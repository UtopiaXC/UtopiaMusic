import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = 'LIVE_DANMAKU_SERVICE';

/// A single real-time or recent danmaku message from a live streaming room.
class LiveDanmakuMessage {
  final String sender;
  final String content;
  final int color;
  final int mode;
  final DateTime timestamp;

  const LiveDanmakuMessage({
    required this.sender,
    required this.content,
    this.color = 0xFFFFFF,
    this.mode = 1,
    required this.timestamp,
  });
}

/// Binary packet codec for Bilibili live danmaku WebSocket protocol (`protover=2`).
class LiveDanmakuPacketParser {
  static const int headerLength = 16;
  static const int opHeartbeat = 2;
  static const int opHeartbeatReply = 3;
  static const int opNotification = 5;
  static const int opAuth = 7;
  static const int opAuthReply = 8;

  static Uint8List encodePacket(
    List<int> body, {
    required int operation,
    int protocolVersion = 1,
    int sequence = 1,
  }) {
    final totalLength = headerLength + body.length;
    final bytes = ByteData(totalLength);
    bytes.setUint32(0, totalLength, Endian.big);
    bytes.setUint16(4, headerLength, Endian.big);
    bytes.setUint16(6, protocolVersion, Endian.big);
    bytes.setUint32(8, operation, Endian.big);
    bytes.setUint32(12, sequence, Endian.big);
    final result = bytes.buffer.asUint8List();
    if (body.isNotEmpty) {
      result.setRange(headerLength, totalLength, body);
    }
    return result;
  }

  static Uint8List encodeAuthPacket({
    required int roomId,
    required String token,
    int uid = 0,
    String buvid = '',
  }) {
    final payload = <String, dynamic>{
      'uid': uid,
      'roomid': roomId,
      'protover': 2,
      'platform': 'web',
      'type': 2,
      if (buvid.isNotEmpty) 'buvid': buvid,
      if (token.isNotEmpty) 'key': token,
    };
    return encodePacket(
      utf8.encode(jsonEncode(payload)),
      operation: opAuth,
      protocolVersion: 1,
    );
  }

  static Uint8List encodeHeartbeatPacket() {
    return encodePacket(
      utf8.encode('[object Object]'),
      operation: opHeartbeat,
      protocolVersion: 1,
    );
  }

  /// Decodes raw WebSocket binary frames into [LiveDanmakuMessage] items.
  static List<LiveDanmakuMessage> decodePackets(Uint8List bytes) {
    final List<LiveDanmakuMessage> messages = [];
    _parseBuffer(bytes, messages);
    return messages;
  }

  static void _parseBuffer(Uint8List bytes, List<LiveDanmakuMessage> out) {
    int offset = 0;
    while (offset + headerLength <= bytes.length) {
      final header = ByteData.sublistView(bytes, offset, offset + headerLength);
      final int packetLen = header.getUint32(0, Endian.big);
      final int headerLen = header.getUint16(4, Endian.big);
      final int protoVer = header.getUint16(6, Endian.big);
      final int op = header.getUint32(8, Endian.big);

      if (packetLen < headerLen ||
          headerLen < headerLength ||
          offset + packetLen > bytes.length) {
        break;
      }

      final body = Uint8List.sublistView(
        bytes,
        offset + headerLen,
        offset + packetLen,
      );

      if (protoVer == 2) {
        try {
          final inflated = Uint8List.fromList(zlib.decode(body));
          _parseBuffer(inflated, out);
        } catch (e) {
          Log.w(_tag, 'Failed to inflate zlib danmaku packet: $e');
        }
      } else if (op == opNotification && body.isNotEmpty) {
        _parseNotificationJson(body, out);
      }

      offset += packetLen;
    }
  }

  static void _parseNotificationJson(
    Uint8List body,
    List<LiveDanmakuMessage> out,
  ) {
    try {
      final decoded = jsonDecode(utf8.decode(body, allowMalformed: true));
      if (decoded is! Map<String, dynamic>) return;
      final cmd = decoded['cmd']?.toString() ?? '';
      if (!cmd.startsWith('DANMU_MSG')) return;
      final info = decoded['info'];
      if (info is! List || info.length < 3) return;

      final content = info[1]?.toString().trim() ?? '';
      if (content.isEmpty) return;

      int mode = 1;
      int color = 0xFFFFFF;
      final meta = info[0];
      if (meta is List) {
        if (meta.length > 1 && meta[1] is num) {
          mode = (meta[1] as num).toInt();
        }
        if (meta.length > 3 && meta[3] is num) {
          color = (meta[3] as num).toInt();
        }
      }

      String sender = '';
      final user = info[2];
      if (user is List && user.length > 1) {
        sender = user[1]?.toString() ?? '';
      }

      out.add(
        LiveDanmakuMessage(
          sender: sender,
          content: content,
          color: color,
          mode: mode,
          timestamp: DateTime.now(),
        ),
      );
    } catch (_) {}
  }
}

/// Manages recent history loading and real-time WebSocket danmaku streaming
/// for an active Bilibili live room.
class LiveDanmakuService {
  final StreamController<LiveDanmakuMessage> _controller =
      StreamController<LiveDanmakuMessage>.broadcast();

  Stream<LiveDanmakuMessage> get danmakuStream => _controller.stream;

  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _connectionToken = 0;
  int? _activeRoomId;
  int _activeUid = 0;
  int _reconnectAttempts = 0;

  static Options _liveOptions() => Options(
    headers: const {
      'Referer': 'https://live.bilibili.com/',
      'Origin': 'https://live.bilibili.com',
    },
  );

  /// Fetches the most recent chat history snapshots shown upon entering a room.
  Future<List<LiveDanmakuMessage>> fetchRecentMessages(int roomId) async {
    try {
      final resp = await Request().get(
        Api.urlLiveDanmuHistory,
        baseUrl: Api.urlLiveBase,
        params: {'roomid': roomId},
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (resp is Map && resp['code'] == 0) {
        final roomList = resp['data']?['room'];
        if (roomList is List) {
          final result = <LiveDanmakuMessage>[];
          for (final entry in roomList) {
            if (entry is! Map) continue;
            final text = entry['text']?.toString().trim() ?? '';
            if (text.isEmpty) continue;
            final sender = entry['nickname']?.toString() ?? '';
            result.add(
              LiveDanmakuMessage(
                sender: sender,
                content: text,
                timestamp: DateTime.now(),
              ),
            );
          }
          return result;
        }
      }
    } catch (e) {
      Log.w(_tag, 'Failed to fetch live danmaku history: $e');
    }
    return const [];
  }

  Future<void> connect(int roomId, {int uid = 0}) async {
    if (_activeRoomId == roomId && _socket != null) {
      return;
    }
    final token = ++_connectionToken;
    _activeRoomId = roomId;
    _activeUid = uid;
    _reconnectAttempts = 0;
    await _closeSocketOnly();
    await _openConnection(roomId, uid: uid, token: token);
  }

  Future<void> _openConnection(
    int roomId, {
    required int uid,
    required int token,
  }) async {
    if (token != _connectionToken || _activeRoomId != roomId) return;

    try {
      await Request().ensureBuvidCookies();
      if (token != _connectionToken) return;

      final infoResp = await Request().get(
        Api.urlLiveDanmuInfo,
        baseUrl: Api.urlLiveBase,
        params: {'id': roomId, 'type': 0},
        useWbi: true,
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (token != _connectionToken) return;

      String danmuToken = '';
      final List<String> wsUrls = [];
      if (infoResp is Map && infoResp['code'] == 0) {
        final data = infoResp['data'];
        if (data is Map) {
          danmuToken = data['token']?.toString() ?? '';
          final hostList = data['host_list'];
          if (hostList is List) {
            for (final host in hostList) {
              if (host is! Map) continue;
              final domain = host['host']?.toString() ?? '';
              final wssPort = host['wss_port'] ?? 443;
              if (domain.isNotEmpty) {
                wsUrls.add('wss://$domain:$wssPort/sub');
              }
            }
          }
        }
      }
      if (wsUrls.isEmpty) {
        wsUrls.add('wss://broadcastlv.chat.bilibili.com:443/sub');
      }

      String buvid = '';
      try {
        final cookieJar = await Request().cookieJar;
        final cookies = await cookieJar.loadForRequest(
          Uri.parse('https://live.bilibili.com/'),
        );
        for (final cookie in cookies) {
          if (cookie.name == 'buvid3' && cookie.value.isNotEmpty) {
            buvid = cookie.value;
            break;
          }
        }
      } catch (_) {}

      WebSocket? connected;
      for (final wsUrl in wsUrls) {
        if (token != _connectionToken) return;
        try {
          connected = await WebSocket.connect(
            wsUrl,
            headers: {
              'Origin': 'https://live.bilibili.com',
              'User-Agent': HttpConstants.userAgent,
            },
          ).timeout(const Duration(seconds: 6));
          break;
        } catch (e) {
          Log.w(_tag, 'Live danmaku WebSocket connect failed ($wsUrl): $e');
        }
      }

      if (connected == null) {
        _scheduleReconnect(roomId, token);
        return;
      }
      if (token != _connectionToken) {
        await connected.close();
        return;
      }

      _socket = connected;
      _reconnectAttempts = 0;

      connected.add(
        LiveDanmakuPacketParser.encodeAuthPacket(
          roomId: roomId,
          token: danmuToken,
          uid: uid,
          buvid: buvid,
        ),
      );
      connected.add(LiveDanmakuPacketParser.encodeHeartbeatPacket());

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (token == _connectionToken && _socket != null) {
          try {
            _socket!.add(LiveDanmakuPacketParser.encodeHeartbeatPacket());
          } catch (_) {}
        }
      });

      _socketSub = connected.listen(
        (dynamic event) {
          if (token != _connectionToken || _controller.isClosed) return;
          Uint8List? raw;
          if (event is Uint8List) {
            raw = event;
          } else if (event is List<int>) {
            raw = Uint8List.fromList(event);
          }
          if (raw == null) return;
          final parsed = LiveDanmakuPacketParser.decodePackets(raw);
          for (final msg in parsed) {
            if (!_controller.isClosed) {
              _controller.add(msg);
            }
          }
        },
        onError: (Object error) {
          Log.w(_tag, 'Live danmaku socket error: $error');
          if (token == _connectionToken) {
            _scheduleReconnect(roomId, token);
          }
        },
        onDone: () {
          if (token == _connectionToken) {
            _scheduleReconnect(roomId, token);
          }
        },
      );
    } catch (e) {
      Log.w(_tag, 'Failed to initialize live danmaku stream: $e');
      if (token == _connectionToken) {
        _scheduleReconnect(roomId, token);
      }
    }
  }

  void _scheduleReconnect(int roomId, int token) {
    if (token != _connectionToken || _activeRoomId != roomId) return;
    if (_reconnectAttempts >= 5) return;
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (token == _connectionToken && _activeRoomId == roomId) {
        _openConnection(roomId, uid: _activeUid, token: token);
      }
    });
  }

  Future<void> _closeSocketOnly() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    final sock = _socket;
    _socket = null;
    if (sock != null) {
      try {
        await sock.close();
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    _connectionToken++;
    _activeRoomId = null;
    await _closeSocketOnly();
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}

