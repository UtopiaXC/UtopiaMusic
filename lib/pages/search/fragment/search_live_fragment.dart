import 'package:flutter/material.dart';
import 'package:utopia_music/connection/live/live_api.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/widgets/live/live_room_card.dart';

class SearchLiveFragment extends StatefulWidget {
  final String keyword;
  final int searchTimestamp;
  final LiveApi? liveApi;

  const SearchLiveFragment({
    super.key,
    required this.keyword,
    this.searchTimestamp = 0,
    this.liveApi,
  });

  @override
  State<SearchLiveFragment> createState() => _SearchLiveFragmentState();
}

class _SearchLiveFragmentState extends State<SearchLiveFragment>
    with AutomaticKeepAliveClientMixin {
  late final LiveApi _liveApi;
  final ScrollController _scrollController = ScrollController();

  List<LiveRoom> _rooms = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  int _page = 1;
  String _activeKeyword = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _liveApi = widget.liveApi ?? LiveApi();
    _scrollController.addListener(_onScroll);
    if (widget.keyword.isNotEmpty) {
      _search(widget.keyword);
    }
  }

  @override
  void didUpdateWidget(SearchLiveFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyword != oldWidget.keyword ||
        (widget.keyword.isNotEmpty &&
            widget.searchTimestamp != oldWidget.searchTimestamp)) {
      _search(widget.keyword);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _activeKeyword.isNotEmpty) {
      _loadMore();
    }
  }

  Future<void> _search(String keyword) async {
    final trimmed = keyword.trim();
    _activeKeyword = trimmed;
    if (trimmed.isEmpty) {
      setState(() {
        _rooms = [];
        _isLoading = false;
        _hasError = false;
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _page = 1;
      _hasMore = true;
      _rooms = [];
    });

    try {
      final results = await _liveApi.searchLiveRooms(trimmed, page: 1);
      if (!mounted || _activeKeyword != trimmed) return;
      setState(() {
        _rooms = results;
        _isLoading = false;
        _hasMore = results.isNotEmpty;
      });
    } catch (_) {
      if (!mounted || _activeKeyword != trimmed) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _activeKeyword.isEmpty) return;
    final searchingKeyword = _activeKeyword;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;

    try {
      final more = await _liveApi.searchLiveRooms(
        searchingKeyword,
        page: nextPage,
      );
      if (!mounted || _activeKeyword != searchingKeyword) return;
      final existingIds = _rooms.map((r) => r.roomId).toSet();
      final filtered = more
          .where((r) => !existingIds.contains(r.roomId))
          .toList();
      setState(() {
        _page = nextPage;
        _rooms.addAll(filtered);
        _hasMore = more.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.keyword.trim().isEmpty) {
      return Center(child: Text(S.of(context).live_search_hint));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(S.of(context).pages_search_no_result),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _search(widget.keyword),
              child: Text(S.of(context).common_retry),
            ),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Center(child: Text(S.of(context).common_no_data));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final delegate = LiveRoomCard.gridDelegateForWidth(
          constraints.maxWidth,
        );

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: false,
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                sliver: SliverGrid(
                  gridDelegate: delegate,
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return LiveRoomCard(room: _rooms[index]);
                  }, childCount: _rooms.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: _isLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        )
                      : (!_hasMore
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    S.of(context).common_at_bottom,
                                    style: TextStyle(
                                      color: Theme.of(context).disabledColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(height: 36)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
