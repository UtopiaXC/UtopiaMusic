import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:xml/xml.dart';
import 'package:utopia_music/models/danmaku.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/connection/utils/api.dart';

final String _tag = "DANMUKU_API";

class DanmakuApi {
  final Dio _dio = Dio();

  Future<List<DanmakuItem>> getDanmaku(int cid) async {
    if (cid == 0) {
      Log.w(_tag, "getDanmaku failed, cid is illegal: $cid");
      return [];
    }
    final String url = '${Api.urlCommentBase}/$cid.xml';
    Log.d(_tag, "Start requesting, url: $url");
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Referer': '${Api.urlBase}${Api.urlDanmuku}$cid',
            'User-Agent': HttpConstants.userAgent,
            'Accept-Encoding': HttpConstants.acceptEncodingIdentity,
          },
          validateStatus: (status) => true,
        ),
      );
      Log.d(_tag, "Response Status: ${response.statusCode}");
      if (response.statusCode != 200) {
        Log.w(_tag, "Fail to get danmuku, status: ${response.statusCode}");
        return [];
      }

      final List<int> bytes = response.data;
      Log.v(_tag, "Received bytes length: ${bytes.length}");

      if (bytes.isEmpty) return [];
      String? xmlString;
      String decodeMethod = "Unknown";
      if (xmlString == null) {
        try {
          final decompressed = ZLibDecoder(raw: true).convert(bytes);
          xmlString = utf8.decode(decompressed);
          decodeMethod = "Raw Deflate";
        } catch (e) {
          Log.w(_tag, "Raw Deflate failed, error: $e");
        }
      }

      if (xmlString == null) {
        try {
          final decompressed = zlib.decode(bytes);
          xmlString = utf8.decode(decompressed);
          decodeMethod = "Standard Zlib";
        } catch (e) {
          Log.w(_tag, "Zlib failed, error: $e");
        }
      }

      if (xmlString == null) {
        try {
          xmlString = utf8.decode(bytes);
          decodeMethod = "Plain Text";
        } catch (e) {
          Log.w(_tag, "UTF8 decode failed, error: $e");
        }
      }
      Log.d(_tag, "Decode method used: $decodeMethod");

      if (xmlString != null) {
        final preview = xmlString.length > 100
            ? xmlString.substring(0, 100)
            : xmlString;
        Log.v(_tag, "Content Preview: ${preview.replaceAll("\n", " ")}");
        if (xmlString.trim().startsWith("<?xml") ||
            xmlString.contains("<d p=")) {
          return _parseDanmakuXml(xmlString);
        } else {
          Log.e(
            _tag,
            "Content is not XML! It is likely an HTML error page or JSON.",
          );
          return [];
        }
      }
    } catch (e) {
      Log.e(_tag, "Fatal Error", e);
    }
    return [];
  }

  List<DanmakuItem> _parseDanmakuXml(String xmlString) {
    Log.v(_tag, "_parseDanmakuXml");
    final List<DanmakuItem> danmakus = [];
    try {
      final cleanXmlString = xmlString.replaceAll(
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'),
        '',
      );
      final document = XmlDocument.parse(cleanXmlString);
      final dElements = document.findAllElements('d');
      Log.v(_tag, "Found ${dElements.length} danmaku elements.");
      for (var element in dElements) {
        final p = element.getAttribute('p');
        if (p != null) {
          final parts = p.split(',');
          if (parts.length >= 4) {
            final time = double.tryParse(parts[0]) ?? 0.0;
            final content = element.innerText;
            final color = int.tryParse(parts[3]) ?? 0xFFFFFF;
            if (content.isNotEmpty) {
              danmakus.add(
                DanmakuItem(time: time, content: content, color: color),
              );
            }
          }
        }
      }
      danmakus.sort((a, b) => a.time.compareTo(b.time));
      Log.d(_tag, "Successfully parsed ${danmakus.length} items.");
    } catch (e) {
      Log.e(_tag, "XML Parse Error: $e");
    }
    return danmakus;
  }
}
