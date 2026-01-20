import 'package:just_audio/just_audio.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/utils/constants.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioStreamApi _audioStreamApi = AudioStreamApi();

  AudioPlayer get player => _player;

  Future<void> playSong(Song song) async {
    try {
      String? audioUrl;
      if (song.bvid.isNotEmpty && song.cid != 0) {
        audioUrl = await _audioStreamApi.getAudioStream(song.bvid, song.cid);
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _player.setUrl(
          audioUrl,
          headers: {
            'User-Agent': HttpConstants.userAgent,
            'Referer': HttpConstants.referer,
          },
        );
        await _player.play();
      } else {
        print("No audio url found for song: ${song.title}");
      }
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }
  
  void dispose() {
    _player.dispose();
  }
}
