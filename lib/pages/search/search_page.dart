import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';
import 'package:utopia_music/widgets/player/mini_player.dart';
import 'package:utopia_music/pages/search/fragment/search_collection_fragment.dart';
import 'package:utopia_music/widgets/search/search_history.dart';
import 'package:utopia_music/widgets/search/search_suggest.dart';
import 'package:utopia_music/pages/search/fragment/search_live_fragment.dart';
import 'package:utopia_music/pages/search/fragment/search_user_fragment.dart';
import 'package:utopia_music/pages/search/fragment/search_video_fragment.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/connection/video/search.dart';

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
  int _searchTimestamp = 0;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _historyOverlay;
  OverlayEntry? _suggestOverlay;
  List<String> _history = [];
  List<String> _suggestions = [];
  static const String _historyKey = 'search_history';
  final SearchApi _searchApi = SearchApi();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _searchController.addListener(_onSearchChanged);
    _loadHistory().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
        if (_searchController.text.isEmpty) {
           _showHistoryOverlay(); 
        }
      });
    });
    
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        if (_searchController.text.isEmpty) {
          _showHistoryOverlay();
        } else {
          _showSuggestOverlay();
        }
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
             _removeHistoryOverlay();
             _removeSuggestOverlay();
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
    _removeSuggestOverlay();
    _debounce?.cancel();
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
    
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.saveSearchHistory) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.remove(keyword);
    history.insert(0, keyword);
    
    final limit = settingsProvider.searchHistoryLimit;
    if (history.length > limit) {
      history = history.sublist(0, limit);
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
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      final text = _searchController.text;
      if (text.isEmpty) {
        _removeSuggestOverlay();
        if (_searchFocusNode.hasFocus) {
           _showHistoryOverlay();
        }
      } else {
        _removeHistoryOverlay();
        _fetchSuggestions(text);
      }
    });
  }

  Future<void> _fetchSuggestions(String keyword) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.showSearchSuggest) return;

    try {
      final suggestions = await _searchApi.getSearchSuggestions(keyword);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });

        if (_suggestions.isNotEmpty && _searchFocusNode.hasFocus) {
          _showSuggestOverlay();
        } else {
          _removeSuggestOverlay();
        }
      }
    } catch (e) {
      print("搜索建议获取失败: $e");
      if (mounted) _removeSuggestOverlay();
    }
  }

  void _showHistoryOverlay() {
    _removeSuggestOverlay();
    if (_historyOverlay != null) return;
    
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.saveSearchHistory) return;

    if (_history.isEmpty) return;

    _historyOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
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
          Positioned(
            width: MediaQuery.of(context).size.width - 112,
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

  void _showSuggestOverlay() {
    _removeHistoryOverlay();
    if (_suggestOverlay != null) {
      _suggestOverlay!.remove();
      _suggestOverlay = null;
    }

    if (_suggestions.isEmpty) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Size? leaderSize = _layerLink.leaderSize;
    final double width = leaderSize?.width ?? MediaQuery.of(context).size.width - 80;

    _suggestOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _removeSuggestOverlay();
                _searchFocusNode.unfocus();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, (leaderSize?.height ?? 50) + 5),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SearchSuggest(
                    suggestions: _suggestions,
                    onSelected: _doSearch,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_suggestOverlay!);
  }

  void _removeHistoryOverlay() {
    _historyOverlay?.remove();
    _historyOverlay = null;
  }

  void _removeSuggestOverlay() {
    _suggestOverlay?.remove();
    _suggestOverlay = null;
  }

  void _doSearch(String keyword) {
    if (keyword.isEmpty) return;
    _searchController.text = keyword;
    _addHistory(keyword);
    setState(() {
      _currentKeyword = keyword;
      _searchTimestamp = DateTime.now().millisecondsSinceEpoch;
    });
    _removeHistoryOverlay();
    _removeSuggestOverlay();
    _searchFocusNode.unfocus();
  }

  void _handleSongSelected(Song song) {
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
          if (isPlayerExpanded && _searchFocusNode.hasFocus) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               _searchFocusNode.unfocus();
             });
          }

          return Stack(
            children: [
              Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  title: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: S.of(context).pages_search_hint_search_input,
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
                        } else {
                          _showSuggestOverlay();
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
                    tabs: [
                      Tab(text: S.of(context).pages_search_tag_live),
                      Tab(text: S.of(context).pages_search_tag_video),
                      Tab(text: S.of(context).pages_search_tag_collection),
                      Tab(text: S.of(context).pages_search_tag_user),
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
                    _removeSuggestOverlay();
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            SearchLiveFragment(
                              keyword: _currentKeyword,
                            ),
                            SearchVideoFragment(
                              onSongSelected: _handleSongSelected,
                              keyword: _currentKeyword,
                              searchTimestamp: _searchTimestamp,
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: (currentSong != null && !isPlayerExpanded) 
                            ? 80 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom
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
                bottom: MediaQuery.of(context).viewInsets.bottom,
                child: AnimatedSlide(
                  offset: (currentSong != null && !isPlayerExpanded)
                      ? Offset.zero
                      : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    height: (currentSong != null && !isPlayerExpanded) 
                        ? 80 + MediaQuery.of(context).padding.bottom 
                        : 0,
                    child: currentSong != null
                        ? SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MiniPlayer(
                                  song: currentSong,
                                  isPlaying: isPlaying,
                                  onTap: () {
                                    _searchFocusNode.unfocus();
                                    playerProvider.togglePlayerExpansion();
                                  },
                                  onPlayPause: playerProvider.togglePlayPause,
                                  onNext: () {},
                                  onPrevious: () {},
                                  onClose: playerProvider.closePlayer,
                                ),
                                SizedBox(height: MediaQuery.of(context).padding.bottom),
                              ],
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
