import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class LibraryApi {
  final HtmlUnescape _unescape = HtmlUnescape();

  Future<List<dynamic>> getCreatedFolders(int mid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlFavFolderCreatedListAll,
        baseUrl: Api.urlBase,
        params: {'up_mid': mid, 'platform': 'web'},
      );
      if (data != null && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      print('Error fetching created folders: $e');
    }
    return [];
  }

  Future<List<dynamic>> getCollectedFolders(int mid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      List<dynamic> allCollections = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final data = await Request().get(
          Api.urlFavFolderCollectedList,
          baseUrl: Api.urlBase,
          params: {'up_mid': mid, 'pn': page, 'ps': 20, 'platform': 'web'},
        );

        if (data != null && data['code'] == 0) {
          final list = data['data']['list'] ?? [];
          final count = data['data']['count'] ?? 0;

          if (list.isEmpty) {
            hasMore = false;
          } else {
            allCollections.addAll(list);
            if (allCollections.length >= count) {
              hasMore = false;
            } else {
              page++;
            }
          }
        } else {
          hasMore = false;
        }
      }
      return allCollections;
    } catch (e) {
      print('Error fetching collected folders: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getFolderInfo(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlFavFolderInfo,
        baseUrl: Api.urlBase,
        params: {'media_id': mediaId, 'platform': 'web'},
      );

      if (data != null && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching folder info: $e');
    }
    return null;
  }

  Future<List<Song>> getFolderResources(
    String mediaId,
    BuildContext context,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      List<Song> allSongs = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final data = await Request().get(
          Api.urlFavoriteResourceList,
          baseUrl: Api.urlBase,
          params: {
            'media_id': mediaId,
            'pn': page,
            'ps': 20,
            'platform': 'web',
          },
        );

        if (data != null && data['code'] == 0) {
          final List<dynamic> medias = data['data']['medias'] ?? [];
          final hasMoreData = data['data']['has_more'] ?? false;

          if (medias.isEmpty) {
            hasMore = false;
          } else {
            allSongs.addAll(
              medias.map((item) => _mapToSong(context, item)).toList(),
            );
            if (!hasMoreData) {
              hasMore = false;
            } else {
              page++;
            }
          }
        } else {
          hasMore = false;
        }
      }
      return allSongs;
    } catch (e) {
      print('Error fetching folder resources: $e');
    }
    return [];
  }

  Future<List<dynamic>> getFavoriteFolders(int mid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlFavFolderCreatedListAll,
        baseUrl: Api.urlBase,
        params: {'up_mid': mid, 'platform': 'web'},
      );
      if (data != null && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      print('Error fetching favorite folders: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getFavoriteFolderInfo(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlFavFolderInfo,
        baseUrl: Api.urlBase,
        params: {'media_id': mediaId, 'platform': 'web'},
      );

      if (data != null && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching favorite folder info: $e');
    }
    return null;
  }

  Future<List<dynamic>> getCollections(int mid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      List<dynamic> allCollections = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final data = await Request().get(
          Api.urlFavFolderCollectedList,
          baseUrl: Api.urlBase,
          params: {'up_mid': mid, 'pn': page, 'ps': 20, 'platform': 'web'},
        );

        if (data != null && data['code'] == 0) {
          final list = data['data']['list'] ?? [];
          final count = data['data']['count'] ?? 0;

          if (list.isEmpty) {
            hasMore = false;
          } else {
            allCollections.addAll(list);
            if (allCollections.length >= count) {
              hasMore = false;
            } else {
              page++;
            }
          }
        } else {
          hasMore = false;
        }
      }
      return allCollections;
    } catch (e) {
      print('Error fetching collections: $e');
    }
    return [];
  }

  Future<List<Song>> getFavoriteResources(
    String mediaId,
    BuildContext context,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      List<Song> allSongs = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final data = await Request().get(
          Api.urlFavoriteResourceList,
          baseUrl: Api.urlBase,
          params: {
            'media_id': mediaId,
            'pn': page,
            'ps': 20,
            'platform': 'web',
          },
        );

        if (data != null && data['code'] == 0) {
          final List<dynamic> medias = data['data']['medias'] ?? [];
          final hasMoreData = data['data']['has_more'] ?? false;

          if (medias.isEmpty) {
            hasMore = false;
          } else {
            allSongs.addAll(
              medias.map((item) => _mapToSong(context, item)).toList(),
            );
            if (!hasMoreData) {
              hasMore = false;
            } else {
              page++;
            }
          }
        } else {
          hasMore = false;
        }
      }
      return allSongs;
    } catch (e) {
      print('Error fetching favorite resources: $e');
    }
    return [];
  }

  Song _mapToSong(BuildContext context, dynamic item) {
    String artist = S.of(context).common_unknown;
    if (item['owner'] != null) {
      artist = item['owner']['name'];
    } else if (item['author'] != null) {
      artist = item['author'];
    } else if (item['upper'] != null) {
      artist = item['upper']['name'];
    }

    String cover = item['pic'] ?? item['cover'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    return Song(
      title: _unescape.convert(item['title'] ?? S.of(context).common_no_title),
      artist: _unescape.convert(artist),
      coverUrl: cover,
      lyrics: S.of(context).common_no_lyrics,
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: item['cid'] ?? 0,
    );
  }
}
