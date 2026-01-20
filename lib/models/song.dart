class Song {
  final String title;
  final String artist;
  final String album; // 新增专辑字段
  final String coverUrl;
  final String lyrics;
  final int colorValue;
  final String audioUrl;

  const Song({
    required this.title,
    required this.artist,
    required this.album, // 必填
    required this.coverUrl,
    required this.lyrics,
    required this.colorValue,
    required this.audioUrl,
  });
}
