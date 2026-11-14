import 'package:utopia_music/models/song.dart';

/// Represents a Bilibili live streaming room.
/// Strictly decoupled from VOD [Song] persistence and queue models.
class LiveRoom {
  final int roomId;
  final int uid;
  final String uname;
  final String face;
  final String title;
  final String cover;
  final String areaName;
  final int online;
  final bool isLive;
  final bool isFollowed;

  const LiveRoom({
    required this.roomId,
    required this.uid,
    required this.uname,
    required this.face,
    required this.title,
    required this.cover,
    this.areaName = '',
    this.online = 0,
    this.isLive = true,
    this.isFollowed = false,
  });

  LiveRoom copyWith({
    int? roomId,
    int? uid,
    String? uname,
    String? face,
    String? title,
    String? cover,
    String? areaName,
    int? online,
    bool? isLive,
    bool? isFollowed,
  }) {
    return LiveRoom(
      roomId: roomId ?? this.roomId,
      uid: uid ?? this.uid,
      uname: uname ?? this.uname,
      face: face ?? this.face,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      areaName: areaName ?? this.areaName,
      online: online ?? this.online,
      isLive: isLive ?? this.isLive,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }

  static String normalizeImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('http://')) return raw.replaceFirst('http://', 'https://');
    return raw;
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory LiveRoom.fromFollowedJson(Map<String, dynamic> json) {
    return LiveRoom(
      roomId: _asInt(json['roomid']),
      uid: _asInt(json['uid']),
      uname: (json['uname'] ?? '').toString(),
      face: normalizeImageUrl(json['face']?.toString()),
      title: (json['title'] ?? '').toString(),
      cover: normalizeImageUrl(
        (json['cover_from_user'] ?? json['keyframe'] ?? json['face'])
            ?.toString(),
      ),
      areaName: (json['area_name_v2'] ?? json['area_name'] ?? '').toString(),
      online: _asInt(json['online']),
      isLive: _asInt(json['live_status']) == 1,
      isFollowed: true,
    );
  }

  factory LiveRoom.fromRecommendJson(Map<String, dynamic> json) {
    return LiveRoom(
      roomId: _asInt(json['roomid'] ?? json['room_id']),
      uid: _asInt(json['uid'] ?? json['up_id']),
      uname: (json['uname'] ?? '').toString(),
      face: normalizeImageUrl(json['face']?.toString()),
      title: (json['title'] ?? '').toString(),
      cover: normalizeImageUrl(
        (json['cover'] ??
                json['user_cover'] ??
                json['system_cover'] ??
                json['keyframe'])
            ?.toString(),
      ),
      areaName: (json['area_v2_name'] ??
              json['area_name'] ??
              json['area_v2_parent_name'] ??
              json['parent_name'] ??
              '')
          .toString(),
      online: _asInt(json['online']),
      isLive: true,
      isFollowed: false,
    );
  }

  factory LiveRoom.fromSearchJson(
    Map<String, dynamic> json, {
    required String cleanedTitle,
    required String cleanedUname,
  }) {
    final liveStatus = json['live_status'];
    return LiveRoom(
      roomId: _asInt(json['roomid']),
      uid: _asInt(json['uid']),
      uname: cleanedUname,
      face: normalizeImageUrl(json['uface']?.toString()),
      title: cleanedTitle,
      cover: normalizeImageUrl(
        (json['user_cover'] ?? json['cover'] ?? json['uface'])?.toString(),
      ),
      areaName: (json['cate_name'] ?? '').toString(),
      online: _asInt(json['online']),
      isLive: liveStatus == null ? true : _asInt(liveStatus) == 1,
      isFollowed: false,
    );
  }

  /// Creates a read-only display projection for rendering inside unified player UI.
  Song toDisplaySong() {
    final resolvedCover = cover.isNotEmpty ? cover : face;
    return Song(
      title: title.isNotEmpty ? title : '$roomId',
      artist: uname,
      coverUrl: resolvedCover,
      lyrics: '',
      colorValue: 0,
      bvid: 'LIVE_$roomId',
      cid: roomId,
    );
  }
}
