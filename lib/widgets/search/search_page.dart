import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/full_player_page.dart';
import 'package:utopia_music/widgets/player/mini_player.dart';
import 'package:utopia_music/widgets/search/search_collection_fragment.dart';
import 'package:utopia_music/widgets/search/search_history.dart';
import 'package:utopia_music/widgets/search/search_user_fragment.dart';
import 'package:utopia_music/widgets/search/search_video_fragment.dart';

class SearchPage extends StatefulWidget {
  final Function(Song) onSongSelected;

  const SearchPage({super.key, required this.onSongSelected});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;
  String _currentKeyword = '';
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _historyOverlay;
  List<String> _history = [];
  static const String _historyKey = 'search_history';
  static const int _maxHistory = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadHistory().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Auto focus when entering the page
        _searchFocusNode.requestFocus();
        if (_searchController.text.isEmpty && _currentKeyword.isEmpty) {
           _showHistoryOverlay(); 
        }
      });
    });
    
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        _showHistoryOverlay();
      } else if (!_searchFocusNode.hasFocus) {
        // Delay removal to allow tap on history item to register
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
             _removeHistoryOverlay();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _removeHistoryOverlay();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _history = prefs.getStringList(_historyKey) ?? [];
      });
    }
  }

  Future<void> _addHistory(String keyword) async {
    if (keyword.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.remove(keyword);
    history.insert(0, keyword);
    if (history.length > _maxHistory) {
      history = history.sublist(0, _maxHistory);
    }
    await prefs.setStringList(_historyKey, history);
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) {
      setState(() {
        _history = [];
      });
      _removeHistoryOverlay();
      _showHistoryOverlay();
    }
  }

  Future<void> _removeHistoryItem(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.remove(keyword);
    await prefs.setStringList(_historyKey, history);
    if (mounted) {
      setState(() {
        _history = history;
      });
      _removeHistoryOverlay();
      _showHistoryOverlay();
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty && _currentKeyword.isEmpty) {
      if (_searchFocusNode.hasFocus) {
         _showHistoryOverlay();
      }
    } else {
      _removeHistoryOverlay();
    }
  }

  void _showHistoryOverlay() {
    if (_historyOverlay != null) return;
    if (_history.isEmpty) return;

    _historyOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _removeHistoryOverlay();
                _searchFocusNode.unfocus();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // History Dropdown
          Positioned(
            width: MediaQuery.of(context).size.width - 112, // Screen width - (leading width + actions width)
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 50),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                child: SearchHistory(
                  history: _history,
                  onSearch: _doSearch,
                  onDelete: _removeHistoryItem,
                  onClear: _clearHistory,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_historyOverlay!);
  }

  void _removeHistoryOverlay() {
    _historyOverlay?.remove();
    _historyOverlay = null;
  }

  void _doSearch(String keyword) {
    if (keyword.isEmpty) return;
    _searchController.text = keyword;
    _addHistory(keyword);
    setState(() {
      _currentKeyword = keyword;
    });
    _removeHistoryOverlay();
    _searchFocusNode.unfocus();
  }

  void _handleSongSelected(Song song) {
    // Ensure focus is removed when a song is selected
    _searchFocusNode.unfocus();
    widget.onSongSelected(song);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        if (playerProvider.isPlayerExpanded) {
          playerProvider.collapsePlayer();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Consumer<PlayerProvider>(
        builder: (context, playerProvider, child) {
          final currentSong = playerProvider.currentSong;
          final isPlayerExpanded = playerProvider.isPlayerExpanded;
          final showFullPlayer = playerProvider.showFullPlayer;
          final isPlaying = playerProvider.isPlaying;

          // If full player is expanded, ensure keyboard is dismissed
          if (isPlayerExpanded && _searchFocusNode.hasFocus) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               _searchFocusNode.unfocus();
             });
          }

          return Stack(
            children: [
              Scaffold(
                resizeToAvoidBottomInset: false, // Prevent resizing when keyboard appears
                appBar: AppBar(
                  title: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: '搜索视频...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      style: TextStyle(color: colorScheme.onSurface),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _doSearch,
                      autofocus: true, 
                      onTap: () {
                        if (_searchController.text.isEmpty) {
                          _showHistoryOverlay();
                        }
                      },
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _doSearch(_searchController.text),
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: '视频'),
                      Tab(text: '合集'),
                      Tab(text: '用户'),
                    ],
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                  ),
                ),
                body: GestureDetector(
                  onTap: () {
                    _searchFocusNode.unfocus();
                    _removeHistoryOverlay();
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            SearchVideoFragment(
                              onSongSelected: _handleSongSelected,
                              keyword: _currentKeyword,
                            ),
                            SearchCollectionFragment(
                              onSongSelected: _handleSongSelected,
                              keyword: _currentKeyword,
                            ),
                            SearchUserFragment(
                              onSongSelected: _handleSongSelected,
                              keyword: _currentKeyword,
                            ),
                          ],
                        ),
                      ),
                      // Add padding at the bottom equal to mini player height if it's visible
                      // Use MediaQuery.of(context).viewInsets.bottom to adjust for keyboard
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: (currentSong != null && !isPlayerExpanded) 
                            ? 80 + MediaQuery.of(context).viewInsets.bottom 
                            : MediaQuery.of(context).viewInsets.bottom,
                      ),
                    ],
                  ),
                ),
              ),
              if (showFullPlayer && currentSong != null)
                Positioned.fill(
                  child: AnimatedSlide(
                    offset: isPlayerExpanded ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: FullPlayerPage(
                        song: currentSong,
                        onCollapse: playerProvider.collapsePlayer,
                        onSongSelected: playerProvider.playSong,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom, // Float above keyboard
                child: AnimatedSlide(
                  offset: (currentSong != null && !isPlayerExpanded)
                      ? Offset.zero
                      : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    height: (currentSong != null && !isPlayerExpanded) ? 80 : 0,
                    child: currentSong != null
                        ? SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: SafeArea(
                              top: false,
                              child: MiniPlayer(
                                song: currentSong,
                                isPlaying: isPlaying,
                                onTap: () {
                                  _searchFocusNode.unfocus(); // Ensure keyboard is closed
                                  playerProvider.togglePlayerExpansion();
                                },
                                onPlayPause: playerProvider.togglePlayPause,
                                onNext: () {}, // Handled internally by MiniPlayer using Provider
                                onPrevious: () {}, // Handled internally by MiniPlayer using Provider
                                onClose: playerProvider.closePlayer,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
