import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/player_content.dart';
import 'package:utopia_music/widgets/player/player_controls.dart';
import 'package:utopia_music/widgets/player/playlist_sheet.dart';
import 'package:utopia_music/widgets/player/swipeable_player_card.dart';

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
    
    // If paused or completed, resume playback after seek
    if (!playerProvider.isPlaying || 
        playerProvider.player.processingState == ProcessingState.completed) {
      playerProvider.player.play();
    }

    setState(() {
      _isDragging = false;
      _position = position;
    });
  }

  void _showPlaylist() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PlaylistSheet(
        playlist: playerProvider.playlist,
        currentSong: widget.song,
        onSongSelected: widget.onSongSelected,
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Song song, {bool isCurrent = false}) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(child: PlayerContent(song: song)),
          Padding(
            padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
            child: PlayerControls(
              isPlaying: isCurrent ? playerProvider.isPlaying : false,
              isLoading: isCurrent ? (playerProvider.player.processingState == ProcessingState.buffering ||
                  playerProvider.player.processingState == ProcessingState.loading) : false,
              duration: isCurrent ? _duration : Duration.zero,
              position: isCurrent ? (_isDragging
                  ? Duration(seconds: _dragValue.toInt())
                  : _position) : Duration.zero,
              loopMode: playerProvider.playMode.index,
              onSeek: isCurrent ? _onSeekEnd : (v){},
              onSeekStart: isCurrent ? _onSeekStart : null,
              onSeekUpdate: isCurrent ? _onSeekUpdate : null,
              onPlayPause: isCurrent ? playerProvider.togglePlayPause : (){},
              onNext: isCurrent && playerProvider.hasNext ? () => playerProvider.playNext() : null,
              onPrevious: isCurrent && playerProvider.hasPrevious ? () => playerProvider.playPrevious() : null,
              onShuffle: isCurrent ? playerProvider.togglePlayMode : (){},
              onPlaylist: isCurrent ? _showPlaylist : (){},
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final playerProvider = Provider.of<PlayerProvider>(context);

    // Determine if next/prev buttons should be enabled based on PlayMode and playlist position
    final hasNext = playerProvider.hasNext;
    final hasPrevious = playerProvider.hasPrevious;

    Song? previousSong;
    Song? nextSong;
    
    final playlist = playerProvider.playlist;
    final currentIndex = playlist.indexWhere((s) => s.bvid == widget.song.bvid && s.cid == widget.song.cid);
    
    if (currentIndex != -1 && playlist.isNotEmpty) {
       if (hasPrevious) {
         int prevIndex = currentIndex - 1;
         if (prevIndex < 0) prevIndex = playlist.length - 1;
         previousSong = playlist[prevIndex];
       }
       if (hasNext) {
         int nextIndex = currentIndex + 1;
         if (nextIndex >= playlist.length) nextIndex = 0;
         nextSong = playlist[nextIndex];
       }
    }
    // Fallback if playlist logic fails or empty
    if (hasPrevious && previousSong == null) previousSong = widget.song;
    if (hasNext && nextSong == null) nextSong = widget.song;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        widget.onCollapse();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                Expanded(
                  child: SwipeablePlayerCard(
                    onNext: hasNext ? () => playerProvider.playNext() : null,
                    onPrevious: hasPrevious ? () => playerProvider.playPrevious() : null,
                    previousChild: previousSong != null ? _buildCardContent(context, previousSong) : null,
                    nextChild: nextSong != null ? _buildCardContent(context, nextSong) : null,
                    child: _buildCardContent(context, widget.song, isCurrent: true),
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
