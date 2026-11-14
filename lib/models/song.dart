class Song {
  final String title;
  final String originTitle;
  final String artist;
  final String coverUrl;
  final String lyrics;
  final int colorValue;
  final String bvid;
  final int cid;
  final int? durationSeconds;
  final int? viewCount;
  final int? danmakuCount;
  final bool isFollowed;

  const Song({
    required this.title,
    String? originTitle,
    required this.artist,
    required this.coverUrl,
    required this.lyrics,
    required this.colorValue,
    required this.bvid,
    required this.cid,
    this.durationSeconds,
    this.viewCount,
    this.danmakuCount,
    this.isFollowed = false,
  }) : originTitle = originTitle ?? title;

  Song copyWith({
    String? title,
    String? originTitle,
    String? artist,
    String? coverUrl,
    String? lyrics,
    int? colorValue,
    String? bvid,
    int? cid,
    int? durationSeconds,
    int? viewCount,
    int? danmakuCount,
    bool? isFollowed,
  }) {
    return Song(
      title: title ?? this.title,
      originTitle: originTitle ?? this.originTitle,
      artist: artist ?? this.artist,
      coverUrl: coverUrl ?? this.coverUrl,
      lyrics: lyrics ?? this.lyrics,
      colorValue: colorValue ?? this.colorValue,
      bvid: bvid ?? this.bvid,
      cid: cid ?? this.cid,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      viewCount: viewCount ?? this.viewCount,
      danmakuCount: danmakuCount ?? this.danmakuCount,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }
}
