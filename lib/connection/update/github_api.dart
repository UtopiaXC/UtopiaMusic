import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:utopia_music/generated/l10n.dart';

class GithubApi {
  static const String _baseUrl =
      'https://api.github.com/repos/UtopiaXC/UtopiaMusic/releases';
  final Dio _dio = Dio();

  Future<Map<String, dynamic>?> getLatestRelease(BuildContext context) async {
    try {
      final response = await _dio.get('$_baseUrl/latest');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception(
          S.of(context).connection_error_update_no_github_connection,
        );
      } else if (e.response?.statusCode == 404) {
        throw Exception(S.of(context).connection_error_update_no_release);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestPreRelease(
    BuildContext context,
  ) async {
    try {
      final response = await _dio.get(_baseUrl);
      if (response.statusCode == 200) {
        final List<dynamic> releases = response.data as List<dynamic>;
        if (releases.isNotEmpty) {
          return releases.first as Map<String, dynamic>;
        } else {
          // Empty list means no releases found
          throw Exception(S.of(context).connection_error_update_no_release);
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception(
          S.of(context).connection_error_update_no_github_connection,
        );
      } else if (e.response?.statusCode == 404) {
        throw Exception(S.of(context).connection_error_update_no_release);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
    return null;
  }
}
