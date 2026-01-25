import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/pages/main/library/downloaded_sheet.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';
import 'package:utopia_music/connection/user/user.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  late VoidCallback _authListener;
  final UserApi _userApi = UserApi();

  @override
  void initState() {
    super.initState();
    _authListener = () {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn) {
        Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
      }
    };

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.addListener(_authListener);
  }

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.removeListener(_authListener);
    super.dispose();
  }

  void _handleCreateLocalPlaylist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        onSubmit: (title, description) async {
          await DatabaseService().createLocalPlaylist(title, description);
          if (mounted) {
            Provider.of<LibraryProvider>(context, listen: false).refreshLibrary(localOnly: true);
          }
        },
      ),
    );
  }

  void _handleCreateBilibiliFolder() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showLoginDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BilibiliPlaylistCreateSheet(
        onSubmit: (title, description, isPublic) async {
          final success = await _userApi.createFavFolder(title, description, isPublic);
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('创建成功')),
              );
              Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('创建失败')),
              );
            }
          }
        },
      ),
    );
  }

  void _showDownloads() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DownloadedSheet(),
    );
  }

  Future<void> _handleRefresh() async {
    Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
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
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('曲库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showDownloads,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'create_local') {
                _handleCreateLocalPlaylist();
              } else if (value == 'create_bilibili') {
                _handleCreateBilibiliFolder();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'create_bilibili',
                  child: Row(
                    children: [
                      Icon(Icons.folder_special_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('创建 B 站收藏夹'),
                    ],
                  ),
                ),
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
            final visibleCategories = libraryProvider.visibleCategories;
            final fullList = libraryProvider.categoryOrder;
            
            return ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 120),
              itemCount: visibleCategories.length,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                 final oldType = visibleCategories[oldIndex];
                 final fullOldIndex = fullList.indexOf(oldType);
                 
                 int fullNewIndex;
                 
                 if (oldIndex < newIndex) {
                   final targetType = visibleCategories[newIndex - 1];
                   final fullTargetIndex = fullList.indexOf(targetType);
                   fullNewIndex = fullTargetIndex + 1;
                 } else {
                   final targetType = visibleCategories[newIndex];
                   fullNewIndex = fullList.indexOf(targetType);
                 }
                 
                 libraryProvider.updateOrder(fullOldIndex, fullNewIndex);
              },
              itemBuilder: (context, index) {
                final type = visibleCategories[index];
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
                
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(type),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PlaylistCategoryWidget(
                      type: type,
                      title: title,
                      refreshSignal: libraryProvider.refreshSignal,
                      onLoginTap: _showLoginDialog,
                      showDragHandle: isDesktop,
                      dragIndex: index,
                    ),
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

class _BilibiliPlaylistCreateSheet extends StatefulWidget {
  final Function(String title, String description, bool isPublic) onSubmit;

  const _BilibiliPlaylistCreateSheet({required this.onSubmit});

  @override
  State<_BilibiliPlaylistCreateSheet> createState() => _BilibiliPlaylistCreateSheetState();
}

class _BilibiliPlaylistCreateSheetState extends State<_BilibiliPlaylistCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await widget.onSubmit(_titleController.text, _descController.text, _isPublic);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '创建 B 站收藏夹',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: '标题',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入标题';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(
                            labelText: '简介',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('公开收藏夹'),
                          value: _isPublic,
                          onChanged: (value) {
                            setState(() {
                              _isPublic = value;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _handleSubmit,
                            child: const Text('创建'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }
}
