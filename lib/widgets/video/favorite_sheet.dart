import 'package:flutter/material.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/generated/l10n.dart';

class FavoriteSheet extends StatefulWidget {
  final int aid;
  final int mid;

  const FavoriteSheet({super.key, required this.aid, required this.mid});

  @override
  State<FavoriteSheet> createState() => _FavoriteSheetState();
}

class _FavoriteSheetState extends State<FavoriteSheet> {
  final UserApi _userApi = UserApi();
  final VideoDetailApi _videoDetailApi = VideoDetailApi();

  List<Map<String, dynamic>> _folders = [];
  final Set<int> _selectedFolderIds = {};
  final Set<int> _initialSelectedFolderIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final list = await _userApi.getUserCreatedFavFoldersAll(
        widget.mid,
        widget.aid,
      );

      if (mounted) {
        setState(() {
          _folders = list;
          for (var folder in list) {
            if (folder['fav_state'] == 1) {
              _selectedFolderIds.add(folder['id']);
              _initialSelectedFolderIds.add(folder['id']);
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final Set<int> toAdd = _selectedFolderIds.difference(
      _initialSelectedFolderIds,
    );
    final Set<int> toRemove = _initialSelectedFolderIds.difference(
      _selectedFolderIds,
    );

    if (toAdd.isEmpty && toRemove.isEmpty) {
      Navigator.pop(context, _selectedFolderIds.isNotEmpty);
      return;
    }

    try {
      final success = await _videoDetailApi.actionFavList(
        widget.aid,
        addMediaIds: toAdd.toList(),
        delMediaIds: toRemove.toList(),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context, _selectedFolderIds.isNotEmpty);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(S.of(context).common_failed)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).common_network_error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).common_favourite,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(S.of(context).common_done),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  if (_isClosing) return false;

                  if (notification.metrics.pixels < -70 &&
                      notification.dragDetails != null) {
                    _isClosing = true;
                    Navigator.pop(context, _selectedFolderIds.isNotEmpty);
                    return true;
                  }
                  return false;
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: _folders.length,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    final int id = folder['id'];
                    final String title = folder['title'];
                    final int count = folder['media_count'];
                    final bool isSelected = _selectedFolderIds.contains(id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedFolderIds.add(id);
                          } else {
                            _selectedFolderIds.remove(id);
                          }
                        });
                      },
                      title: Text(title),
                      subtitle: Text('$count${S.of(context).weight_video_detail_contants}'),
                      secondary: const Icon(Icons.folder),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
