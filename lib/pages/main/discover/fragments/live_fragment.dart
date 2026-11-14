import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/live/live_api.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/widgets/live/live_room_card.dart';

class LiveFragment extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final LiveApi? liveApi;

  const LiveFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
    this.liveApi,
  });

  @override
  State<LiveFragment> createState() => _LiveFragmentState();
}

class _LiveFragmentState extends State<LiveFragment>
    with AutomaticKeepAliveClientMixin {
  late final LiveApi _liveApi;

  List<LiveRoom> _followedRooms = [];
  List<LiveRoom> _recommendedRooms = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreRecommended = true;
  bool _hasError = false;
  int _recommendPage = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _liveApi = widget.liveApi ?? LiveApi();
    widget.scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    if (widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent - 240 &&
        !_isLoadingMore &&
        _hasMoreRecommended &&
        !_isInitialLoading) {
      _loadMoreRecommended();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _hasError = false;
      _recommendPage = 1;
      _hasMoreRecommended = true;
    });

    try {
      final isLoggedIn = _readIsLoggedIn();
      final followedFuture = isLoggedIn
          ? _liveApi.getFollowedLiveRooms(page: 1, pageSize: 20)
          : Future.value(<LiveRoom>[]);
      final recommendFuture = _liveApi.getRecommendedLiveRooms(
        page: 1,
        pageSize: 20,
      );

      final results = await Future.wait([followedFuture, recommendFuture]);
      if (!mounted) return;
      setState(() {
        _followedRooms = results[0];
        _recommendedRooms = results[1];
        _isInitialLoading = false;
        _hasMoreRecommended = _recommendedRooms.isNotEmpty;
        _hasError = _followedRooms.isEmpty && _recommendedRooms.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _hasError = _followedRooms.isEmpty && _recommendedRooms.isEmpty;
      });
    }
  }

  bool _readIsLoggedIn() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).isLoggedIn;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadMoreRecommended() async {
    if (_isLoadingMore || !_hasMoreRecommended) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _recommendPage + 1;
    try {
      final more = await _liveApi.getRecommendedLiveRooms(
        page: nextPage,
        pageSize: 20,
      );
      if (!mounted) return;
      final existingIds = _recommendedRooms.map((r) => r.roomId).toSet();
      final filtered = more
          .where((r) => !existingIds.contains(r.roomId))
          .toList();
      setState(() {
        _recommendPage = nextPage;
        _recommendedRooms.addAll(filtered);
        _hasMoreRecommended = more.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, int? count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isInitialLoading &&
        _followedRooms.isEmpty &&
        _recommendedRooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _followedRooms.isEmpty && _recommendedRooms.isEmpty) {
      return RefreshIndicator(
        key: widget.refreshIndicatorKey,
        onRefresh: _loadInitial,
        child: ListView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.28),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(S.of(context).pages_discover_error_network),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadInitial,
                    child: Text(S.of(context).common_retry),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool isLoggedIn = _readIsLoggedIn();

    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: _loadInitial,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final delegate = LiveRoomCard.gridDelegateForWidth(
            constraints.maxWidth,
          );
          return Scrollbar(
            controller: widget.scrollController,
            thumbVisibility: false,
            interactive: true,
            thickness: 6,
            radius: const Radius.circular(3),
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    S.of(context).live_followed_section,
                    _followedRooms.length,
                  ),
                ),
                if (_followedRooms.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate: delegate,
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return LiveRoomCard(room: _followedRooms[index]);
                      }, childCount: _followedRooms.length),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isLoggedIn
                              ? S.of(context).live_followed_empty
                              : S.of(context).weight_video_detail_please_login_first,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    S.of(context).live_recommend_section,
                    null,
                  ),
                ),
                if (_recommendedRooms.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate: delegate,
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return LiveRoomCard(room: _recommendedRooms[index]);
                      }, childCount: _recommendedRooms.length),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(S.of(context).common_no_data),
                      ),
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
                        : (!_hasMoreRecommended
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
      ),
    );
  }
}
