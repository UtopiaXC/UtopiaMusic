import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'package:utopia_music/models/danmaku.dart';

class DanmakuApi {
  final Dio _dio = Dio();
  Future<List<DanmakuItem>> getDanmaku(int cid) async {
    if (cid == 0) {
      print('[DanmakuDebug] CID is 0, skipping.');
      return [];
    }
    final String url = 'https://comment.bilibili.com/$cid.xml';
    print('[DanmakuDebug] Start requesting: $url');
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Referer': 'https://www.bilibili.com/video/av$cid',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept-Encoding': 'identity',
          },
          validateStatus: (status) => true,
        ),
      );

      print('[DanmakuDebug] Response Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('[DanmakuDebug] Failed. Server message: ${response.statusMessage}');
        return [];
      }

      final List<int> bytes = response.data;
      print('[DanmakuDebug] Received bytes length: ${bytes.length}');

      if (bytes.isEmpty) return [];
      String? xmlString;
      String decodeMethod = "Unknown";
      if (xmlString == null) {
        try {
          final decompressed = ZLibDecoder(raw: true).convert(bytes);
          xmlString = utf8.decode(decompressed);
          decodeMethod = "Raw Deflate";
        } catch (e) {
          print('[DanmakuDebug] Raw Deflate failed');
        }
      }

      if (xmlString == null) {
        try {
          final decompressed = zlib.decode(bytes);
          xmlString = utf8.decode(decompressed);
          decodeMethod = "Standard Zlib";
        } catch (e) {
          print('[DanmakuDebug] Zlib failed');
        }
      }

      if (xmlString == null) {
        try {
          xmlString = utf8.decode(bytes);
          decodeMethod = "Plain Text";
        } catch (e) {
          print('[DanmakuDebug] UTF8 decode failed');
        }
      }

      print('[DanmakuDebug] Decode method used: $decodeMethod');

      if (xmlString != null) {
        final preview = xmlString.length > 100 ? xmlString.substring(0, 100) : xmlString;
        print('[DanmakuDebug] Content Preview: ${preview.replaceAll("\n", " ")}');
        if (xmlString.trim().startsWith("<?xml") || xmlString.contains("<d p=")) {
          return _parseDanmakuXml(xmlString);
        } else {
          print('[DanmakuDebug] ERROR: Content is not XML! It is likely an HTML error page or JSON.');
          return [];
        }
      }

    } catch (e) {
      print('[DanmakuDebug] Fatal Error: $e');
    }
    return [];
  }

  List<DanmakuItem> _parseDanmakuXml(String xmlString) {
    print('[DanmakuDebug] Parsing XML...');
    final List<DanmakuItem> danmakus = [];
    try {
      final cleanXmlString = xmlString.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
      final document = XmlDocument.parse(cleanXmlString);
      final dElements = document.findAllElements('d');
      print('[DanmakuDebug] Found ${dElements.length} danmaku elements.');
      for (var element in dElements) {
        final p = element.getAttribute('p');
        if (p != null) {
          final parts = p.split(',');
          if (parts.length >= 4) {
            final time = double.tryParse(parts[0]) ?? 0.0;
            final content = element.innerText;
            final color = int.tryParse(parts[3]) ?? 0xFFFFFF;
            if (content.isNotEmpty) {
              danmakus.add(DanmakuItem(
                time: time,
                content: content,
                color: color,
              ));
            }
          }
        }
      }
      danmakus.sort((a, b) => a.time.compareTo(b.time));
      print('[DanmakuDebug] Successfully parsed ${danmakus.length} items.');

    } catch (e) {
      print('[DanmakuDebug] XML Parse Error: $e');
    }
    return danmakus;
  }
}