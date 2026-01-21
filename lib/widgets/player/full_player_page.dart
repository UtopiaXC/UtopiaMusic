import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/audio_player_service.dart';
import 'package:utopia_music/widgets/player/player_content.dart';
import 'package:utopia_music/widgets/player/player_controls.dart';
import 'package:utopia_music/widgets/player/playlist_sheet.dart';

class FullPlayerPage extends StatefulWidget {
  final Song song;
  final VoidCallback  onCollapse;
  final Function(Song) onSongSelected;

  const FullPlayerPage({
    super.key,
    required this.song,
    required this.onCollapse,
    required this.onSongSelected,
  });

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage> {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0.0;

  int _loopMode = 0;

  final List<Song> _playlist = [];

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayerService.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading;
        });
      }
    });

    _audioPlayerService.player.positionStream.listen((position) {
      if (mounted && !_isDragging) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayerService.player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayerService.player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayerService.pause();
    } else {
      _audioPlayerService.resume();
    }
  }

  void _playNext() {
    if (_playlist.isEmpty) return;

    int currentIndex = _playlist.indexWhere(
      (s) => s.bvid == widget.song.bvid && s.cid == widget.song.cid,
    );
    int nextIndex = 0;

    if (_loopMode == 2) {
      nextIndex = currentIndex;
      _audioPlayerService.player.seek(Duration.zero);
      _audioPlayerService.resume();
      return;
    } else if (_loopMode == 3) {
      nextIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length);
    } else {
      if (currentIndex < _playlist.length - 1) {
        nextIndex = currentIndex + 1;
      } else {
        if (_loopMode == 1) {
          nextIndex = 0;
        } else {
          _audioPlayerService.stop();
          return;
        }
      }
    }

    if (nextIndex >= 0 && nextIndex < _playlist.length) {
      widget.onSongSelected(_playlist[nextIndex]);
    }
  }

  void _playPrevious() {
    if (_playlist.isEmpty) return;

    int currentIndex = _playlist.indexWhere(
      (s) => s.bvid == widget.song.bvid && s.cid == widget.song.cid,
    );
    int prevIndex = 0;

    if (_loopMode == 3) {
      prevIndex = (currentIndex - 1 + _playlist.length) % _playlist.length;
    } else {
      if (currentIndex > 0) {
        prevIndex = currentIndex - 1;
      } else {
        prevIndex = _playlist.length - 1;
      }
    }

    if (prevIndex >= 0 && prevIndex < _playlist.length) {
      widget.onSongSelected(_playlist[prevIndex]);
    }
  }

  void _toggleLoopMode() {
    setState(() {
      _loopMode = (_loopMode + 1) % 4;
    });

    String modeName;
    switch (_loopMode) {
      case 0:
        modeName = '列表顺序';
        break;
      case 1:
        modeName = '列表循环';
        break;
      case 2:
        modeName = '单曲循环';
        break;
      case 3:
        modeName = '随机播放';
        break;
      default:
        modeName = '列表顺序';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(modeName), duration: const Duration(seconds: 1)),
    );
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
    final position = Duration(seconds: value.toInt());
    _audioPlayerService.player.seek(position);
    setState(() {
      _isDragging = false;
      _position = position;
    });
  }

  void _showPlaylist() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PlaylistSheet(
        playlist: _playlist,
        currentSong: widget.song,
        onSongSelected: widget.onSongSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        widget.onCollapse();
      },
      child: Scaffold(
        body: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! > 10) {
              widget.onCollapse();
            }
          },
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                SizedBox(height: topPadding + 12),
                SizedBox(
                  height: kToolbarHeight,
                  child: NavigationToolbar(
                    leading: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: widget.onCollapse,
                      tooltip: '收起',
                    ),
                    middle: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.song.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.song.artist,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    centerMiddle: true,
                  ),
                ),
                Expanded(child: PlayerContent(song: widget.song)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
                  child: PlayerControls(
                    isPlaying: _isPlaying,
                    isLoading: _isLoading,
                    duration: _duration,
                    position: _isDragging
                        ? Duration(seconds: _dragValue.toInt())
                        : _position,
                    loopMode: _loopMode,
                    onSeek: _onSeekEnd,
                    onSeekStart: _onSeekStart,
                    onSeekUpdate: _onSeekUpdate,
                    onPlayPause: _togglePlayPause,
                    onNext: _playNext,
                    onPrevious: _playPrevious,
                    onShuffle: _toggleLoopMode,
                    onPlaylist: _showPlaylist,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
