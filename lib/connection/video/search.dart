import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SEARCH_API";

class SearchApi {
  final DatabaseService _dbService = DatabaseService();
  final HtmlUnescape _unescape = HtmlUnescape();

  Future<List<Song>> searchVideos(
    BuildContext context,
    String keyword, {
    int page = 1,
    int retryCount = 0,
  }) async {
    final params = {'search_type': 'video', 'keyword': keyword, 'page': page};

    try {
      final data = await Request().get(
        Api.urlSearch,
        baseUrl: Api.urlBase,
        params: params,
        useWbi: true,
      );
      final prefs = await SharedPreferences.getInstance();
      final maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;

      if (data != null && data is Map && data['code'] == 0) {
        if (data['data'] == null) {
          if (retryCount < maxRetries) {
            Log.d(_tag, 'Search response data is null, retrying... ($retryCount)');
            await Future.delayed(const Duration(milliseconds: 500));
            return searchVideos(
              context,
              keyword,
              page: page,
              retryCount: retryCount + 1,
            );
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
          Log.d(
            _tag,
            'Search failed (code: ${data is Map ? data['code'] : 'invalid'}), retrying... ($retryCount)',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          return searchVideos(
            context,
            keyword,
            page: page,
            retryCount: retryCount + 1,
          );
        }

        Log.w(
          _tag,
          'Failed to search videos: ${data is Map ? data['message'] : 'Unknown error'} (${data is Map ? data['code'] : 'Unknown code'})',
        );
        return [];
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;

      if (retryCount < maxRetries) {
        Log.d(_tag, 'Error searching videos: $e, retrying... ($retryCount)');
        await Future.delayed(const Duration(milliseconds: 500));
        return searchVideos(
          context,
          keyword,
          page: page,
          retryCount: retryCount + 1,
        );
      }
      Log.w(_tag, 'Error searching videos: $e');
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String keyword) async {
    if (keyword.isEmpty) return [];

    final params = {'term': keyword, 'main_ver': 'v1', 'highlight': ''};

    try {
      var data = await Request().get(
        Api.urlSearchSuggest,
        baseUrl: Api.urlSearchBase,
        params: params,
      );

      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          Log.w(_tag, 'JSON Decode failed: $e');
          return [];
        }
      }

      if (data != null && data is Map) {
        if (data['result'] != null) {
          final resultNode = data['result'];
          if (resultNode is Map) {
            if (resultNode['tag'] != null && resultNode['tag'] is List) {
              final List tags = resultNode['tag'];
              return tags
                  .map<String>((item) {
                    if (item is Map) {
                      return item['value']?.toString() ??
                          item['term']?.toString() ??
                          '';
                    }
                    return '';
                  })
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          } else if (resultNode is List) {
            return resultNode
                .map<String>((item) {
                  if (item is Map) {
                    return item['value']?.toString() ?? '';
                  }
                  return '';
                })
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }

      return [];
    } catch (e) {
      Log.w(_tag, 'Error fetching search suggestions: $e');
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
        baseUrl: Api.urlBase,
        params: {'bvid': bvid},
      );
      if (detailData != null && detailData is Map && detailData['code'] == 0) {
        int cid = detailData['data']['cid'];
        if (cid != 0) {
          _dbService.updateCid(bvid, cid);
        }
        return detailData['data']['cid'] ?? 0;
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching video detail for cid: $e');
    }
    return 0;
  }
}
