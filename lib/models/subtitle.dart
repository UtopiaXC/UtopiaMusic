import 'package:flutter/cupertino.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/generated/l10n.dart';

class SubtitleItem {
  final double from;
  final double to;
  final String content;

  SubtitleItem({required this.from, required this.to, required this.content});
}

enum SubtitleType { manual, ai, aiConclusion }

class SubtitleTrack {
  final String id;
  final String displayName;
  final String languageCode;
  final String lanDoc;
  final SubtitleType type;
  final String subtitleUrl;
  List<SubtitleItem>? cachedItems;

  SubtitleTrack({
    required this.id,
    required this.displayName,
    required this.languageCode,
    required this.lanDoc,
    required this.type,
    required this.subtitleUrl,
    this.cachedItems,
  });

  String get shortName {
    String prefix = type == SubtitleType.ai ? '[AI] ' : '';
    return '$prefix$lanDoc';
  }

  String get typeLabel {
    final context = navigatorKey.currentContext;
    if (context == null) {
      switch (type) {
        case SubtitleType.manual:
          return '人工';
        case SubtitleType.ai:
          return 'AI';
        case SubtitleType.aiConclusion:
          return 'AI总结';
      }
    } else {
      switch (type) {
        case SubtitleType.manual:
          return S.of(context).subtitle_type_manual;
        case SubtitleType.ai:
          return S.of(context).subtitle_type_ai;
        case SubtitleType.aiConclusion:
          return S.of(context).subtitle_type_ai_summary;
      }
    }
  }
}

class SubtitleResult {
  final List<SubtitleTrack> tracks;
  int selectedIndex;
  final bool hasAiConclusion;
  final List<SubtitleItem>? aiConclusionItems;

  SubtitleResult({
    required this.tracks,
    this.selectedIndex = 0,
    this.hasAiConclusion = false,
    this.aiConclusionItems,
  });

  SubtitleTrack? get selectedTrack =>
      tracks.isNotEmpty && selectedIndex < tracks.length
      ? tracks[selectedIndex]
      : null;

  bool get hasSubtitles =>
      tracks.isNotEmpty || (hasAiConclusion && aiConclusionItems != null);

  List<SubtitleItem>? get currentItems {
    if (tracks.isEmpty) {
      return aiConclusionItems;
    }
    return selectedTrack?.cachedItems;
  }
}
