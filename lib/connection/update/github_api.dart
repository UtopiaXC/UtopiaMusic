import 'package:dio/dio.dart';

class GithubApi {
  static const String _baseUrl = 'https://api.github.com/repos/UtopiaXC/UtopiaMusic/releases';
  final Dio _dio = Dio();

  Future<Map<String, dynamic>?> getLatestRelease() async {
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
        throw Exception('当前设备无法连接到GitHub，请检查您的网络环境');
      } else if (e.response?.statusCode == 404) {
        throw Exception('当前仓库没有发布版本');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestPreRelease() async {
    try {
      final response = await _dio.get(_baseUrl);
      if (response.statusCode == 200) {
        final List<dynamic> releases = response.data as List<dynamic>;
        if (releases.isNotEmpty) {
          return releases.first as Map<String, dynamic>;
        } else {
           // Empty list means no releases found
           throw Exception('当前仓库没有发布版本');
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception('当前设备无法连接到GitHub，请检查您的网络环境');
      } else if (e.response?.statusCode == 404) {
        throw Exception('当前仓库没有发布版本');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
    return null;
  }
}
