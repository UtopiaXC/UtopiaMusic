import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:dio/dio.dart';

class VideoDetailApi {
  final HtmlUnescape _unescape = HtmlUnescape();

  Future<Map<String, dynamic>?> getVideoDetail(String bvid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlVideoDetail,
        baseUrl: Api.urlBase,
        params: {'bvid': bvid},
        useWbi: true,
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching video detail: $e');
    }
    return null;
  }

  Future<List<Song>> getRelatedVideos(BuildContext context, String bvid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        '/x/web-interface/archive/related',
        baseUrl: Api.urlBase,
        params: {'bvid': bvid},
      );

      if (data != null && data is Map && data['code'] == 0) {
        final List<dynamic> list = data['data'] ?? [];
        return list.map((item) => _mapToSong(context, item)).toList();
      }
    } catch (e) {
      print('Error fetching related videos: $e');
    }
    return [];
  }

  Future<List<Song>> getVideoCollection(BuildContext context, String bvid, int aid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      // First try to get collection info from video detail (ugc_season)
      // But usually we need to fetch collection list if it belongs to one.
      // The API for collection list is often /x/polymer/web-space/seasons_archives_list
      // or similar, but simpler is to check 'ugc_season' in video detail.
      // If we want to fetch the full list, we might need season_id.
      
      // For simplicity, let's assume we get the season_id from somewhere or use a different API.
      // Actually, 'ugc_season' in video detail contains 'sections' which has 'episodes'.
      
      final detail = await getVideoDetail(bvid);
      if (detail != null && detail['ugc_season'] != null) {
         final sections = detail['ugc_season']['sections'];
         if (sections is List) {
           List<Song> allSongs = [];
           for (var section in sections) {
             final episodes = section['episodes'];
             if (episodes is List) {
               allSongs.addAll(episodes.map((e) => _mapEpisodeToSong(context, e)).toList());
             }
           }
           return allSongs;
         }
      }
    } catch (e) {
      print('Error fetching video collection: $e');
    }
    return [];
  }
  
  Future<List<Map<String, dynamic>>> getVideoReplies(String bvid, {int page = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }
      
      // Need aid for reply API usually, but let's try to get aid first if not provided
      // Or just use bvid if API supports it (Reply API usually needs type=1 and oid=aid)
      // We need to fetch aid from bvid first.
      
      int aid = 0;
      final detail = await getVideoDetail(bvid);
      if (detail != null) {
        aid = detail['aid'] ?? 0;
      }
      
      if (aid == 0) return [];

      final data = await Request().get(
        '/x/v2/reply',
        baseUrl: Api.urlBase,
        params: {
          'type': 1,
          'oid': aid,
          'pn': page,
          'ps': 20,
          'sort': 1, // 1 for time, 2 for hot? usually 1 or 0. Let's use default or 1.
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        final replies = data['data']['replies'];
        if (replies is List) {
          return List<Map<String, dynamic>>.from(replies);
        }
      }
    } catch (e) {
      print('Error fetching replies: $e');
    }
    return [];
  }
  
  Future<List<Map<String, dynamic>>> getReplyReplies(int oid, int rpid, {int page = 1}) async {
     try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        '/x/v2/reply/reply',
        baseUrl: Api.urlBase,
        params: {
          'type': 1,
          'oid': oid,
          'root': rpid,
          'pn': page,
          'ps': 10,
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        final replies = data['data']['replies'];
        if (replies is List) {
          return List<Map<String, dynamic>>.from(replies);
        }
      }
    } catch (e) {
      print('Error fetching sub-replies: $e');
    }
    return [];
  }

  Future<bool> actionLike(String bvid, bool like) async {
    try {
      final data = await Request().post(
        Api.urlArchiveLike,
        baseUrl: Api.urlBase,
        data: {
          'bvid': bvid,
          'like': like ? 1 : 2, // 1: like, 2: cancel like
          'csrf': await Request().getCsrf(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      return data != null && data is Map && data['code'] == 0;
    } catch (e) {
      print('Error action like: $e');
    }
    return false;
  }

  Future<bool> actionCoin(String bvid, {int count = 1}) async {
    try {
      final data = await Request().post(
        Api.urlArchiveCoin,
        baseUrl: Api.urlBase,
        data: {
          'bvid': bvid,
          'multiply': count,
          'csrf': await Request().getCsrf(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      return data != null && data is Map && data['code'] == 0;
    } catch (e) {
      print('Error action coin: $e');
    }
    return false;
  }

  Future<bool> actionFav(int aid, int addMediaId, {List<int>? delMediaIds}) async {
    return actionFavList(aid, addMediaIds: [addMediaId], delMediaIds: delMediaIds);
  }

  Future<bool> actionFavList(int aid, {List<int>? addMediaIds, List<int>? delMediaIds}) async {
    try {
      String addIds = '';
      if (addMediaIds != null && addMediaIds.isNotEmpty) {
        addIds = addMediaIds.join(',');
      }
      
      String delIds = '';
      if (delMediaIds != null && delMediaIds.isNotEmpty) {
        delIds = delMediaIds.join(',');
      }
      
      final data = await Request().post(
        Api.urlArchiveFav,
        baseUrl: Api.urlBase,
        data: {
          'rid': aid,
          'type': 2,
          'add_media_ids': addIds,
          'del_media_ids': delIds,
          'csrf': await Request().getCsrf(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      return data != null && data is Map && data['code'] == 0;
    } catch (e) {
      print('Error action fav: $e');
    }
    return false;
  }

  Song _mapToSong(BuildContext context, dynamic item) {
    String cover = item['pic'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    
    String title = item['title'] ?? '';
    title = _unescape.convert(title);
    
    String artist = '';
    if (item['owner'] != null) {
      artist = item['owner']['name'] ?? '';
    }
    artist = _unescape.convert(artist);

    return Song(
      title: title,
      artist: artist,
      coverUrl: cover,
      lyrics: '',
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: item['cid'] ?? 0,
    );
  }
  
  Song _mapEpisodeToSong(BuildContext context, dynamic item) {
    String cover = item['arc']['pic'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    
    String title = item['title'] ?? '';
    title = _unescape.convert(title);
    
    // Author info might not be in episode directly, usually same as collection owner
    // But here we just use what we have or empty
    String artist = ''; 
    
    return Song(
      title: title,
      artist: artist, // Might need to be filled from outside
      coverUrl: cover,
      lyrics: '',
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: item['cid'] ?? 0,
    );
  }
}
