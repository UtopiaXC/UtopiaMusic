import 'dart:async';
import 'dart:io';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search_api.dart';
import 'package:utopia_music/connection/utils/constants.dart';

class AudioProxyService {
  static final AudioProxyService _instance = AudioProxyService._internal();

  factory AudioProxyService() => _instance;

  AudioProxyService._internal();

  HttpServer? _server;
  final int _port = 0;
  String? _cacheDir;
  final AudioStreamApi _audioStreamApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  final Set<String> _activeDownloads = {};

  Function(String bvid)? onCacheFinished;

  void setCacheDir(String path) {
    _cacheDir = path;
  }

  bool isBvidDownloading(String bvid) {
    return _activeDownloads.contains(bvid);
  }

  Future<void> start() async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
    print('AudioProxy running on port: ${_server!.port}');

    _server!.listen((HttpRequest request) async {
      try {
        final bvid = request.uri.queryParameters['bvid'];
        String? cidStr = request.uri.queryParameters['cid'];

        if (bvid == null || _cacheDir == null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
          return;
        }

        final File cacheFile = File('$_cacheDir/song_$bvid.m4s');
        if (await cacheFile.exists()) {
          await _serveLocalFile(request, cacheFile);
          return;
        }

        bool isAlreadyDownloading = _activeDownloads.contains(bvid);
        int cid = int.tryParse(cidStr ?? '0') ?? 0;
        if (cid == 0) {
          try {
            cid = await _searchApi.fetchCid(bvid);
          } catch (e) {
            request.response.statusCode = HttpStatus.notFound;
            request.response.close();
            return;
          }
        }

        String? realAudioUrl;
        try {
          realAudioUrl = await _audioStreamApi.getAudioStream(bvid, cid);
        } catch (e) {
          print('Stream link fetched failed: $e');
        }

        if (realAudioUrl == null) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
          return;
        }
        bool enableCaching = !isAlreadyDownloading;

        await _proxyAndCache(request, realAudioUrl, bvid, enableCaching);
      } catch (e) {
        print('Proxy Error: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> _serveLocalFile(HttpRequest request, File file) async {
    try {
      final fileLength = await file.length();
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      if (rangeHeader != null) {
        final parts = rangeHeader.replaceFirst('bytes=', '').split('-');
        final start = int.parse(parts[0]);
        final end = parts.length > 1 && parts[1].isNotEmpty
            ? int.parse(parts[1])
            : fileLength - 1;

        if (start >= fileLength) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentLengthHeader,
          end - start + 1,
        );
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$fileLength',
        );
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentType = ContentType.parse("audio/mp4");

        await file.openRead(start, end + 1).pipe(request.response);
      } else {
        request.response.headers.set(
          HttpHeaders.contentLengthHeader,
          fileLength,
        );
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentType = ContentType.parse("audio/mp4");
        await file.openRead().pipe(request.response);
      }
    } catch (e) {}
  }

  Future<void> _proxyAndCache(
    HttpRequest request,
    String remoteUrl,
    String bvid,
    bool enableCaching,
  ) async {
    final client = HttpClient();
    final HttpClientRequest targetRequest = await client.getUrl(
      Uri.parse(remoteUrl),
    );

    targetRequest.headers.set('User-Agent', HttpConstants.userAgent);
    targetRequest.headers.set('Referer', HttpConstants.referer);
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null) {
      targetRequest.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      enableCaching = false;
    }

    final HttpClientResponse targetResponse = await targetRequest.close();
    request.response.statusCode = targetResponse.statusCode;
    request.response.headers.contentType = targetResponse.headers.contentType;
    if (targetResponse.headers.value(HttpHeaders.contentLengthHeader) != null) {
      request.response.headers.set(
        HttpHeaders.contentLengthHeader,
        targetResponse.headers.value(HttpHeaders.contentLengthHeader)!,
      );
    }
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (targetResponse.headers.value(HttpHeaders.contentRangeHeader) != null) {
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        targetResponse.headers.value(HttpHeaders.contentRangeHeader)!,
      );
    }

    IOSink? fileSink;
    File? tempFile;
    if (enableCaching && targetResponse.statusCode == 200) {
      _activeDownloads.add(bvid);
      tempFile = File('$_cacheDir/song_$bvid.part');
      fileSink = tempFile.openWrite();
    }

    StreamSubscription<List<int>>? subscription;
    final Completer<void> streamCompleter = Completer();

    subscription = targetResponse.listen(
      (data) {
        if (fileSink != null) {
          fileSink.add(data);
        }
        try {
          request.response.add(data);
        } catch (e) {
          print("Play stop, cancel download: $bvid");
          subscription?.cancel();
          _abortDownload(fileSink, tempFile, bvid);
          _activeDownloads.remove(bvid);

          try {
            request.response.close();
          } catch (_) {}
          if (!streamCompleter.isCompleted) streamCompleter.complete();
        }
      },
      onDone: () async {
        if (fileSink != null) {
          await fileSink.close();
          final finalFile = File('$_cacheDir/song_$bvid.m4s');
          if (await tempFile!.exists()) {
            await tempFile.rename(finalFile.path);
            print('Cached over: $bvid');
            onCacheFinished?.call(bvid);
          }
          _activeDownloads.remove(bvid);
        }
        try {
          await request.response.close();
        } catch (_) {}
        if (!streamCompleter.isCompleted) streamCompleter.complete();
      },
      onError: (e) {
        print("Stream error: $e");
        _abortDownload(fileSink, tempFile, bvid);
        _activeDownloads.remove(bvid);
        try {
          request.response.close();
        } catch (_) {}
        if (!streamCompleter.isCompleted) streamCompleter.completeError(e);
      },
      cancelOnError: true,
    );

    await streamCompleter.future;
  }

  Future<void> _abortDownload(
    IOSink? fileSink,
    File? tempFile,
    String bvid,
  ) async {
    if (fileSink != null) {
      try {
        await fileSink.close();
      } catch (_) {}

      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
          print("Cache cleaned: $bvid");
        } catch (e) {
          print("Fail to clean cache: $e");
        }
      }
    }
  }

  String buildUrl(String bvid, int cid) {
    if (_server == null) throw Exception("Proxy server not started!");
    return 'http://127.0.0.1:${_server!.port}/stream?bvid=$bvid&cid=$cid';
  }

  void stop() {
    _server?.close();
    _server = null;
  }
}
