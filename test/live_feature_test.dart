import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/live/live_api.dart';
import 'package:utopia_music/connection/live/live_danmaku_service.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/bili_id.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/pages/main/discover/fragments/live_fragment.dart';
import 'package:utopia_music/pages/search/fragment/search_live_fragment.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/services/live/live_audio_service.dart';
import 'package:utopia_music/services/live/live_flv_audio_source.dart';
import 'package:utopia_music/widgets/live/live_room_card.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';

class _FakeLiveAudioService implements LiveAudioServiceProtocol {
  final StreamController<PlayerState> _controller =
      StreamController<PlayerState>.broadcast();
  List<String> lastPlayedUrls = [];
  bool stopped = false;
  bool paused = false;
  int playCallCount = 0;

  @override
  Stream<PlayerState> get playerStateStream => _controller.stream;

  @override
  Future<bool> playStreamUrls(
    List<String> urls, {
    LiveRoom? room,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) return false;
    playCallCount++;
    lastPlayedUrls = List.of(urls);
    paused = false;
    stopped = false;
    _controller.add(PlayerState(true, ProcessingState.ready));
    return urls.isNotEmpty;
  }

  @override
  Future<void> pause() async {
    paused = true;
    _controller.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> resume() async {
    paused = false;
    _controller.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _controller.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _SlowLiveApi extends _FakeLiveApi {
  final Completer<List<String>> urlCompleter = Completer<List<String>>();

  @override
  Future<List<String>> getLiveStreamUrls(int roomId) => urlCompleter.future;
}

class _FakeLiveApi extends LiveApi {
  final List<LiveRoom> followed;
  final List<LiveRoom> recommended;
  final List<LiveRoom> searchResults;
  final LiveRoom? userLiveRoom;

  _FakeLiveApi({
    this.followed = const [],
    this.recommended = const [],
    this.searchResults = const [],
    this.userLiveRoom,
  });

  @override
  Future<List<LiveRoom>> getFollowedLiveRooms({
    int page = 1,
    int pageSize = 20,
  }) async => followed;

  @override
  Future<List<LiveRoom>> getRecommendedLiveRooms({
    int page = 1,
    int pageSize = 20,
  }) async => recommended;

  @override
  Future<List<LiveRoom>> searchLiveRooms(
    String keyword, {
    int page = 1,
  }) async => searchResults;

  @override
  Future<LiveRoom?> getUserLiveRoom(
    int mid, {
    String uname = '',
    String face = '',
  }) async => userLiveRoom;

  @override
  Future<LiveRoom?> getRoomInfo(int roomId, {LiveRoom? fallback}) async =>
      fallback;

  @override
  Future<List<String>> getLiveStreamUrls(int roomId) async => [
    'https://example.com/live/$roomId.m3u8',
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'PlayerProvider runs live mode cleanly and cancels stale slow live loads',
    () async {
      final service = _FakeLiveAudioService();
      final slowApi = _SlowLiveApi();
      final playerProvider = PlayerProvider(
        liveAudioService: service,
        liveApi: slowApi,
      );

      final room = const LiveRoom(
        roomId: 888,
        uid: 1001,
        uname: 'Streamer',
        face: '',
        title: 'Acoustic Night Stream',
        cover: '',
        areaName: 'Music',
        online: 2500,
      );

      final pendingLoad = playerProvider.playLiveRoom(room);
      expect(playerProvider.isLiveMode, isTrue);
      expect(playerProvider.isLiveLoading, isTrue);
      expect(playerProvider.hasNext, isFalse);
      expect(playerProvider.hasPrevious, isFalse);

      // Simulate user backing out / closing player before slow stream resolves
      await playerProvider.closePlayer();
      slowApi.urlCompleter.complete(['https://example.com/live/888.m3u8']);
      await pendingLoad;

      expect(playerProvider.isLiveMode, isFalse);
      expect(playerProvider.currentLiveRoom, isNull);
      expect(playerProvider.currentSong, isNull);
      expect(service.playCallCount, 0);

      // Now test normal live playback lifecycle
      final api = _FakeLiveApi();
      final activeProvider = PlayerProvider(
        liveAudioService: service,
        liveApi: api,
      );
      await activeProvider.playLiveRoom(room);
      expect(activeProvider.isLiveMode, isTrue);
      expect(activeProvider.currentLiveRoom?.roomId, 888);
      expect(activeProvider.isPlaying, isTrue);
      expect(service.lastPlayedUrls, ['https://example.com/live/888.m3u8']);

      await activeProvider.togglePlayPause();
      expect(activeProvider.isPlaying, isFalse);
      expect(service.paused, isTrue);

      await activeProvider.closePlayer();
      expect(activeProvider.isLiveMode, isFalse);
      expect(service.stopped, isTrue);

      playerProvider.dispose();
      activeProvider.dispose();
    },
  );

  testWidgets(
    'LiveFragment displays followed section on top and recommended live rooms below',
    (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final playerProvider = PlayerProvider(
        liveAudioService: _FakeLiveAudioService(),
        liveApi: _FakeLiveApi(),
      );
      final api = _FakeLiveApi(
        followed: const [
          LiveRoom(
            roomId: 101,
            uid: 11,
            uname: 'Followed DJ',
            face: '',
            title: 'Followed Live Set',
            cover: '',
            isFollowed: true,
          ),
        ],
        recommended: const [
          LiveRoom(
            roomId: 202,
            uid: 22,
            uname: 'Rec DJ',
            face: '',
            title: 'Recommended Chill Live',
            cover: '',
            online: 18500,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: playerProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh')],
            locale: const Locale('zh'),
            home: Scaffold(
              body: LiveFragment(
                scrollController: ScrollController(),
                refreshIndicatorKey: GlobalKey<RefreshIndicatorState>(),
                liveApi: api,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('关注的直播间'), findsOneWidget);
      expect(find.text('推荐直播间'), findsOneWidget);
      expect(find.text('Recommended Chill Live'), findsOneWidget);
      expect(find.byType(LiveRoomCard), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'SearchLiveFragment searches and displays matching live rooms',
    (WidgetTester tester) async {
      final playerProvider = PlayerProvider(
        liveAudioService: _FakeLiveAudioService(),
        liveApi: _FakeLiveApi(),
      );
      final api = _FakeLiveApi(
        searchResults: const [
          LiveRoom(
            roomId: 303,
            uid: 33,
            uname: 'Jazz Host',
            face: '',
            title: 'Late Night Jazz Piano',
            cover: '',
            areaName: 'Music',
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: playerProvider,
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh')],
            locale: const Locale('zh'),
            home: Scaffold(
              body: SearchLiveFragment(
                keyword: 'Jazz',
                searchTimestamp: 1,
                liveApi: api,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Late Night Jazz Piano'), findsOneWidget);
      expect(find.text('Jazz Host'), findsOneWidget);
    },
  );

  testWidgets(
    'SpaceSheet displays live room entry banner when user is currently live',
    (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final playerProvider = PlayerProvider(
        liveAudioService: _FakeLiveAudioService(),
        liveApi: _FakeLiveApi(),
      );
      final settingsProvider = SettingsProvider();
      final api = _FakeLiveApi(
        userLiveRoom: const LiveRoom(
          roomId: 404,
          uid: 444,
          uname: 'Live User',
          face: '',
          title: 'Live Studio Session',
          cover: '',
          isLive: true,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh')],
            locale: const Locale('zh'),
            home: Scaffold(
              body: SpaceSheet(mid: 444, liveApi: api),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Live Studio Session'), findsOneWidget);
      expect(find.text('进入直播间'), findsOneWidget);
    },
  );

  testWidgets(
    'FullPlayerPage disables unsupported controls cleanly in live mode',
    (WidgetTester tester) async {
      final service = _FakeLiveAudioService();
      final api = _FakeLiveApi();
      final playerProvider = PlayerProvider(
        liveAudioService: service,
        liveApi: api,
      );
      final settingsProvider = SettingsProvider();
      final authProvider = AuthProvider();
      final sbProvider = SponsorBlockProvider();

      await playerProvider.playLiveRoom(
        const LiveRoom(
          roomId: 505,
          uid: 55,
          uname: 'Pure Audio Streamer',
          face: '',
          title: 'Radio Room',
          cover: '',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: sbProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh')],
            locale: const Locale('zh'),
            home: FullPlayerPage(
              song: playerProvider.currentSong!,
              onCollapse: () {},
              onSongSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Radio Room'), findsOneWidget);
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders, isNotEmpty);
      expect(sliders.every((s) => s.onChanged == null), isTrue);
      final nextBtns = tester
          .widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_next),
          )
          .toList();
      expect(nextBtns, isNotEmpty);
      expect(nextBtns.every((b) => b.onPressed == null), isTrue);
      final prevBtns = tester
          .widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_previous),
          )
          .toList();
      expect(prevBtns, isNotEmpty);
      expect(prevBtns.every((b) => b.onPressed == null), isTrue);
      final lyricsBtns = tester
          .widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.lyrics_outlined),
          )
          .toList();
      expect(lyricsBtns, isNotEmpty);
      expect(lyricsBtns.any((b) => b.onPressed != null), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      playerProvider.dispose();
    },
  );

  test('LiveDanmakuPacketParser decodes zlib DANMU_MSG and LiveApi filters Android FLV', () {
    final jsonBytes = utf8.encode(
      jsonEncode({
        'cmd': 'DANMU_MSG',
        'info': [
          [0, 1, 25, 0xFF8800, 0],
          'Live stream danmaku!',
          [12345, 'Listener'],
        ],
      }),
    );
    final innerPacket = LiveDanmakuPacketParser.encodePacket(
      jsonBytes,
      operation: LiveDanmakuPacketParser.opNotification,
      protocolVersion: 0,
    );
    final compressedPacket = LiveDanmakuPacketParser.encodePacket(
      Uint8List.fromList(zlib.encode(innerPacket)),
      operation: LiveDanmakuPacketParser.opNotification,
      protocolVersion: 2,
    );

    final parsed = LiveDanmakuPacketParser.decodePackets(compressedPacket);
    expect(parsed.length, 1);
    expect(parsed.first.sender, 'Listener');
    expect(parsed.first.content, 'Live stream danmaku!');
    expect(parsed.first.color, 0xFF8800);

    final androidUrls = LiveApi.filterUrlsForPlatform([
      'https://cdn.example/live/index.m3u8',
      'https://cdn.example/live/stream.flv',
    ], isAndroid: true);
    expect(androidUrls, ['https://cdn.example/live/index.m3u8']);

    final mediaKitUrls = LiveApi.filterUrlsForPlatform(
      [
        'https://cdn.example/live/index.m3u8',
        'https://cdn.example/live/stream.flv',
      ],
      isAndroid: false,
      usesMediaKit: true,
    );
    expect(mediaKitUrls, ['https://cdn.example/live/stream.flv']);
  });

  test('FlvAudioDemuxer extracts AAC ADTS frames and drops FLV video tags', () {
    List<int> buildTag(int type, List<int> payload) {
      final size = payload.length;
      return [
        type,
        (size >> 16) & 0xFF,
        (size >> 8) & 0xFF,
        size & 0xFF,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        ...payload,
        0,
        0,
        0,
        11 + size,
      ];
    }

    final flvBytes = <int>[
      // FLV header (audio+video) + PreviousTagSize0
      0x46, 0x4C, 0x56, 0x01, 0x05, 0x00, 0x00, 0x00, 0x09,
      0x00, 0x00, 0x00, 0x00,
      // Video tag (type 9) - must be ignored
      ...buildTag(9, [0x17, 0x00, 0x00, 0x00, 0x00, 0xAA, 0xBB]),
      // AAC AudioSpecificConfig (AAC-LC=2, 44100Hz index=4 -> 0x12, ch=2 -> 0x10)
      ...buildTag(8, [0xAF, 0x00, 0x12, 0x10]),
      // Raw AAC audio frame
      ...buildTag(8, [0xAF, 0x01, 0xDE, 0xAD, 0xBE, 0xEF]),
    ];

    final demuxer = FlvAudioDemuxer();
    final split = flvBytes.length ~/ 2;
    final out1 = demuxer.feed(flvBytes.sublist(0, split));
    final out2 = demuxer.feed(flvBytes.sublist(split));
    final frames = [...out1, ...out2];

    expect(demuxer.contentType, 'audio/aac');
    expect(frames.length, 1);
    final adts = frames.first;
    expect(adts.length, 7 + 4);
    expect(adts[0], 0xFF);
    expect(adts[1], 0xF1);
    expect(adts.sublist(7), [0xDE, 0xAD, 0xBE, 0xEF]);
  });

  test('LiveApi parses index/getList feed and orders fmp4 HLS -> ts HLS -> flv', () {
    final api = LiveApi();
    final rooms = api.parseIndexListResponse({
      'code': 0,
      'data': {
        'recommend_room_list': [
          {
            'roomid': 101,
            'uid': 11,
            'uname': 'Host A',
            'title': '<em>Lo-fi</em> Beats',
            'cover': '//i0.hdslb.com/bfs/live/a.jpg',
            'area_v2_name': 'Music',
            'online': 1234,
          },
        ],
        'room_list': [
          {
            'module_info': {'title': 'Recommend'},
            'list': [
              {
                'roomid': 101,
                'uid': 11,
                'uname': 'Host A',
                'title': 'Lo-fi Beats',
                'cover': 'http://i0.hdslb.com/bfs/live/a.jpg',
                'area_v2_name': 'Music',
                'online': 1234,
              },
              {
                'roomid': 202,
                'up_id': 22,
                'uname': 'Host B',
                'title': 'Late Night Radio',
                'user_cover': '//i0.hdslb.com/bfs/live/b.jpg',
                'area_v2_parent_name': 'Radio',
                'online': 99,
              },
            ],
          },
        ],
      },
    });

    expect(rooms.length, 2);
    expect(rooms[0].roomId, 101);
    expect(rooms[0].title, 'Lo-fi Beats');
    expect(rooms[0].cover, 'https://i0.hdslb.com/bfs/live/a.jpg');
    expect(rooms[0].areaName, 'Music');
    expect(rooms[1].roomId, 202);
    expect(rooms[1].uid, 22);
    expect(rooms[1].areaName, 'Radio');

    final urls = api.extractPlayInfoUrls({
      'code': 0,
      'data': {
        'playurl_info': {
          'playurl': {
            'stream': [
              {
                'protocol_name': 'http_stream',
                'format': [
                  {
                    'format_name': 'flv',
                    'codec': [
                      {
                        'base_url': '/live/stream.flv',
                        'url_info': [
                          {'host': 'https://cdn-flv.example', 'extra': '?a=1'},
                        ],
                      },
                    ],
                  },
                ],
              },
              {
                'protocol_name': 'http_hls',
                'format': [
                  {
                    'format_name': 'ts',
                    'codec': [
                      {
                        'base_url': '/live/stream.m3u8',
                        'url_info': [
                          {'host': 'https://cdn-ts.example', 'extra': '?a=2'},
                        ],
                      },
                    ],
                  },
                  {
                    'format_name': 'fmp4',
                    'codec': [
                      {
                        'base_url': '/live/index.m3u8',
                        'url_info': [
                          {'host': 'https://cdn-fmp4.example', 'extra': '?a=3'},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
    });

    expect(urls, [
      'https://cdn-fmp4.example/live/index.m3u8?a=3',
      'https://cdn-ts.example/live/stream.m3u8?a=2',
      'https://cdn-flv.example/live/stream.flv?a=1',
    ]);
  });

  test(
    'LiveRoomByMid endpoint, AV/BV conversion, WBI space percent-encoding, and App space fallback parser work correctly',
    () {
      expect(Api.urlLiveRoomByMid, '/room/v1/Room/getRoomInfoOld');
      expect(BiliIdUtils.av2bv(170001), 'BV17x411w7KC');
      expect(BiliIdUtils.generateBuvid3().endsWith('infoc'), isTrue);

      final encoded = WbiUtil.encodeWbiForTest(
        {'keyword': 'lofi music', 'page': 1},
        '7cd084941338484aae1ad9425b84077c',
        '4932caff0ff746eab6f01bf08b70ac45',
        timestamp: 1700000000,
      );
      expect(encoded['w_rid'], 'e99ed95767cee6d5f0197b78034e8505');

      final items = UserApi.mapAppArchiveItems([
        {
          'param': '170001',
          'title': 'Fallback Video',
          'author': 'UP Name',
          'cover': 'http://i0.hdslb.com/bfs/archive/test.jpg',
          'duration': 215,
          'first_cid': 987654,
          'stat': {'view': 1234, 'danmaku': 56},
        },
      ]);

      expect(items.length, 1);
      expect(items.first['bvid'], 'BV17x411w7KC');
      expect(items.first['pic'], 'https://i0.hdslb.com/bfs/archive/test.jpg');
      expect(items.first['author'], 'UP Name');
      expect(items.first['cid'], 987654);
      expect(items.first['play'], 1234);
    },
  );
}
