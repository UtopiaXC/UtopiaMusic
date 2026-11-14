import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class _StubHttpClientAdapter implements HttpClientAdapter {
  final bool failNetwork;

  _StubHttpClientAdapter({this.failNetwork = false});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failNetwork) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Simulated offline mode',
      );
    }

    if (options.path.contains(Api.urlFingerSpi)) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 0,
          'data': {'b_3': 'TEST_BUVID3_VALUE', 'b_4': 'TEST_BUVID4_VALUE'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.path.contains(Api.urlNav)) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': -101,
          'data': {
            'wbi_img': {
              'img_url': 'https://i0.hdslb.com/bfs/wbi/test_img.png',
              'sub_url': 'https://i0.hdslb.com/bfs/wbi/test_sub.png',
            },
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': {'ok': true},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Guest cold-start cookie initialization completes without deadlocking', () async {
    final tempDir = Directory.systemTemp.createTempSync('utopia_req_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final request = Request.createForTest(
      cookieDir: tempDir,
      httpClientAdapter: _StubHttpClientAdapter(),
    );

    final jar = await request.cookieJar.timeout(const Duration(seconds: 3));
    final baseCookies = await jar.loadForRequest(Uri.parse(Api.urlBase));
    final liveCookies = await jar.loadForRequest(Uri.parse(Api.urlLiveBase));

    expect(
      baseCookies.any((c) => c.name == 'buvid3' && c.value == 'TEST_BUVID3_VALUE'),
      isTrue,
    );
    expect(
      baseCookies.any((c) => c.name == 'b_nut' && c.value.isNotEmpty),
      isTrue,
    );
    expect(
      liveCookies.any((c) => c.name == 'buvid3' && c.value == 'TEST_BUVID3_VALUE'),
      isTrue,
    );

    final navResp = await request
        .get(Api.urlNav)
        .timeout(const Duration(seconds: 3));
    expect(navResp, isA<Map>());
    expect(navResp['code'], -101);
  });

  test('Guest offline cold-start falls back to generated buvid3 without hanging', () async {
    final tempDir = Directory.systemTemp.createTempSync('utopia_req_offline_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final request = Request.createForTest(
      cookieDir: tempDir,
      httpClientAdapter: _StubHttpClientAdapter(failNetwork: true),
    );

    final jar = await request.cookieJar.timeout(const Duration(seconds: 3));
    final baseCookies = await jar.loadForRequest(Uri.parse(Api.urlBase));

    expect(
      baseCookies.any((c) => c.name == 'buvid3' && c.value.isNotEmpty),
      isTrue,
    );
    expect(
      baseCookies.any((c) => c.name == 'b_nut' && c.value.isNotEmpty),
      isTrue,
    );
  });
}
