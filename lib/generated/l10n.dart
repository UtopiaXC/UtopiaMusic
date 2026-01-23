// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Utopia Music`
  String get common_title {
    return Intl.message(
      'Utopia Music',
      name: 'common_title',
      desc: '',
      args: [],
    );
  }

  /// `Confirm`
  String get common_confirm {
    return Intl.message('Confirm', name: 'common_confirm', desc: '', args: []);
  }

  /// `Confirm?`
  String get common_confirm_title {
    return Intl.message(
      'Confirm?',
      name: 'common_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get common_cancel {
    return Intl.message('Cancel', name: 'common_cancel', desc: '', args: []);
  }

  /// `No data`
  String get common_no_data {
    return Intl.message('No data', name: 'common_no_data', desc: '', args: []);
  }

  /// `Clean`
  String get common_clean {
    return Intl.message('Clean', name: 'common_clean', desc: '', args: []);
  }

  /// `Close`
  String get common_close {
    return Intl.message('Close', name: 'common_close', desc: '', args: []);
  }

  /// `Retract`
  String get common_retract {
    return Intl.message('Retract', name: 'common_retract', desc: '', args: []);
  }

  /// `Unknown`
  String get common_unknown {
    return Intl.message('Unknown', name: 'common_unknown', desc: '', args: []);
  }

  /// `No title`
  String get common_no_title {
    return Intl.message(
      'No title',
      name: 'common_no_title',
      desc: '',
      args: [],
    );
  }

  /// `No lyrics`
  String get common_no_lyrics {
    return Intl.message(
      'No lyrics',
      name: 'common_no_lyrics',
      desc: '',
      args: [],
    );
  }

  /// `Discover`
  String get pages_tag_discover {
    return Intl.message(
      'Discover',
      name: 'pages_tag_discover',
      desc: '',
      args: [],
    );
  }

  /// `Library`
  String get pages_tag_library {
    return Intl.message(
      'Library',
      name: 'pages_tag_library',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get pages_tag_settings {
    return Intl.message(
      'Settings',
      name: 'pages_tag_settings',
      desc: '',
      args: [],
    );
  }

  /// `Search...`
  String get pages_search_hint_search_input {
    return Intl.message(
      'Search...',
      name: 'pages_search_hint_search_input',
      desc: '',
      args: [],
    );
  }

  /// `Live`
  String get pages_search_tag_live {
    return Intl.message(
      'Live',
      name: 'pages_search_tag_live',
      desc: '',
      args: [],
    );
  }

  /// `Video`
  String get pages_search_tag_video {
    return Intl.message(
      'Video',
      name: 'pages_search_tag_video',
      desc: '',
      args: [],
    );
  }

  /// `Collection`
  String get pages_search_tag_collection {
    return Intl.message(
      'Collection',
      name: 'pages_search_tag_collection',
      desc: '',
      args: [],
    );
  }

  /// `User`
  String get pages_search_tag_user {
    return Intl.message(
      'User',
      name: 'pages_search_tag_user',
      desc: '',
      args: [],
    );
  }

  /// `Input keyword to search`
  String get pages_search_tag_video_hint {
    return Intl.message(
      'Input keyword to search',
      name: 'pages_search_tag_video_hint',
      desc: '',
      args: [],
    );
  }

  /// `Tap again to refresh`
  String get pages_discover_refresh_toast {
    return Intl.message(
      'Tap again to refresh',
      name: 'pages_discover_refresh_toast',
      desc: '',
      args: [],
    );
  }

  /// `Live`
  String get pages_discover_tag_live {
    return Intl.message(
      'Live',
      name: 'pages_discover_tag_live',
      desc: '',
      args: [],
    );
  }

  /// `Recommend`
  String get pages_discover_tag_recommend {
    return Intl.message(
      'Recommend',
      name: 'pages_discover_tag_recommend',
      desc: '',
      args: [],
    );
  }

  /// `Feed`
  String get pages_discover_tag_feed {
    return Intl.message(
      'Feed',
      name: 'pages_discover_tag_feed',
      desc: '',
      args: [],
    );
  }

  /// `Ranking`
  String get pages_discover_tag_ranking {
    return Intl.message(
      'Ranking',
      name: 'pages_discover_tag_ranking',
      desc: '',
      args: [],
    );
  }

  /// `Music Ranking`
  String get pages_discover_tag_ranking_category_music {
    return Intl.message(
      'Music Ranking',
      name: 'pages_discover_tag_ranking_category_music',
      desc: '',
      args: [],
    );
  }

  /// `Kichiku Ranking`
  String get pages_discover_tag_ranking_category_kichiku {
    return Intl.message(
      'Kichiku Ranking',
      name: 'pages_discover_tag_ranking_category_kichiku',
      desc: '',
      args: [],
    );
  }

  /// `Next`
  String get play_control_next {
    return Intl.message('Next', name: 'play_control_next', desc: '', args: []);
  }

  /// `Previous`
  String get play_control_previous {
    return Intl.message(
      'Previous',
      name: 'play_control_previous',
      desc: '',
      args: [],
    );
  }

  /// `Pause`
  String get play_control_pause {
    return Intl.message(
      'Pause',
      name: 'play_control_pause',
      desc: '',
      args: [],
    );
  }

  /// `Stop`
  String get play_control_stop {
    return Intl.message('Stop', name: 'play_control_stop', desc: '', args: []);
  }

  /// `Resume`
  String get play_control_resume {
    return Intl.message(
      'Resume',
      name: 'play_control_resume',
      desc: '',
      args: [],
    );
  }

  /// `Sequence`
  String get play_control_mode_sequence {
    return Intl.message(
      'Sequence',
      name: 'play_control_mode_sequence',
      desc: '',
      args: [],
    );
  }

  /// `List loop`
  String get play_control_mode_loop {
    return Intl.message(
      'List loop',
      name: 'play_control_mode_loop',
      desc: '',
      args: [],
    );
  }

  /// `Single repeat`
  String get play_control_mode_single {
    return Intl.message(
      'Single repeat',
      name: 'play_control_mode_single',
      desc: '',
      args: [],
    );
  }

  /// `Shuffle`
  String get play_control_mode_shuffle {
    return Intl.message(
      'Shuffle',
      name: 'play_control_mode_shuffle',
      desc: '',
      args: [],
    );
  }

  /// `Timer stop`
  String get play_control_mode_timer_stop {
    return Intl.message(
      'Timer stop',
      name: 'play_control_mode_timer_stop',
      desc: '',
      args: [],
    );
  }

  /// `Random continue`
  String get play_control_mode_random_continue {
    return Intl.message(
      'Random continue',
      name: 'play_control_mode_random_continue',
      desc: '',
      args: [],
    );
  }

  /// `Collection`
  String get play_control_mode_random_collection {
    return Intl.message(
      'Collection',
      name: 'play_control_mode_random_collection',
      desc: '',
      args: [],
    );
  }

  /// `Comment`
  String get play_control_mode_random_comment {
    return Intl.message(
      'Comment',
      name: 'play_control_mode_random_comment',
      desc: '',
      args: [],
    );
  }

  /// `Info`
  String get play_control_mode_random_info {
    return Intl.message(
      'Info',
      name: 'play_control_mode_random_info',
      desc: '',
      args: [],
    );
  }

  /// `Add to play list`
  String get item_options_add_to_play_list {
    return Intl.message(
      'Add to play list',
      name: 'item_options_add_to_play_list',
      desc: '',
      args: [],
    );
  }

  /// `Replace play list by recent list`
  String get dialog_option_replace_play_list_by_song_list {
    return Intl.message(
      'Replace play list by recent list',
      name: 'dialog_option_replace_play_list_by_song_list',
      desc: '',
      args: [],
    );
  }

  /// `Insert into play list and play`
  String get dialog_option_insert_after_and_play {
    return Intl.message(
      'Insert into play list and play',
      name: 'dialog_option_insert_after_and_play',
      desc: '',
      args: [],
    );
  }

  /// `Insert into play list only`
  String get dialog_option_insert_after {
    return Intl.message(
      'Insert into play list only',
      name: 'dialog_option_insert_after',
      desc: '',
      args: [],
    );
  }

  /// `Append to end`
  String get dialog_option_append_to_end {
    return Intl.message(
      'Append to end',
      name: 'dialog_option_append_to_end',
      desc: '',
      args: [],
    );
  }

  /// `Replace play list single song`
  String get dialog_option_replace_by_single_song {
    return Intl.message(
      'Replace play list single song',
      name: 'dialog_option_replace_by_single_song',
      desc: '',
      args: [],
    );
  }

  /// `Search history`
  String get weight_search_label_serach_history {
    return Intl.message(
      'Search history',
      name: 'weight_search_label_serach_history',
      desc: '',
      args: [],
    );
  }

  /// `Confirm to clean history?`
  String get weight_search_label_confirm_clean_history_message {
    return Intl.message(
      'Confirm to clean history?',
      name: 'weight_search_label_confirm_clean_history_message',
      desc: '',
      args: [],
    );
  }

  /// `Play list`
  String get weight_play_list_label_name {
    return Intl.message(
      'Play list',
      name: 'weight_play_list_label_name',
      desc: '',
      args: [],
    );
  }

  /// `Confirm to clean play list?`
  String get weight_play_list_label_confirm_clean_message {
    return Intl.message(
      'Confirm to clean play list?',
      name: 'weight_play_list_label_confirm_clean_message',
      desc: '',
      args: [],
    );
  }

  /// `Clean play list`
  String get weight_search_label_confirm_clean_history_title {
    return Intl.message(
      'Clean play list',
      name: 'weight_search_label_confirm_clean_history_title',
      desc: '',
      args: [],
    );
  }

  /// `Switch play mode`
  String get weight_play_control_label_switch_paly_mode {
    return Intl.message(
      'Switch play mode',
      name: 'weight_play_control_label_switch_paly_mode',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
