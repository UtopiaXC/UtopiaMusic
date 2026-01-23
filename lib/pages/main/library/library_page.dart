import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  void _handleCreateLocalPlaylist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        onSubmit: (title, description) async {
          await DatabaseService().createLocalPlaylist(title, description);
          if (mounted) {
            Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
          }
        },
      ),
    );
  }

  Future<void> _handleRefresh() async {
    Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
    // Simulate a delay or wait for actual refresh if possible
    // Since refreshLibrary just notifies listeners, it's instant.
    // But the widgets will reload data asynchronously.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('曲库'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'create_local') {
                _handleCreateLocalPlaylist();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'create_local',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 20),
                      SizedBox(width: 12),
                      Text('创建本地歌单'),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Consumer<LibraryProvider>(
          builder: (context, libraryProvider, child) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 120),
              itemCount: libraryProvider.categoryOrder.length,
              onReorder: libraryProvider.updateOrder,
              itemBuilder: (context, index) {
                final type = libraryProvider.categoryOrder[index];
                String title = '';
                switch (type) {
                  case PlaylistCategoryType.favorites:
                    title = '收藏夹';
                    break;
                  case PlaylistCategoryType.collections:
                    title = '合集';
                    break;
                  case PlaylistCategoryType.local:
                    title = '本地歌单';
                    break;
                }
                
                return Padding(
                  key: ValueKey(type),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PlaylistCategoryWidget(
                    type: type,
                    title: title,
                    // Pass refresh signal to force update when needed
                    refreshSignal: libraryProvider.refreshSignal,
                    onLoginTap: _showLoginDialog,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
