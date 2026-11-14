import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:utopia_music/connection/utils/constants.dart';

/// Incremental binary demuxer converting live FLV audio tags into ADTS AAC
/// (or raw MPEG) frames so `just_audio_media_kit` / `libmpv` can start playback
/// immediately without probing video streams or HLS segments.
class FlvAudioDemuxer {
  bool _headerParsed = false;
  int _objectType = 2;
  int _freqIndex = 4;
  int _channelConfig = 2;
  bool _hasAudioConfig = false;
  String? _contentType;
  Uint8List _pending = Uint8List(0);

  String? get contentType => _contentType;

  /// Builds a 7-byte ADTS header matching the AAC frame length and AudioSpecificConfig.
  static Uint8List buildAdtsHeader({
    required int aacPayloadLength,
    required int objectType,
    required int freqIndex,
    required int channelConfig,
  }) {
    final frameLength = aacPayloadLength + 7;
    final profile = (objectType >= 1 && objectType <= 4)
        ? objectType - 1
        : 1;
    final safeFreq = freqIndex & 0x0F;
    final safeCh = channelConfig & 0x07;

    return Uint8List.fromList([
      0xFF,
      0xF1,
      ((profile & 0x03) << 6) | ((safeFreq & 0x0F) << 2) | ((safeCh >> 2) & 0x01),
      ((safeCh & 0x03) << 6) | ((frameLength >> 11) & 0x03),
      (frameLength >> 3) & 0xFF,
      ((frameLength & 0x07) << 5) | 0x1F,
      0xFC,
    ]);
  }

  /// Feeds a chunk of raw FLV bytes and returns extracted audio frame buffers.
  List<Uint8List> feed(List<int> chunk) {
    if (chunk.isEmpty) return const [];
    final Uint8List data;
    if (_pending.isEmpty) {
      data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    } else {
      final combined = Uint8List(_pending.length + chunk.length);
      combined.setRange(0, _pending.length, _pending);
      combined.setRange(_pending.length, combined.length, chunk);
      data = combined;
    }

    int offset = 0;
    if (!_headerParsed) {
      if (data.length < 13) {
        _pending = data;
        return const [];
      }
      if (data[0] != 0x46 || data[1] != 0x4C || data[2] != 0x56) {
        throw const FormatException('Invalid FLV stream header');
      }
      offset = 13;
      _headerParsed = true;
    }

    final outputs = <Uint8List>[];
    while (data.length - offset >= 11) {
      final tagType = data[offset];
      final dataSize =
          (data[offset + 1] << 16) |
          (data[offset + 2] << 8) |
          data[offset + 3];
      final totalTagBytes = 11 + dataSize + 4;
      if (data.length - offset < totalTagBytes) {
        break;
      }

      if (tagType == 8 && dataSize >= 2) {
        final payloadStart = offset + 11;
        final soundFormat = (data[payloadStart] >> 4) & 0x0F;
        if (soundFormat == 10) {
          final aacPacketType = data[payloadStart + 1];
          if (aacPacketType == 0 && dataSize >= 4) {
            final b0 = data[payloadStart + 2];
            final b1 = data[payloadStart + 3];
            _objectType = (b0 >> 3) & 0x1F;
            _freqIndex = ((b0 & 0x07) << 1) | ((b1 >> 7) & 0x01);
            _channelConfig = (b1 >> 3) & 0x0F;
            _hasAudioConfig = true;
          } else if (aacPacketType == 1 && dataSize > 2 && _hasAudioConfig) {
            final rawLen = dataSize - 2;
            final adts = buildAdtsHeader(
              aacPayloadLength: rawLen,
              objectType: _objectType,
              freqIndex: _freqIndex,
              channelConfig: _channelConfig,
            );
            final frame = Uint8List(adts.length + rawLen);
            frame.setRange(0, adts.length, adts);
            frame.setRange(
              adts.length,
              frame.length,
              data,
              payloadStart + 2,
            );
            _contentType ??= 'audio/aac';
            outputs.add(frame);
          }
        } else if (soundFormat == 2 && dataSize > 1) {
          _contentType ??= 'audio/mpeg';
          outputs.add(
            Uint8List.sublistView(data, payloadStart + 1, payloadStart + dataSize),
          );
        }
      }
      offset += totalTagBytes;
    }

    _pending = offset < data.length
        ? Uint8List.sublistView(data, offset)
        : Uint8List(0);
    return outputs;
  }
}

/// Streams a live Bilibili FLV URL through an on-the-fly audio demuxer so
/// audio-only desktop/iOS `libmpv` backends start in <200ms without probing
/// multi-megabyte video streams.
class LiveFlvAacAudioSource extends StreamAudioSource {
  final Uri uri;
  final Map<String, String> headers;
  final Duration connectTimeout;

  LiveFlvAacAudioSource(
    this.uri, {
    Map<String, String>? headers,
    this.connectTimeout = const Duration(seconds: 6),
    super.tag,
  }) : headers = headers ??
            {
              'Referer': 'https://live.bilibili.com/',
              'User-Agent': HttpConstants.userAgent,
            };

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (start != null && start > 0) {
      throw UnsupportedError('Live FLV stream does not support range requests');
    }

    final client = HttpClient()..connectionTimeout = connectTimeout;
    StreamSubscription<List<int>>? upstreamSub;
    bool closed = false;

    Future<void> closeUpstream() async {
      if (closed) return;
      closed = true;
      await upstreamSub?.cancel();
      client.close(force: true);
    }

    try {
      final req = await client.getUrl(uri).timeout(connectTimeout);
      headers.forEach((key, value) {
        req.headers.set(key, value);
      });
      final resp = await req.close().timeout(connectTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        await closeUpstream();
        throw HttpException(
          'Unexpected status ${resp.statusCode} for live FLV stream',
          uri: uri,
        );
      }

      final demuxer = FlvAudioDemuxer();
      final readyCompleter = Completer<String>();
      late final StreamController<List<int>> controller;
      controller = StreamController<List<int>>(
        onCancel: closeUpstream,
      );

      upstreamSub = resp.listen(
        (chunk) {
          if (closed || controller.isClosed) return;
          try {
            final frames = demuxer.feed(chunk);
            for (final frame in frames) {
              controller.add(frame);
            }
            if (!readyCompleter.isCompleted &&
                frames.isNotEmpty &&
                demuxer.contentType != null) {
              readyCompleter.complete(demuxer.contentType!);
            }
          } catch (e, st) {
            if (!readyCompleter.isCompleted) {
              readyCompleter.completeError(e, st);
            } else if (!controller.isClosed) {
              controller.addError(e, st);
            }
            unawaited(closeUpstream());
            if (!controller.isClosed) {
              unawaited(controller.close());
            }
          }
        },
        onError: (Object error, StackTrace st) {
          if (!readyCompleter.isCompleted) {
            readyCompleter.completeError(error, st);
          } else if (!controller.isClosed) {
            controller.addError(error, st);
          }
          unawaited(closeUpstream());
          if (!controller.isClosed) {
            unawaited(controller.close());
          }
        },
        onDone: () {
          if (!readyCompleter.isCompleted) {
            readyCompleter.completeError(
              const FormatException('Live FLV stream ended before first audio frame'),
            );
          }
          unawaited(closeUpstream());
          if (!controller.isClosed) {
            unawaited(controller.close());
          }
        },
        cancelOnError: true,
      );

      final mimeType = await readyCompleter.future.timeout(connectTimeout);
      return StreamAudioResponse(
        sourceLength: null,
        contentLength: null,
        offset: null,
        stream: controller.stream,
        contentType: mimeType,
        rangeRequestsSupported: false,
      );
    } catch (_) {
      await closeUpstream();
      rethrow;
    }
  }
}
