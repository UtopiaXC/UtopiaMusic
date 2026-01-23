class Song {
  final String title;
  final String originTitle; // Added for renaming support
  final String artist;
  final String coverUrl;
  final String lyrics;
  final int colorValue;
  final String bvid;
  final int cid;

  const Song({
    required this.title,
    String? originTitle,
    required this.artist,
    required this.coverUrl,
    required this.lyrics,
    required this.colorValue,
    required this.bvid,
    required this.cid,
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
    );
  }
}
