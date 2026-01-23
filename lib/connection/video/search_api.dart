import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class SearchApi {
  final HtmlUnescape _unescape = HtmlUnescape();

  Future<List<Song>> searchVideos(BuildContext context, String keyword, {int page = 1, int retryCount = 0}) async {
    final params = {
      'search_type': 'video',
      'keyword': keyword,
      'page': page,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlSearch,
        params: params,
        useWbi: true,
      );
      
      final maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;

      if (data != null && data is Map && data['code'] == 0) {
        if (data['data'] == null) {
           if (retryCount < maxRetries) {
             print('Search response data is null, retrying... ($retryCount)');
             await Future.delayed(const Duration(milliseconds: 500));
             return searchVideos(context, keyword, page: page, retryCount: retryCount + 1);
           }
           return [];
        }

        final result = data['data']['result'];
        if (result is List) {
          return result
              .map((item) => _mapToSong(context, item))
              .whereType<Song>()
              .toList();
        } else {
          return [];
        }
      } else {
        if (retryCount < maxRetries) {
           print('Search failed (code: ${data is Map ? data['code'] : 'invalid'}), retrying... ($retryCount)');
           await Future.delayed(const Duration(milliseconds: 500));
           return searchVideos(context, keyword, page: page, retryCount: retryCount + 1);
        }

        print(
          'Failed to search videos: ${data is Map ? data['message'] : 'Unknown error'} (${data is Map ? data['code'] : 'Unknown code'})',
        );
        return [];
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;
      
      if (retryCount < maxRetries) {
        print('Error searching videos: $e, retrying... ($retryCount)');
        await Future.delayed(const Duration(milliseconds: 500));
        return searchVideos(context, keyword, page: page, retryCount: retryCount + 1);
      }
      print('Error searching videos: $e');
      return [];
    }
  }

  Song? _mapToSong(BuildContext context, dynamic item) {
    if (item == null || item is! Map) return null;

    String bvid = item['bvid'] ?? '';
    if (bvid.isEmpty) return null;

    final artist = item['author'] ?? S.of(context).common_no_title;
    String cover = item['pic'] ?? '';
    if (cover.startsWith('//')) {
      cover = 'https:$cover';
    } else if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    int cid = 0;
    String title = item['title'] ?? S.of(context).common_no_title;
    title = title.replaceAll(RegExp(r'<[^>]*>'), '');
    title = _unescape.convert(title);
    String artistName = artist;
    artistName = artistName.replaceAll(RegExp(r'<[^>]*>'), '');
    artistName = _unescape.convert(artistName);

    return Song(
      title: title,
      artist: artistName,
      coverUrl: cover,
      lyrics: S.of(context).common_no_lyrics,
      colorValue: 0xFF2196F3,
      bvid: bvid,
      cid: cid,
    );
  }

  Future<int> fetchCid(String bvid) async {
    if (bvid.isEmpty) return 0;
    try {
      final detailData = await Request().get(
        Api.urlVideoDetail,
        params: {'bvid': bvid},
      );
      if (detailData != null && detailData is Map && detailData['code'] == 0) {
        return detailData['data']['cid'] ?? 0;
      }
    } catch (e) {
      print('Error fetching video detail for cid: $e');
    }
    return 0;
  }
}
