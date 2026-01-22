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
  String? _cacheDirectory;
  final AudioStreamApi _audioStreamApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  final Set<String> _activeDownloads = {};

  Function(String bvid)? onCacheFinished;
  void setCacheDir(String path) {
    _cacheDirectory = path;
  }

  bool isBvidDownloading(String bvid) {
    return _activeDownloads.contains(bvid);
  }

  Future<void> start() async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);

    _server!.listen((HttpRequest request) async {
      try {
        final bvid = request.uri.queryParameters['bvid'];
        String? cidString = request.uri.queryParameters['cid'];

        if (bvid == null || _cacheDirectory == null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
          return;
        }

        final File localCacheFile = File('$_cacheDirectory/song_$bvid.m4s');
        if (await localCacheFile.exists()) {
          await _serveLocalFile(request, localCacheFile);
          return;
        }

        int cid = int.tryParse(cidString ?? '0') ?? 0;
        if (cid == 0) {
          try {
            cid = await _searchApi.fetchCid(bvid);
          } catch (error) {
            request.response.statusCode = HttpStatus.notFound;
            request.response.close();
            return;
          }
        }

        String? remoteAudioUrl;
        try {
          remoteAudioUrl = await _audioStreamApi.getAudioStream(bvid, cid);
        } catch (error) {
          print(error);
        }

        if (remoteAudioUrl == null) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
          return;
        }

        if (request.method == 'HEAD') {
          await _handleHeadRequest(request, remoteAudioUrl);
          return;
        }

        bool isAlreadyDownloading = _activeDownloads.contains(bvid);
        bool enableCaching = !isAlreadyDownloading;

        await _proxyAndCache(request, remoteAudioUrl, bvid, enableCaching);
      } catch (error) {
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

      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.contentType = ContentType.parse("audio/mp4");

      if (request.method == 'HEAD') {
        request.response.headers.set(HttpHeaders.contentLengthHeader, fileLength);
        request.response.close();
        return;
      }

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

        await file.openRead(start, end + 1).pipe(request.response);
      } else {
        request.response.headers.set(
          HttpHeaders.contentLengthHeader,
          fileLength,
        );
        await file.openRead().pipe(request.response);
      }
    } catch (error) {
      try {
        request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleHeadRequest(HttpRequest request, String remoteUrl) async {
    final client = HttpClient();
    try {
      final HttpClientRequest targetRequest = await client.headUrl(Uri.parse(remoteUrl));
      targetRequest.headers.set('User-Agent', HttpConstants.userAgent);
      targetRequest.headers.set('Referer', HttpConstants.referer);

      final HttpClientResponse targetResponse = await targetRequest.close();

      request.response.statusCode = targetResponse.statusCode;
      request.response.headers.contentType = targetResponse.headers.contentType;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (targetResponse.headers.value(HttpHeaders.contentLengthHeader) != null) {
        request.response.headers.set(
          HttpHeaders.contentLengthHeader,
          targetResponse.headers.value(HttpHeaders.contentLengthHeader)!,
        );
      }

      await request.response.close();
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.close();
    } finally {
      client.close();
    }
  }

  Future<void> _proxyAndCache(
      HttpRequest request,
      String remoteUrl,
      String bvid,
      bool enableCaching,
      ) async {
    final client = HttpClient();
    try {
      final HttpClientRequest targetRequest = await client.getUrl(Uri.parse(remoteUrl));

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
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (targetResponse.headers.value(HttpHeaders.contentLengthHeader) != null) {
        request.response.headers.set(
          HttpHeaders.contentLengthHeader,
          targetResponse.headers.value(HttpHeaders.contentLengthHeader)!,
        );
      }

      if (targetResponse.headers.value(HttpHeaders.contentRangeHeader) != null) {
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          targetResponse.headers.value(HttpHeaders.contentRangeHeader)!,
        );
      }

      IOSink? fileSink;
      File? tempFile;
      if (enableCaching && targetResponse.statusCode == HttpStatus.ok) {
        _activeDownloads.add(bvid);
        tempFile = File('$_cacheDirectory/song_$bvid.part');
        try {
          fileSink = tempFile.openWrite();
        } catch (e) {
          print("Error opening cache file: $e");
          enableCaching = false;
          fileSink = null;
          tempFile = null;
          _activeDownloads.remove(bvid);
        }
      }

      StreamSubscription<List<int>>? subscription;
      final Completer<void> streamCompleter = Completer();

      subscription = targetResponse.listen(
            (data) {
          if (fileSink != null) {
            try {
              fileSink!.add(data);
            } catch (e) {
              print("Write error: $e");
              _abortDownload(fileSink, tempFile, bvid);
              fileSink = null;
              tempFile = null;
              _activeDownloads.remove(bvid);
            }
          }
          try {
            request.response.add(data);
          } catch (error) {
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
            try {
              await fileSink!.close();
              final finalFile = File('$_cacheDirectory/song_$bvid.m4s');
              if (tempFile != null && await tempFile!.exists()) {
                await tempFile!.rename(finalFile.path);
                onCacheFinished?.call(bvid);
              }
            } catch (e) {
              print("Error finalizing cache: $e");
              _abortDownload(fileSink, tempFile, bvid);
            }
            _activeDownloads.remove(bvid);
          }
          try {
            await request.response.close();
          } catch (_) {}
          if (!streamCompleter.isCompleted) streamCompleter.complete();
        },
        onError: (error) {
          _abortDownload(fileSink, tempFile, bvid);
          _activeDownloads.remove(bvid);
          try {
            request.response.close();
          } catch (_) {}
          if (!streamCompleter.isCompleted) streamCompleter.completeError(error);
        },
        cancelOnError: true,
      );

      await streamCompleter.future;

    } catch (error) {
      _activeDownloads.remove(bvid);
      try {
        request.response.close();
      } catch (_) {}
    } finally {
      client.close();
    }
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

      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  String buildUrl(String bvid, int cid) {
    if (_server == null) throw Exception("Proxy server not started");
    return 'http://127.0.0.1:${_server!.port}/stream?bvid=$bvid&cid=$cid';
  }

  void stop() {
    _server?.close();
    _server = null;
  }
}
