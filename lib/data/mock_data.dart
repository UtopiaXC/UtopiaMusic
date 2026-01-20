import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';

class MockData {
  static final List<Song> songs = List.generate(2, (index) {
    final isEven = index % 2 == 0;
    final colorValue = Colors.primaries[index % Colors.primaries.length].value;
    
    if (index == 0) {
      return const Song(
        title: '我多想说再见啊（星尘Infinity）',
        artist: '柯立可',
        album: '我多想说再见啊（星尘Infinity）',
        coverUrl: 'http://p2.music.126.net/CT6BsF4MRFvsePrksk1DDw==/109951167161932342.jpg',
        lyrics: 'Lyrics for song 1...',
        colorValue: 0xFF2196F3,
        audioUrl: 'https://music.163.com/song/media/outer/url?id=2138287436.mp3',
      );
    } else if (index == 1) {
      return const Song(
        title: '星与你消失之日-完整版（Cover 泠鸢Yousa）',
        artist: '茶理理',
        album: '猹狸翻唱场',
        coverUrl: 'http://p1.music.126.net/DI-2I0o_IdDr5HCejn4EFw==/109951162920736376.jpg',
        lyrics: 'Lyrics for song 2...',
        colorValue: 0xFF4CAF50,
        audioUrl: 'https://music.163.com/song/media/outer/url?id=480428670.mp3',
      );
    }

    return Song(
      title: isEven ? '测试歌曲 1 (重复 $index)' : '测试歌曲 2 (重复 $index)',
      artist: isEven ? '歌手 A' : '歌手 B',
      album: '测试专辑',
      coverUrl: isEven 
          ? 'http://p2.music.126.net/CT6BsF4MRFvsePrksk1DDw==/109951167161932342.jpg'
          : 'http://p1.music.126.net/DI-2I0o_IdDr5HCejn4EFw==/109951162920736376.jpg',
      lyrics: 'This is the lyrics for song $index...\n\nLine 1\nLine 2\nLine 3\n...',
      colorValue: colorValue,
      audioUrl: isEven
          ? 'https://music.163.com/song/media/outer/url?id=2138287436.mp3'
          : 'https://music.163.com/song/media/outer/url?id=480428670.mp3',
    );
  });
}
