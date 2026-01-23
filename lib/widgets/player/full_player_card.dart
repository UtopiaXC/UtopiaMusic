import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/lyrics_card.dart';
import 'package:utopia_music/widgets/player/player_content.dart';
import 'package:utopia_music/widgets/player/player_controls.dart';
import 'package:utopia_music/widgets/player/playlist_sheet.dart';
import 'package:utopia_music/widgets/player/swipeable_player_card.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'dart:async';

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
  bool _showLyrics = false;
  Timer? _timer;

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
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI for timer countdown
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  void _showTimerDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.isTimerActive) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('关闭定时器'),
          content: Text('当前停止时间为：${playerProvider.stopTime?.toString().split('.')[0]}\n是否关闭定时器？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                playerProvider.cancelTimer();
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _TimerDialog(),
      );
    }
  }

  void _showMoreDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.subscriptions_outlined),
                title: Text(S.of(context).play_control_mode_random_collection),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_motion),
                title: Text(S.of(context).play_control_mode_random_continue),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.high_quality),
                title: const Text('音质'),
                onTap: () {
                  Navigator.pop(context);
                  _showQualityDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showQualityDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('选择音质', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildQualityOption('低 (64K)'),
              _buildQualityOption('标准 (132K)'),
              _buildQualityOption('高 (192K)'),
              _buildQualityOption('杜比全景声 (大会员)'),
              _buildQualityOption('HiRes无损 (大会员)'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityOption(String title) {
    return ListTile(
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCardContent(BuildContext context, Song song, {bool isCurrent = false}) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    return Container(
      key: ValueKey('${song.bvid}_${song.cid}'),
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
              loopMode: playerProvider.playMode,
              onSeek: isCurrent ? _onSeekEnd : (v){},
              onSeekStart: isCurrent ? _onSeekStart : null,
              onSeekUpdate: isCurrent ? _onSeekUpdate : null,
              onPlayPause: isCurrent ? playerProvider.togglePlayPause : (){},
              onNext: isCurrent && playerProvider.hasNext ? () => playerProvider.playNext() : null,
              onPrevious: isCurrent && playerProvider.hasPrevious ? () => playerProvider.playPrevious() : null,
              onShuffle: isCurrent ? playerProvider.togglePlayMode : (){},
              onPlaylist: isCurrent ? _showPlaylist : (){},
              onLyrics: isCurrent ? _toggleLyrics : (){},
              onTimer: isCurrent ? _showTimerDialog : (){},
              onComment: isCurrent ? () {} : (){}, 
              onInfo: isCurrent ? () {} : (){}, 
              onMore: isCurrent ? _showMoreDialog : (){},
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
    if (hasPrevious && previousSong == null) previousSong = widget.song;
    if (hasNext && nextSong == null) nextSong = widget.song;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_showLyrics) {
          _toggleLyrics();
          return;
        }
        widget.onCollapse();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! > 10) {
              if (_showLyrics) {
                _toggleLyrics();
              }
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
                      onPressed: () {
                        if (_showLyrics) {
                          _toggleLyrics();
                        }
                        widget.onCollapse();
                      },
                      tooltip: S.of(context).common_retract,
                    ),
                    middle: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: MediaQuery.of(context).size.width * 0.6,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textStyle = const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              );
                              final textSpan = TextSpan(text: widget.song.title, style: textStyle);
                              final textPainter = TextPainter(
                                text: textSpan,
                                textDirection: TextDirection.ltr,
                                maxLines: 1,
                              );
                              textPainter.layout();
                              
                              if (textPainter.width > constraints.maxWidth) {
                                return Marquee(
                                  text: widget.song.title,
                                  style: textStyle,
                                  scrollAxis: Axis.horizontal,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  blankSpace: 20.0,
                                  velocity: 30.0,
                                  pauseAfterRound: const Duration(seconds: 1),
                                  startPadding: 0.0,
                                  accelerationDuration: const Duration(seconds: 1),
                                  accelerationCurve: Curves.linear,
                                  decelerationDuration: const Duration(milliseconds: 500),
                                  decelerationCurve: Curves.easeOut,
                                );
                              } else {
                                return Text(
                                  widget.song.title,
                                  style: textStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                );
                              }
                            },
                          ),
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
                  child: Stack(
                    children: [
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        offset: _showLyrics ? const Offset(-1, 0) : Offset.zero,
                        child: SwipeablePlayerCard(
                          onNext: hasNext ? () => playerProvider.playNext() : null,
                          onPrevious: hasPrevious ? () => playerProvider.playPrevious() : null,
                          previousChild: previousSong != null ? _buildCardContent(context, previousSong) : null,
                          nextChild: nextSong != null ? _buildCardContent(context, nextSong) : null,
                          child: _buildCardContent(context, widget.song, isCurrent: true),
                        ),
                      ),
                      
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        offset: _showLyrics ? Offset.zero : const Offset(1, 0),
                        child: LyricsPage(onBack: _toggleLyrics),
                      ),
                    ],
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

class _TimerDialog extends StatefulWidget {
  const _TimerDialog();

  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _stopAfterCurrent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setTimer(int minutes) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.setStopTimer(Duration(minutes: minutes), stopAfterCurrent: _stopAfterCurrent);
    Navigator.pop(context);
  }

  void _showCustomTimerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义倒计时'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '分钟', suffixText: 'min'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                _setTimer(minutes);
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _stopAfterCurrent,
                onChanged: (value) {
                  setState(() {
                    _stopAfterCurrent = value ?? false;
                  });
                },
                title: const Text('播放完当前曲目后停止'),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '倒计时关闭'),
                  Tab(text: '指定时间关闭'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCountdownTab(),
                    _buildSpecificTimeTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownTab() {
    return ListView(
      children: [
        ListTile(title: const Text('15 分钟'), onTap: () => _setTimer(15)),
        ListTile(title: const Text('30 分钟'), onTap: () => _setTimer(30)),
        ListTile(title: const Text('60 分钟'), onTap: () => _setTimer(60)),
        ListTile(title: const Text('90 分钟'), onTap: () => _setTimer(90)),
        ListTile(title: const Text('自定义'), onTap: _showCustomTimerDialog),
      ],
    );
  }

  Widget _buildSpecificTimeTab() {
    return Center(
      child: FilledButton(
        onPressed: () async {
          final now = TimeOfDay.now();
          final time = await showTimePicker(
            context: context,
            initialTime: now,
          );
          if (time != null) {
            final nowDateTime = DateTime.now();
            var selectedDateTime = DateTime(
              nowDateTime.year,
              nowDateTime.month,
              nowDateTime.day,
              time.hour,
              time.minute,
            );
            if (selectedDateTime.isBefore(nowDateTime)) {
              selectedDateTime = selectedDateTime.add(const Duration(days: 1));
            }
            
            if (mounted) {
              final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
              playerProvider.setStopTime(selectedDateTime, stopAfterCurrent: _stopAfterCurrent);
              Navigator.pop(context);
            }
          }
        },
        child: const Text('选择时间'),
      ),
    );
  }
}
