import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/search/search_collection_fragment.dart';
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
  late TabController _tabController;
  String _currentKeyword = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _doSearch(String keyword) {
    if (keyword.isEmpty) return;
    setState(() {
      _currentKeyword = keyword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索视频...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          style: TextStyle(color: colorScheme.onSurface),
          textInputAction: TextInputAction.search,
          onSubmitted: _doSearch,
          autofocus: true,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          SearchVideoFragment(
            onSongSelected: widget.onSongSelected,
            keyword: _currentKeyword,
          ),
          SearchCollectionFragment(
            onSongSelected: widget.onSongSelected,
            keyword: _currentKeyword,
          ),
          SearchUserFragment(
            onSongSelected: widget.onSongSelected,
            keyword: _currentKeyword,
          ),
        ],
      ),
    );
  }
}
