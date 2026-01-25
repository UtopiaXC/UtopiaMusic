import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';

class BiliAudioSource extends StreamAudioSource {
  final String bvid;
  final int? initCid;
  final String title;
  final String coverUrl;
  final String artist;
  final int quality;

  final AudioStreamApi _audioStreamApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  final DownloadManager _downloadManager = DownloadManager();

  int? _resolvedCid;
  AudioStreamInfo? _cachedStreamInfo;

  BiliAudioSource({
    required this.bvid,
    this.initCid,
    required this.title,
    required this.coverUrl,
    required this.artist,
    this.quality = 30280,
  }) : super(
         tag: MediaItem(
           id: '${bvid}_${initCid ?? 0}',
           title: title,
           artist: artist,
           artUri: Uri.tryParse(coverUrl),
         ),
       ) {
    if (initCid != null && initCid != 0) {
      _resolvedCid = initCid;
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      if (_resolvedCid == null || _resolvedCid == 0) {
        print('BiliAudioSource: Fetching CID for $bvid...');
        _resolvedCid = await _searchApi.fetchCid(bvid);
        if (_resolvedCid == 0) {
          throw Exception('无法获取有效的 CID');
        }
      }
      final cid = _resolvedCid!;
      final localRes = await _downloadManager.getPlayableFile(
        bvid,
        cid,
        quality,
      );
      if (localRes != null) {
        final file = localRes.file;
        final actualQuality = localRes.quality;
        if (actualQuality != quality) {
          print(
            "BiliAudioSource: Playing local file (Quality: $actualQuality, Requested: $quality)",
          );
        }
        AudioPlayerService().notifyActualQuality(actualQuality);
        return _serveFile(file, start, end);
      }

      if (_cachedStreamInfo == null) {
        print('BiliAudioSource: Fetching Audio Stream for $bvid / $cid...');
        _cachedStreamInfo = await _audioStreamApi.getAudioStream(
          bvid,
          cid,
          preferredQuality: quality,
        );
      }

      if (_cachedStreamInfo != null) {
        AudioPlayerService().notifyActualQuality(_cachedStreamInfo!.quality);
      }

      if (_cachedStreamInfo == null || _cachedStreamInfo!.url.isEmpty) {
        throw Exception('无法获取音频流地址');
      }

      bool enableCaching = (start == null || start == 0) && end == null;

      if (enableCaching) {
        return _streamAndCache(_cachedStreamInfo!);
      } else {
        return _streamFromNetwork(_cachedStreamInfo!, start ?? 0, end);
      }
    } catch (e) {
      print("BiliAudioSource Error: $e");
      AudioPlayerService().notifyPlaybackError(
        bvid,
        _resolvedCid ?? initCid ?? 0,
      );
      rethrow;
    }
  }

  Future<StreamAudioResponse> _streamAndCache(AudioStreamInfo info) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(Uri.parse(info.url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);

      final response = await request.close();

      if (response.statusCode >= 400) {
        throw Exception('HTTP Error: ${response.statusCode}');
      }

      final tempFile = await _downloadManager.getTempCacheFile(
        bvid,
        _resolvedCid!,
        quality,
      );
      final fileSink = tempFile.openWrite();

      int? totalLength = response.contentLength;
      if (totalLength == -1) totalLength = null;

      Stream<List<int>> teeStream() async* {
        try {
          await for (var chunk in response) {
            fileSink.add(chunk);
            yield chunk;
          }
          await fileSink.flush();
          await fileSink.close();

          print("BiliAudioSource: Caching finished for $bvid");
          await _downloadManager.commitCacheFile(
            tempFile,
            bvid,
            _resolvedCid!,
            quality,
          );
        } catch (e) {
          print("Stream interrupted: $e");
          try {
            await fileSink.close();
          } catch (_) {}
          try {
            if (await tempFile.exists()) await tempFile.delete();
          } catch (_) {}
          throw e;
        }
      }

      return StreamAudioResponse(
        sourceLength: totalLength,
        contentLength: totalLength,
        offset: 0,
        stream: teeStream(),
        contentType: _getContentTypeFromExtension(info.extension),
      );
    } catch (e) {
      client.close();
      AudioPlayerService().notifyPlaybackError(
        bvid,
        _resolvedCid ?? initCid ?? 0,
      );
      rethrow;
    }
  }

  Future<StreamAudioResponse> _streamFromNetwork(
    AudioStreamInfo info,
    int start,
    int? end,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(info.url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);
      String rangeHeader = 'bytes=$start-';
      if (end != null) rangeHeader += '$end';
      request.headers.set('Range', rangeHeader);
      final response = await request.close();
      int? totalLength;
      final contentRange = response.headers.value(
        HttpHeaders.contentRangeHeader,
      );
      if (contentRange != null) {
        try {
          final parts = contentRange.split('/');
          if (parts.length == 2 && parts[1] != '*')
            totalLength = int.tryParse(parts[1]);
        } catch (_) {}
      }
      if (totalLength == null && response.statusCode == 200)
        totalLength = response.contentLength;
      return StreamAudioResponse(
        sourceLength: totalLength,
        contentLength: response.contentLength == -1
            ? null
            : response.contentLength,
        offset: start,
        stream: response,
        contentType: _getContentTypeFromExtension(info.extension),
      );
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Future<StreamAudioResponse> _serveFile(
    File file,
    int? start,
    int? end,
  ) async {
    final fileSize = await file.length();
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? (fileSize > 0 ? fileSize : null);
    int? contentLength;
    if (effectiveEnd != null)
      contentLength = effectiveEnd - effectiveStart;
    else
      contentLength = fileSize - effectiveStart;
    if (contentLength < 0) contentLength = 0;
    return StreamAudioResponse(
      sourceLength: fileSize,
      contentLength: contentLength,
      offset: effectiveStart,
      stream: file.openRead(effectiveStart, effectiveEnd),
      contentType: _getContentTypeFromExtension(file.path.split('.').last),
    );
  }

  String _getContentTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'm4a':
      case 'mp4':
      case 'm4s':
      case 'audio':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      default:
        return 'audio/mpeg';
    }
  }
}
