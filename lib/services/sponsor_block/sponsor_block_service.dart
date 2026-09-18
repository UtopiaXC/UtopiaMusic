import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:utopia_music/models/sponsor_block/segment_item_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/user_info.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SPONSOR_BLOCK_SERVICE";

class SponsorBlockService {
  static final SponsorBlockService _instance = SponsorBlockService._internal();
  factory SponsorBlockService() => _instance;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'origin': 'UtopiaMusic',
        'x-ext-version': '0.2.2',
      },
      validateStatus: (status) => true,
    ),
  );

  SponsorBlockService._internal();

  static const String defaultServer = 'https://www.bsbsb.top';

  String _api(String server, String path) {
    String trimmed = server.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return '$trimmed/api/$path';
  }

  Future<List<SegmentItemModel>?> getSkipSegments({
    required String server,
    required String bvid,
    required int cid,
  }) async {
    try {
      final url = _api(server, 'skipSegments');
      final Map<String, dynamic> params = {'videoID': bvid};
      if (cid > 0) {
        params['cid'] = cid;
      }
      final res = await _dio.get(
        url,
        queryParameters: params,
      );

      if (res.statusCode == 200) {
        if (res.data is List) {
          final list = res.data as List;
          return list
              .map((i) => SegmentItemModel.fromJson(i as Map<String, dynamic>))
              .toList();
        }
      } else if (res.statusCode == 404) {
        // No segments found
        return [];
      } else {
        Log.w(_tag, 'getSkipSegments error: ${res.statusCode} ${res.data}');
      }
    } catch (e) {
      Log.e(_tag, 'getSkipSegments request failed', e);
    }
    return null;
  }

  Future<bool> uptimeStatus({required String server}) async {
    try {
      final url = _api(server, 'status/uptime');
      final res = await _dio.get(url);
      if (res.statusCode == 200) {
        if (res.data is num) return true;
        if (res.data is String && num.tryParse(res.data) != null) return true;
        return true;
      }
    } catch (e) {
      Log.w(_tag, 'uptimeStatus failed: $e');
    }
    return false;
  }

  Future<UserInfo?> getUserInfo({
    required String server,
    required String userId,
    List<String> values = const ['viewCount', 'minutesSaved', 'segmentCount'],
  }) async {
    try {
      final url = _api(server, 'userInfo');
      final res = await _dio.get(
        url,
        queryParameters: {
          'userID': userId,
          'values': jsonEncode(values),
        },
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return UserInfo.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (e) {
      Log.e(_tag, 'getUserInfo failed', e);
    }
    return null;
  }

  Future<bool> voteOnSponsorTime({
    required String server,
    required String uuid,
    required String userId,
    int? type,
    SegmentType? category,
  }) async {
    try {
      final url = _api(server, 'voteOnSponsorTime');
      final query = <String, dynamic>{
        'UUID': uuid,
        'userID': userId,
      };
      if (type != null) query['type'] = type;
      if (category != null) query['category'] = category.name;

      final res = await _dio.post(
        url,
        queryParameters: query,
      );
      return res.statusCode == 200;
    } catch (e) {
      Log.e(_tag, 'voteOnSponsorTime failed', e);
      return false;
    }
  }

  Future<bool> viewedVideoSponsorTime({
    required String server,
    required String uuid,
  }) async {
    try {
      final url = _api(server, 'viewedVideoSponsorTime');
      final res = await _dio.post(
        url,
        data: {'UUID': uuid},
      );
      return res.statusCode == 200;
    } catch (e) {
      Log.w(_tag, 'viewedVideoSponsorTime failed: $e');
      return false;
    }
  }
}
