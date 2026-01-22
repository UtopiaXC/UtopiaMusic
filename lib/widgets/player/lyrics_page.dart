import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/player_controls.dart';
import 'package:just_audio/just_audio.dart';

class LyricsPage extends StatefulWidget {
  final VoidCallback onBack;

  const LyricsPage({
    super.key,
    required this.onBack,
  });

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    playerProvider.player.positionStream.listen((position) {
      if (mounted && !_isDragging) {
        setState(() {
          _position = position;
        });
      }
    });

    playerProvider.player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  void _onSeekStart(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
    });
  }

  void _onSeekUpdate(double value) {
    setState(() {
      _dragValue = value;
    });
  }

  void _onSeekEnd(double value) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final position = Duration(seconds: value.toInt());
    playerProvider.player.seek(position);

    if (!playerProvider.isPlaying || 
        playerProvider.player.processingState == ProcessingState.completed) {
      playerProvider.player.play();
    }

    setState(() {
      _isDragging = false;
      _position = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final song = playerProvider.currentSong;

    if (song == null) return const SizedBox();

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.primaryDelta! > 10) {
          widget.onBack();
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    song.lyrics.isEmpty ? '暂无歌词' : song.lyrics,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.8,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
              child: PlayerControls(
                isPlaying: playerProvider.isPlaying,
                isLoading: playerProvider.player.processingState == ProcessingState.buffering ||
                    playerProvider.player.processingState == ProcessingState.loading,
                duration: _duration,
                position: _isDragging
                    ? Duration(seconds: _dragValue.toInt())
                    : _position,
                loopMode: playerProvider.playMode,
                onSeek: _onSeekEnd,
                onSeekStart: _onSeekStart,
                onSeekUpdate: _onSeekUpdate,
                onPlayPause: playerProvider.togglePlayPause,
                onNext: playerProvider.hasNext ? () => playerProvider.playNext() : null,
                onPrevious: playerProvider.hasPrevious ? () => playerProvider.playPrevious() : null,
                onShuffle: playerProvider.togglePlayMode,
                onPlaylist: () {},
                onLyrics: widget.onBack,
                hideExtraControls: false,
                showLyricsButtonOnly: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
