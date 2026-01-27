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

  /// `UtopiaXC`
  String get common_author {
    return Intl.message('UtopiaXC', name: 'common_author', desc: '', args: []);
  }

  /// `Confirm`
  String get common_confirm {
    return Intl.message('Confirm', name: 'common_confirm', desc: '', args: []);
  }

  /// ``
  String get common_confirm_title {
    return Intl.message('', name: 'common_confirm_title', desc: '', args: []);
  }

  /// `Cancel`
  String get common_cancel {
    return Intl.message('Cancel', name: 'common_cancel', desc: '', args: []);
  }

  /// `No Data`
  String get common_no_data {
    return Intl.message('No Data', name: 'common_no_data', desc: '', args: []);
  }

  /// `Clear`
  String get common_clean {
    return Intl.message('Clear', name: 'common_clean', desc: '', args: []);
  }

  /// `Close`
  String get common_close {
    return Intl.message('Close', name: 'common_close', desc: '', args: []);
  }

  /// `Disable`
  String get common_disable {
    return Intl.message('Disable', name: 'common_disable', desc: '', args: []);
  }

  /// `Collapse`
  String get common_retract {
    return Intl.message('Collapse', name: 'common_retract', desc: '', args: []);
  }

  /// `Unknown`
  String get common_unknown {
    return Intl.message('Unknown', name: 'common_unknown', desc: '', args: []);
  }

  /// `Create`
  String get common_create {
    return Intl.message('Create', name: 'common_create', desc: '', args: []);
  }

  /// `No Title`
  String get common_no_title {
    return Intl.message(
      'No Title',
      name: 'common_no_title',
      desc: '',
      args: [],
    );
  }

  /// `Lyrics`
  String get common_lyrics {
    return Intl.message('Lyrics', name: 'common_lyrics', desc: '', args: []);
  }

  /// `AI/Subtitle`
  String get common_ai_subtitle {
    return Intl.message(
      'AI/Subtitle',
      name: 'common_ai_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Quality`
  String get common_audio_quality {
    return Intl.message(
      'Quality',
      name: 'common_audio_quality',
      desc: '',
      args: [],
    );
  }

  /// `Speed`
  String get common_audio_speed {
    return Intl.message(
      'Speed',
      name: 'common_audio_speed',
      desc: '',
      args: [],
    );
  }

  /// `Detail`
  String get common_detail {
    return Intl.message('Detail', name: 'common_detail', desc: '', args: []);
  }

  /// `No Lyrics`
  String get common_no_lyrics {
    return Intl.message(
      'No Lyrics',
      name: 'common_no_lyrics',
      desc: '',
      args: [],
    );
  }

  /// `Download`
  String get common_download {
    return Intl.message(
      'Download',
      name: 'common_download',
      desc: '',
      args: [],
    );
  }

  /// `Danmuku`
  String get common_danmuku {
    return Intl.message('Danmuku', name: 'common_danmuku', desc: '', args: []);
  }

  /// `Time`
  String get common_time {
    return Intl.message('Time', name: 'common_time', desc: '', args: []);
  }

  /// `Play`
  String get common_play {
    return Intl.message('Play', name: 'common_play', desc: '', args: []);
  }

  /// `Play All`
  String get common_play_all {
    return Intl.message(
      'Play All',
      name: 'common_play_all',
      desc: '',
      args: [],
    );
  }

  /// `Intro`
  String get common_intro {
    return Intl.message('Intro', name: 'common_intro', desc: '', args: []);
  }

  /// `Public`
  String get common_public {
    return Intl.message('Public', name: 'common_public', desc: '', args: []);
  }

  /// `Private`
  String get common_private {
    return Intl.message('Private', name: 'common_private', desc: '', args: []);
  }

  /// `None`
  String get common_none {
    return Intl.message('None', name: 'common_none', desc: '', args: []);
  }

  /// `Limit`
  String get common_limitation {
    return Intl.message('Limit', name: 'common_limitation', desc: '', args: []);
  }

  /// `Please Input`
  String get common_please_input {
    return Intl.message(
      'Please Input',
      name: 'common_please_input',
      desc: '',
      args: [],
    );
  }

  /// `Integer`
  String get common_int {
    return Intl.message('Integer', name: 'common_int', desc: '', args: []);
  }

  /// `Favorites`
  String get common_favourite_folder {
    return Intl.message(
      'Favorites',
      name: 'common_favourite_folder',
      desc: '',
      args: [],
    );
  }

  /// `Local Playlist`
  String get common_local_song_list {
    return Intl.message(
      'Local Playlist',
      name: 'common_local_song_list',
      desc: '',
      args: [],
    );
  }

  /// `Replace`
  String get common_replace {
    return Intl.message('Replace', name: 'common_replace', desc: '', args: []);
  }

  /// `Tips`
  String get common_tips {
    return Intl.message('Tips', name: 'common_tips', desc: '', args: []);
  }

  /// `Alert`
  String get common_alert {
    return Intl.message('Alert', name: 'common_alert', desc: '', args: []);
  }

  /// `Collection`
  String get common_collection {
    return Intl.message(
      'Collection',
      name: 'common_collection',
      desc: '',
      args: [],
    );
  }

  /// `Parts`
  String get common_parts {
    return Intl.message('Parts', name: 'common_parts', desc: '', args: []);
  }

  /// `Success`
  String get common_succeed {
    return Intl.message('Success', name: 'common_succeed', desc: '', args: []);
  }

  /// `Load Failed`
  String get common_loaded_failed {
    return Intl.message(
      'Load Failed',
      name: 'common_loaded_failed',
      desc: '',
      args: [],
    );
  }

  /// `Collection & Parts`
  String get common_collection_and_parts {
    return Intl.message(
      'Collection & Parts',
      name: 'common_collection_and_parts',
      desc: '',
      args: [],
    );
  }

  /// `Uploaded`
  String get common_uploaded {
    return Intl.message(
      'Uploaded',
      name: 'common_uploaded',
      desc: '',
      args: [],
    );
  }

  /// `No Uploads`
  String get common_no_uploaded {
    return Intl.message(
      'No Uploads',
      name: 'common_no_uploaded',
      desc: '',
      args: [],
    );
  }

  /// `Open in Bilibili`
  String get common_open_in_bilibili {
    return Intl.message(
      'Open in Bilibili',
      name: 'common_open_in_bilibili',
      desc: '',
      args: [],
    );
  }

  /// `Save to Bilibili Favorites`
  String get common_save_in_bilibili_favourite_folder {
    return Intl.message(
      'Save to Bilibili Favorites',
      name: 'common_save_in_bilibili_favourite_folder',
      desc: '',
      args: [],
    );
  }

  /// `Recommend`
  String get common_recommend {
    return Intl.message(
      'Recommend',
      name: 'common_recommend',
      desc: '',
      args: [],
    );
  }

  /// `Comment`
  String get common_comment {
    return Intl.message('Comment', name: 'common_comment', desc: '', args: []);
  }

  /// `No Comments`
  String get common_no_comment {
    return Intl.message(
      'No Comments',
      name: 'common_no_comment',
      desc: '',
      args: [],
    );
  }

  /// `Replace Playlist`
  String get common_replace_playlist {
    return Intl.message(
      'Replace Playlist',
      name: 'common_replace_playlist',
      desc: '',
      args: [],
    );
  }

  /// `No More Data`
  String get common_at_bottom {
    return Intl.message(
      'No More Data',
      name: 'common_at_bottom',
      desc: '',
      args: [],
    );
  }

  /// `Songs`
  String get common_count_of_songs {
    return Intl.message(
      'Songs',
      name: 'common_count_of_songs',
      desc: '',
      args: [],
    );
  }

  /// `Failed`
  String get common_failed {
    return Intl.message('Failed', name: 'common_failed', desc: '', args: []);
  }

  /// `Network Error`
  String get common_network_error {
    return Intl.message(
      'Network Error',
      name: 'common_network_error',
      desc: '',
      args: [],
    );
  }

  /// `Favorite`
  String get common_favourite {
    return Intl.message(
      'Favorite',
      name: 'common_favourite',
      desc: '',
      args: [],
    );
  }

  /// `Done`
  String get common_done {
    return Intl.message('Done', name: 'common_done', desc: '', args: []);
  }

  /// `Refresh`
  String get common_refresh {
    return Intl.message('Refresh', name: 'common_refresh', desc: '', args: []);
  }

  /// `Follow`
  String get common_subscribe {
    return Intl.message('Follow', name: 'common_subscribe', desc: '', args: []);
  }

  /// `Unfollow`
  String get common_unsubscribe {
    return Intl.message(
      'Unfollow',
      name: 'common_unsubscribe',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to`
  String get common_confirm_to {
    return Intl.message(
      'Are you sure to',
      name: 'common_confirm_to',
      desc: '',
      args: [],
    );
  }

  /// `?`
  String get common_confirm_to_end {
    return Intl.message('?', name: 'common_confirm_to_end', desc: '', args: []);
  }

  /// `GitHub`
  String get common_github {
    return Intl.message('GitHub', name: 'common_github', desc: '', args: []);
  }

  /// `New Title`
  String get common_new_title {
    return Intl.message(
      'New Title',
      name: 'common_new_title',
      desc: '',
      args: [],
    );
  }

  /// `Please input title`
  String get common_new_title_input {
    return Intl.message(
      'Please input title',
      name: 'common_new_title_input',
      desc: '',
      args: [],
    );
  }

  /// `Downloaded`
  String get common_downloaded {
    return Intl.message(
      'Downloaded',
      name: 'common_downloaded',
      desc: '',
      args: [],
    );
  }

  /// `More`
  String get common_more {
    return Intl.message('More', name: 'common_more', desc: '', args: []);
  }

  /// `Custom`
  String get common_custom {
    return Intl.message('Custom', name: 'common_custom', desc: '', args: []);
  }

  /// `Under Development`
  String get common_under_development {
    return Intl.message(
      'Under Development',
      name: 'common_under_development',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get common_retry {
    return Intl.message('Retry', name: 'common_retry', desc: '', args: []);
  }

  /// `History`
  String get common_history {
    return Intl.message('History', name: 'common_history', desc: '', args: []);
  }

  /// `K`
  String get number_thousand {
    return Intl.message('K', name: 'number_thousand', desc: '', args: []);
  }

  /// `10K`
  String get number_ten_thousand {
    return Intl.message('10K', name: 'number_ten_thousand', desc: '', args: []);
  }

  /// `M`
  String get number_million {
    return Intl.message('M', name: 'number_million', desc: '', args: []);
  }

  /// `10M`
  String get number_ten_million {
    return Intl.message('10M', name: 'number_ten_million', desc: '', args: []);
  }

  /// `100M`
  String get number_hundred_million {
    return Intl.message(
      '100M',
      name: 'number_hundred_million',
      desc: '',
      args: [],
    );
  }

  /// `sec`
  String get time_second {
    return Intl.message('sec', name: 'time_second', desc: '', args: []);
  }

  /// `min`
  String get time_minute {
    return Intl.message('min', name: 'time_minute', desc: '', args: []);
  }

  /// `hr`
  String get time_hour {
    return Intl.message('hr', name: 'time_hour', desc: '', args: []);
  }

  /// `day`
  String get time_day {
    return Intl.message('day', name: 'time_day', desc: '', args: []);
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

  /// `Input keywords to search`
  String get pages_search_tag_video_hint {
    return Intl.message(
      'Input keywords to search',
      name: 'pages_search_tag_video_hint',
      desc: '',
      args: [],
    );
  }

  /// `No result, possibly due to network issues or API restrictions. Please retry.\nIf not logged in, try logging in and retrying.`
  String get pages_search_no_result {
    return Intl.message(
      'No result, possibly due to network issues or API restrictions. Please retry.\nIf not logged in, try logging in and retrying.',
      name: 'pages_search_no_result',
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

  /// `Unlock`
  String get pages_lock_screen_unlock {
    return Intl.message(
      'Unlock',
      name: 'pages_lock_screen_unlock',
      desc: '',
      args: [],
    );
  }

  /// `App Locked`
  String get pages_lock_screen_locked {
    return Intl.message(
      'App Locked',
      name: 'pages_lock_screen_locked',
      desc: '',
      args: [],
    );
  }

  /// `Appearance`
  String get pages_settings_tag_appearance {
    return Intl.message(
      'Appearance',
      name: 'pages_settings_tag_appearance',
      desc: '',
      args: [],
    );
  }

  /// `Global`
  String get pages_settings_appearance_global {
    return Intl.message(
      'Global',
      name: 'pages_settings_appearance_global',
      desc: '',
      args: [],
    );
  }

  /// `Pages`
  String get pages_settings_appearance_pages {
    return Intl.message(
      'Pages',
      name: 'pages_settings_appearance_pages',
      desc: '',
      args: [],
    );
  }

  /// `Player`
  String get pages_settings_appearance_player {
    return Intl.message(
      'Player',
      name: 'pages_settings_appearance_player',
      desc: '',
      args: [],
    );
  }

  /// `Dark Mode`
  String get pages_settings_appearance_dark_mode {
    return Intl.message(
      'Dark Mode',
      name: 'pages_settings_appearance_dark_mode',
      desc: '',
      args: [],
    );
  }

  /// `Always Dark`
  String get pages_settings_appearance_dark_mode_dark {
    return Intl.message(
      'Always Dark',
      name: 'pages_settings_appearance_dark_mode_dark',
      desc: '',
      args: [],
    );
  }

  /// `Always Light`
  String get pages_settings_appearance_dark_mode_light {
    return Intl.message(
      'Always Light',
      name: 'pages_settings_appearance_dark_mode_light',
      desc: '',
      args: [],
    );
  }

  /// `Follow System`
  String get pages_settings_appearance_dark_mode_system {
    return Intl.message(
      'Follow System',
      name: 'pages_settings_appearance_dark_mode_system',
      desc: '',
      args: [],
    );
  }

  /// `Theme Color`
  String get pages_settings_appearance_theme_color {
    return Intl.message(
      'Theme Color',
      name: 'pages_settings_appearance_theme_color',
      desc: '',
      args: [],
    );
  }

  /// `Player Background`
  String get pages_settings_appearance_player_background {
    return Intl.message(
      'Player Background',
      name: 'pages_settings_appearance_player_background',
      desc: '',
      args: [],
    );
  }

  /// `Choose player background style`
  String get pages_settings_appearance_player_background_description {
    return Intl.message(
      'Choose player background style',
      name: 'pages_settings_appearance_player_background_description',
      desc: '',
      args: [],
    );
  }

  /// `None`
  String get pages_settings_appearance_player_background_none {
    return Intl.message(
      'None',
      name: 'pages_settings_appearance_player_background_none',
      desc: '',
      args: [],
    );
  }

  /// `Gradient`
  String get pages_settings_appearance_player_background_gradient {
    return Intl.message(
      'Gradient',
      name: 'pages_settings_appearance_player_background_gradient',
      desc: '',
      args: [],
    );
  }

  /// `Blur`
  String get pages_settings_appearance_player_background_blur {
    return Intl.message(
      'Blur',
      name: 'pages_settings_appearance_player_background_blur',
      desc: '',
      args: [],
    );
  }

  /// `Gaussian Blur`
  String get pages_settings_appearance_player_background_gaussian_blur {
    return Intl.message(
      'Gaussian Blur',
      name: 'pages_settings_appearance_player_background_gaussian_blur',
      desc: '',
      args: [],
    );
  }

  /// `Startup Page`
  String get pages_settings_appearance_startup_page {
    return Intl.message(
      'Startup Page',
      name: 'pages_settings_appearance_startup_page',
      desc: '',
      args: [],
    );
  }

  /// `Discover`
  String get pages_settings_appearance_startup_page_discover {
    return Intl.message(
      'Discover',
      name: 'pages_settings_appearance_startup_page_discover',
      desc: '',
      args: [],
    );
  }

  /// `Discover Page Order`
  String get pages_settings_appearance_startup_page_discover_order {
    return Intl.message(
      'Discover Page Order',
      name: 'pages_settings_appearance_startup_page_discover_order',
      desc: '',
      args: [],
    );
  }

  /// `Library`
  String get pages_settings_appearance_startup_page_library {
    return Intl.message(
      'Library',
      name: 'pages_settings_appearance_startup_page_library',
      desc: '',
      args: [],
    );
  }

  /// `Library Page Order`
  String get pages_settings_appearance_startup_page_library_order {
    return Intl.message(
      'Library Page Order',
      name: 'pages_settings_appearance_startup_page_library_order',
      desc: '',
      args: [],
    );
  }

  /// `Favorites`
  String get pages_settings_appearance_startup_page_library_order_folder {
    return Intl.message(
      'Favorites',
      name: 'pages_settings_appearance_startup_page_library_order_folder',
      desc: '',
      args: [],
    );
  }

  /// `Collection`
  String get pages_settings_appearance_startup_page_library_order_collection {
    return Intl.message(
      'Collection',
      name: 'pages_settings_appearance_startup_page_library_order_collection',
      desc: '',
      args: [],
    );
  }

  /// `Local Playlist`
  String get pages_settings_appearance_startup_page_library_order_songlist {
    return Intl.message(
      'Local Playlist',
      name: 'pages_settings_appearance_startup_page_library_order_songlist',
      desc: '',
      args: [],
    );
  }

  /// `Hide Widget`
  String get pages_settings_appearance_startup_page_library_order_hide {
    return Intl.message(
      'Hide Widget',
      name: 'pages_settings_appearance_startup_page_library_order_hide',
      desc: '',
      args: [],
    );
  }

  /// `Show Widget`
  String get pages_settings_appearance_startup_page_library_order_show {
    return Intl.message(
      'Show Widget',
      name: 'pages_settings_appearance_startup_page_library_order_show',
      desc: '',
      args: [],
    );
  }

  /// `Show this widget in Library?`
  String get pages_settings_appearance_startup_page_library_order_show_ask {
    return Intl.message(
      'Show this widget in Library?',
      name: 'pages_settings_appearance_startup_page_library_order_show_ask',
      desc: '',
      args: [],
    );
  }

  /// `Hide this widget in Library?`
  String get pages_settings_appearance_startup_page_library_order_hide_ask {
    return Intl.message(
      'Hide this widget in Library?',
      name: 'pages_settings_appearance_startup_page_library_order_hide_ask',
      desc: '',
      args: [],
    );
  }

  /// `Show this widget in Discover?`
  String get pages_settings_appearance_startup_page_discover_order_show_ask {
    return Intl.message(
      'Show this widget in Discover?',
      name: 'pages_settings_appearance_startup_page_discover_order_show_ask',
      desc: '',
      args: [],
    );
  }

  /// `Hide this widget in Discover?`
  String get pages_settings_appearance_startup_page_discover_order_hide_ask {
    return Intl.message(
      'Hide this widget in Discover?',
      name: 'pages_settings_appearance_startup_page_discover_order_hide_ask',
      desc: '',
      args: [],
    );
  }

  /// `Pick Color`
  String get pages_settings_appearance_pickup_color {
    return Intl.message(
      'Pick Color',
      name: 'pages_settings_appearance_pickup_color',
      desc: '',
      args: [],
    );
  }

  /// `Search`
  String get pages_settings_tag_search {
    return Intl.message(
      'Search',
      name: 'pages_settings_tag_search',
      desc: '',
      args: [],
    );
  }

  /// `Local Search History`
  String get pages_settings_tag_search_local_history {
    return Intl.message(
      'Local Search History',
      name: 'pages_settings_tag_search_local_history',
      desc: '',
      args: [],
    );
  }

  /// `History Limit`
  String get pages_settings_tag_search_local_history_limit {
    return Intl.message(
      'History Limit',
      name: 'pages_settings_tag_search_local_history_limit',
      desc: '',
      args: [],
    );
  }

  /// `Current Limit`
  String get pages_settings_tag_search_local_history_limit_now {
    return Intl.message(
      'Current Limit',
      name: 'pages_settings_tag_search_local_history_limit_now',
      desc: '',
      args: [],
    );
  }

  /// `Search Suggest`
  String get pages_settings_tag_search_suggest {
    return Intl.message(
      'Search Suggest',
      name: 'pages_settings_tag_search_suggest',
      desc: '',
      args: [],
    );
  }

  /// `Show Search Suggest`
  String get pages_settings_tag_search_suggest_title {
    return Intl.message(
      'Show Search Suggest',
      name: 'pages_settings_tag_search_suggest_title',
      desc: '',
      args: [],
    );
  }

  /// `Show suggestions when typing`
  String get pages_settings_tag_search_suggest_hint {
    return Intl.message(
      'Show suggestions when typing',
      name: 'pages_settings_tag_search_suggest_hint',
      desc: '',
      args: [],
    );
  }

  /// `Player`
  String get pages_settings_tag_player {
    return Intl.message(
      'Player',
      name: 'pages_settings_tag_player',
      desc: '',
      args: [],
    );
  }

  /// `Codec`
  String get pages_settings_tag_player_codec {
    return Intl.message(
      'Codec',
      name: 'pages_settings_tag_player_codec',
      desc: '',
      args: [],
    );
  }

  /// `Default Online Quality`
  String get pages_settings_tag_player_codec_online_default_quality {
    return Intl.message(
      'Default Online Quality',
      name: 'pages_settings_tag_player_codec_online_default_quality',
      desc: '',
      args: [],
    );
  }

  /// `Skip Unavailable`
  String get pages_settings_tag_player_codec_clear_unavailable {
    return Intl.message(
      'Skip Unavailable',
      name: 'pages_settings_tag_player_codec_clear_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Automatically skip unavailable resources (copyright/paid) and play next`
  String get pages_settings_tag_player_codec_clear_unavailable_description {
    return Intl.message(
      'Automatically skip unavailable resources (copyright/paid) and play next',
      name: 'pages_settings_tag_player_codec_clear_unavailable_description',
      desc: '',
      args: [],
    );
  }

  /// `Control`
  String get pages_settings_tag_player_control {
    return Intl.message(
      'Control',
      name: 'pages_settings_tag_player_control',
      desc: '',
      args: [],
    );
  }

  /// `Save Progress`
  String get pages_settings_tag_player_control_save_progress {
    return Intl.message(
      'Save Progress',
      name: 'pages_settings_tag_player_control_save_progress',
      desc: '',
      args: [],
    );
  }

  /// `Restore playback progress on restart`
  String get pages_settings_tag_player_control_save_progress_description {
    return Intl.message(
      'Restore playback progress on restart',
      name: 'pages_settings_tag_player_control_save_progress_description',
      desc: '',
      args: [],
    );
  }

  /// `Auto Play`
  String get pages_settings_tag_player_control_auto_play {
    return Intl.message(
      'Auto Play',
      name: 'pages_settings_tag_player_control_auto_play',
      desc: '',
      args: [],
    );
  }

  /// `Auto play on startup if playing when exited`
  String get pages_settings_tag_player_control_auto_play_descriptionn {
    return Intl.message(
      'Auto play on startup if playing when exited',
      name: 'pages_settings_tag_player_control_auto_play_descriptionn',
      desc: '',
      args: [],
    );
  }

  /// `Auto Next`
  String get pages_settings_tag_player_auto_next {
    return Intl.message(
      'Auto Next',
      name: 'pages_settings_tag_player_auto_next',
      desc: '',
      args: [],
    );
  }

  /// `Recommend Next`
  String get pages_settings_tag_player_auto_next_suggest {
    return Intl.message(
      'Recommend Next',
      name: 'pages_settings_tag_player_auto_next_suggest',
      desc: '',
      args: [],
    );
  }

  /// `Automatically fetch recommended video and replace playlist`
  String get pages_settings_tag_player_auto_next_suggest_description {
    return Intl.message(
      'Automatically fetch recommended video and replace playlist',
      name: 'pages_settings_tag_player_auto_next_suggest_description',
      desc: '',
      args: [],
    );
  }

  /// `If enabled, switching to the next video will automatically fetch recommendations and replace the current playlist.\n\nThis conflicts with loop mode. Enabling this will disable loop mode and take over the playlist.`
  String get pages_settings_tag_player_auto_next_suggest_dialog_msg {
    return Intl.message(
      'If enabled, switching to the next video will automatically fetch recommendations and replace the current playlist.\n\nThis conflicts with loop mode. Enabling this will disable loop mode and take over the playlist.',
      name: 'pages_settings_tag_player_auto_next_suggest_dialog_msg',
      desc: '',
      args: [],
    );
  }

  /// `Comment`
  String get pages_settings_tag_player_comment {
    return Intl.message(
      'Comment',
      name: 'pages_settings_tag_player_comment',
      desc: '',
      args: [],
    );
  }

  /// `Show Comments`
  String get pages_settings_tag_player_comment_title {
    return Intl.message(
      'Show Comments',
      name: 'pages_settings_tag_player_comment_title',
      desc: '',
      args: [],
    );
  }

  /// `Show comments page in video detail`
  String get pages_settings_tag_player_comment_description {
    return Intl.message(
      'Show comments page in video detail',
      name: 'pages_settings_tag_player_comment_description',
      desc: '',
      args: [],
    );
  }

  /// `Download`
  String get pages_settings_tag_download {
    return Intl.message(
      'Download',
      name: 'pages_settings_tag_download',
      desc: '',
      args: [],
    );
  }

  /// `Clear Music Cache`
  String get pages_settings_tag_download_cache_clear_cache {
    return Intl.message(
      'Clear Music Cache',
      name: 'pages_settings_tag_download_cache_clear_cache',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to delete all cached songs and reset statistics?\nThis will require re-downloading all songs.`
  String get pages_settings_tag_download_cache_clear_cache_description {
    return Intl.message(
      'Are you sure to delete all cached songs and reset statistics?\nThis will require re-downloading all songs.',
      name: 'pages_settings_tag_download_cache_clear_cache_description',
      desc: '',
      args: [],
    );
  }

  /// `Cache Cleared`
  String get pages_settings_tag_download_cache_clear_cache_cleared {
    return Intl.message(
      'Cache Cleared',
      name: 'pages_settings_tag_download_cache_clear_cache_cleared',
      desc: '',
      args: [],
    );
  }

  /// `Clear All Downloads`
  String get pages_settings_tag_download_download_clear_downloaded {
    return Intl.message(
      'Clear All Downloads',
      name: 'pages_settings_tag_download_download_clear_downloaded',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to delete all downloaded songs? This cannot be undone.`
  String get pages_settings_tag_download_download_clear_downloaded_description {
    return Intl.message(
      'Are you sure to delete all downloaded songs? This cannot be undone.',
      name: 'pages_settings_tag_download_download_clear_downloaded_description',
      desc: '',
      args: [],
    );
  }

  /// `Downloads Cleared`
  String get pages_settings_tag_download_download_clear_downloaded_cleared {
    return Intl.message(
      'Downloads Cleared',
      name: 'pages_settings_tag_download_download_clear_downloaded_cleared',
      desc: '',
      args: [],
    );
  }

  /// `Performance & Download`
  String get pages_settings_tag_download_performance {
    return Intl.message(
      'Performance & Download',
      name: 'pages_settings_tag_download_performance',
      desc: '',
      args: [],
    );
  }

  /// `Cache`
  String get pages_settings_tag_download_performance_cache {
    return Intl.message(
      'Cache',
      name: 'pages_settings_tag_download_performance_cache',
      desc: '',
      args: [],
    );
  }

  /// `Cache Limit`
  String get pages_settings_tag_download_performance_cache_limit {
    return Intl.message(
      'Cache Limit',
      name: 'pages_settings_tag_download_performance_cache_limit',
      desc: '',
      args: [],
    );
  }

  /// `Cache reduces data usage`
  String get pages_settings_tag_download_performance_cache_limit_description {
    return Intl.message(
      'Cache reduces data usage',
      name: 'pages_settings_tag_download_performance_cache_limit_description',
      desc: '',
      args: [],
    );
  }

  /// `Used`
  String get pages_settings_tag_download_cache_used {
    return Intl.message(
      'Used',
      name: 'pages_settings_tag_download_cache_used',
      desc: '',
      args: [],
    );
  }

  /// `Default Download Quality`
  String get pages_settings_tag_download_defult_quality {
    return Intl.message(
      'Default Download Quality',
      name: 'pages_settings_tag_download_defult_quality',
      desc: '',
      args: [],
    );
  }

  /// `Clear All Downloads`
  String get pages_settings_tag_download_clear {
    return Intl.message(
      'Clear All Downloads',
      name: 'pages_settings_tag_download_clear',
      desc: '',
      args: [],
    );
  }

  /// `Network`
  String get pages_settings_tag_network {
    return Intl.message(
      'Network',
      name: 'pages_settings_tag_network',
      desc: '',
      args: [],
    );
  }

  /// `API Request`
  String get pages_settings_tag_network_interface_request {
    return Intl.message(
      'API Request',
      name: 'pages_settings_tag_network_interface_request',
      desc: '',
      args: [],
    );
  }

  /// `Retry Count`
  String get pages_settings_tag_network_interface_request_retry {
    return Intl.message(
      'Retry Count',
      name: 'pages_settings_tag_network_interface_request_retry',
      desc: '',
      args: [],
    );
  }

  /// `Retries on network error or parsing failure`
  String get pages_settings_tag_network_interface_request_retry_description {
    return Intl.message(
      'Retries on network error or parsing failure',
      name: 'pages_settings_tag_network_interface_request_retry_description',
      desc: '',
      args: [],
    );
  }

  /// `Request Delay`
  String get pages_settings_tag_network_request_delay {
    return Intl.message(
      'Request Delay',
      name: 'pages_settings_tag_network_request_delay',
      desc: '',
      args: [],
    );
  }

  /// `Reduce risk of being blocked`
  String get pages_settings_tag_network_request_delay_description {
    return Intl.message(
      'Reduce risk of being blocked',
      name: 'pages_settings_tag_network_request_delay_description',
      desc: '',
      args: [],
    );
  }

  /// `History`
  String get pages_settings_tag_network_play_history {
    return Intl.message(
      'History',
      name: 'pages_settings_tag_network_play_history',
      desc: '',
      args: [],
    );
  }

  /// `Report Play History`
  String get pages_settings_tag_network_play_history_report {
    return Intl.message(
      'Report Play History',
      name: 'pages_settings_tag_network_play_history_report',
      desc: '',
      args: [],
    );
  }

  /// `Sync play history to Bilibili`
  String get pages_settings_tag_network_play_history_report_description {
    return Intl.message(
      'Sync play history to Bilibili',
      name: 'pages_settings_tag_network_play_history_report_description',
      desc: '',
      args: [],
    );
  }

  /// `Report Delay`
  String get pages_settings_tag_network_play_history_report_delay {
    return Intl.message(
      'Report Delay',
      name: 'pages_settings_tag_network_play_history_report_delay',
      desc: '',
      args: [],
    );
  }

  /// `Report progress after specified time to avoid invalid requests`
  String get pages_settings_tag_network_play_history_report_delay_description {
    return Intl.message(
      'Report progress after specified time to avoid invalid requests',
      name: 'pages_settings_tag_network_play_history_report_delay_description',
      desc: '',
      args: [],
    );
  }

  /// `Security`
  String get pages_settings_tag_security {
    return Intl.message(
      'Security',
      name: 'pages_settings_tag_security',
      desc: '',
      args: [],
    );
  }

  /// `Lock`
  String get pages_settings_tag_security_lock {
    return Intl.message(
      'Lock',
      name: 'pages_settings_tag_security_lock',
      desc: '',
      args: [],
    );
  }

  /// `Biometrics`
  String get pages_settings_tag_security_biometrics {
    return Intl.message(
      'Biometrics',
      name: 'pages_settings_tag_security_biometrics',
      desc: '',
      args: [],
    );
  }

  /// `Not applicable on Windows`
  String get pages_settings_tag_security_biometrics_windows_inapplicable {
    return Intl.message(
      'Not applicable on Windows',
      name: 'pages_settings_tag_security_biometrics_windows_inapplicable',
      desc: '',
      args: [],
    );
  }

  /// `Blur in Multitasking`
  String get pages_settings_tag_security_hide_in_task {
    return Intl.message(
      'Blur in Multitasking',
      name: 'pages_settings_tag_security_hide_in_task',
      desc: '',
      args: [],
    );
  }

  /// `Lock Delay`
  String get pages_settings_tag_security_lock_dely {
    return Intl.message(
      'Lock Delay',
      name: 'pages_settings_tag_security_lock_dely',
      desc: '',
      args: [],
    );
  }

  /// `Every Switch`
  String get pages_settings_tag_security_lock_dely_everytime {
    return Intl.message(
      'Every Switch',
      name: 'pages_settings_tag_security_lock_dely_everytime',
      desc: '',
      args: [],
    );
  }

  /// `Input Minutes`
  String get pages_settings_tag_security_lock_dely_custom_inpit {
    return Intl.message(
      'Input Minutes',
      name: 'pages_settings_tag_security_lock_dely_custom_inpit',
      desc: '',
      args: [],
    );
  }

  /// `General`
  String get pages_settings_tag_general {
    return Intl.message(
      'General',
      name: 'pages_settings_tag_general',
      desc: '',
      args: [],
    );
  }

  /// `Global`
  String get pages_settings_tag_general_global {
    return Intl.message(
      'Global',
      name: 'pages_settings_tag_general_global',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get pages_settings_tag_general_global_language {
    return Intl.message(
      'Language',
      name: 'pages_settings_tag_general_global_language',
      desc: '',
      args: [],
    );
  }

  /// `Follow System`
  String get pages_settings_tag_general_global_language_system {
    return Intl.message(
      'Follow System',
      name: 'pages_settings_tag_general_global_language_system',
      desc: '',
      args: [],
    );
  }

  /// `Update`
  String get pages_settings_tag_general_update {
    return Intl.message(
      'Update',
      name: 'pages_settings_tag_general_update',
      desc: '',
      args: [],
    );
  }

  /// `Auto Check Update`
  String get pages_settings_tag_general_update_auto_check {
    return Intl.message(
      'Auto Check Update',
      name: 'pages_settings_tag_general_update_auto_check',
      desc: '',
      args: [],
    );
  }

  /// `Check Beta Update`
  String get pages_settings_tag_general_update_check_beta {
    return Intl.message(
      'Check Beta Update',
      name: 'pages_settings_tag_general_update_check_beta',
      desc: '',
      args: [],
    );
  }

  /// `Initialize`
  String get pages_settings_tag_general_initial {
    return Intl.message(
      'Initialize',
      name: 'pages_settings_tag_general_initial',
      desc: '',
      args: [],
    );
  }

  /// `Reset Settings`
  String get pages_settings_tag_general_initial_reset_settings {
    return Intl.message(
      'Reset Settings',
      name: 'pages_settings_tag_general_initial_reset_settings',
      desc: '',
      args: [],
    );
  }

  /// `Reset App`
  String get pages_settings_tag_general_initial_reset_app {
    return Intl.message(
      'Reset App',
      name: 'pages_settings_tag_general_initial_reset_app',
      desc: '',
      args: [],
    );
  }

  /// `Developer Options`
  String get pages_settings_tag_general_development {
    return Intl.message(
      'Developer Options',
      name: 'pages_settings_tag_general_development',
      desc: '',
      args: [],
    );
  }

  /// `Debug Mode`
  String get pages_settings_tag_general_development_debug {
    return Intl.message(
      'Debug Mode',
      name: 'pages_settings_tag_general_development_debug',
      desc: '',
      args: [],
    );
  }

  /// `Log Level`
  String get pages_settings_tag_general_development_log_level {
    return Intl.message(
      'Log Level',
      name: 'pages_settings_tag_general_development_log_level',
      desc: '',
      args: [],
    );
  }

  /// `Verbose`
  String get pages_settings_tag_general_development_log_level_verbose {
    return Intl.message(
      'Verbose',
      name: 'pages_settings_tag_general_development_log_level_verbose',
      desc: '',
      args: [],
    );
  }

  /// `Debug`
  String get pages_settings_tag_general_development_log_level_debug {
    return Intl.message(
      'Debug',
      name: 'pages_settings_tag_general_development_log_level_debug',
      desc: '',
      args: [],
    );
  }

  /// `Info`
  String get pages_settings_tag_general_development_log_level_info {
    return Intl.message(
      'Info',
      name: 'pages_settings_tag_general_development_log_level_info',
      desc: '',
      args: [],
    );
  }

  /// `Warning`
  String get pages_settings_tag_general_development_log_level_warning {
    return Intl.message(
      'Warning',
      name: 'pages_settings_tag_general_development_log_level_warning',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get pages_settings_tag_general_development_log_level_error {
    return Intl.message(
      'Error',
      name: 'pages_settings_tag_general_development_log_level_error',
      desc: '',
      args: [],
    );
  }

  /// `Export Logs`
  String get pages_settings_tag_general_development_log_export {
    return Intl.message(
      'Export Logs',
      name: 'pages_settings_tag_general_development_log_export',
      desc: '',
      args: [],
    );
  }

  /// `Enabling debug mode will output logs to the console, which may contain sensitive information. Please only enable this for testing or when exporting logs for bug reporting.`
  String get pages_settings_tag_general_development_enable_alert {
    return Intl.message(
      'Enabling debug mode will output logs to the console, which may contain sensitive information. Please only enable this for testing or when exporting logs for bug reporting.',
      name: 'pages_settings_tag_general_development_enable_alert',
      desc: '',
      args: [],
    );
  }

  /// `Debug mode enabled. Restart recommended for console output to take effect.`
  String get pages_settings_tag_general_development_enabled_toast {
    return Intl.message(
      'Debug mode enabled. Restart recommended for console output to take effect.',
      name: 'pages_settings_tag_general_development_enabled_toast',
      desc: '',
      args: [],
    );
  }

  /// `Reset settings to default?\n(Login status and local playlists will not be cleared)`
  String get pages_settings_tag_general_initial_reset_settings_alert_message {
    return Intl.message(
      'Reset settings to default?\n(Login status and local playlists will not be cleared)',
      name: 'pages_settings_tag_general_initial_reset_settings_alert_message',
      desc: '',
      args: [],
    );
  }

  /// `Completely reset the app to initial state?\nThis will clear ALL data (downloads, cache, login info, settings, etc.) and restart the app.`
  String get pages_settings_tag_general_initial_reset_app_alert_message {
    return Intl.message(
      'Completely reset the app to initial state?\nThis will clear ALL data (downloads, cache, login info, settings, etc.) and restart the app.',
      name: 'pages_settings_tag_general_initial_reset_app_alert_message',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get pages_settings_tag_about {
    return Intl.message(
      'About',
      name: 'pages_settings_tag_about',
      desc: '',
      args: [],
    );
  }

  /// `Developer`
  String get pages_settings_about_developer {
    return Intl.message(
      'Developer',
      name: 'pages_settings_about_developer',
      desc: '',
      args: [],
    );
  }

  /// `GitHub`
  String get pages_settings_about_github {
    return Intl.message(
      'GitHub',
      name: 'pages_settings_about_github',
      desc: '',
      args: [],
    );
  }

  /// `Check Update`
  String get pages_settings_about_check_update {
    return Intl.message(
      'Check Update',
      name: 'pages_settings_about_check_update',
      desc: '',
      args: [],
    );
  }

  /// `EULA`
  String get pages_settings_about_eurl {
    return Intl.message(
      'EULA',
      name: 'pages_settings_about_eurl',
      desc: '',
      args: [],
    );
  }

  /// `Q&A`
  String get pages_settings_about_qa {
    return Intl.message(
      'Q&A',
      name: 'pages_settings_about_qa',
      desc: '',
      args: [],
    );
  }

  /// `Open Source License`
  String get pages_settings_about_open_source_license {
    return Intl.message(
      'Open Source License',
      name: 'pages_settings_about_open_source_license',
      desc: '',
      args: [],
    );
  }

  /// `Agree`
  String get pages_settings_about_agree {
    return Intl.message(
      'Agree',
      name: 'pages_settings_about_agree',
      desc: '',
      args: [],
    );
  }

  /// `Disagree and Exit`
  String get pages_settings_about_disagree_and_exit {
    return Intl.message(
      'Disagree and Exit',
      name: 'pages_settings_about_disagree_and_exit',
      desc: '',
      args: [],
    );
  }

  /// `Create Local Playlist`
  String get pages_libiray_create_local_song_list {
    return Intl.message(
      'Create Local Playlist',
      name: 'pages_libiray_create_local_song_list',
      desc: '',
      args: [],
    );
  }

  /// `Create Bilibili Favorites`
  String get pages_libiray_create_online_bilibili_folder {
    return Intl.message(
      'Create Bilibili Favorites',
      name: 'pages_libiray_create_online_bilibili_folder',
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

  /// `Loop List`
  String get play_control_mode_loop {
    return Intl.message(
      'Loop List',
      name: 'play_control_mode_loop',
      desc: '',
      args: [],
    );
  }

  /// `Loop Single`
  String get play_control_mode_single {
    return Intl.message(
      'Loop Single',
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

  /// `Timer Stop`
  String get play_control_mode_timer_stop {
    return Intl.message(
      'Timer Stop',
      name: 'play_control_mode_timer_stop',
      desc: '',
      args: [],
    );
  }

  /// `Recommend Next`
  String get play_control_mode_random_continue {
    return Intl.message(
      'Recommend Next',
      name: 'play_control_mode_random_continue',
      desc: '',
      args: [],
    );
  }

  /// `Add to Playlist`
  String get item_options_add_to_play_list {
    return Intl.message(
      'Add to Playlist',
      name: 'item_options_add_to_play_list',
      desc: '',
      args: [],
    );
  }

  /// `Replace playlist with current list and play`
  String get sheet_option_replace_play_list_by_song_list {
    return Intl.message(
      'Replace playlist with current list and play',
      name: 'sheet_option_replace_play_list_by_song_list',
      desc: '',
      args: [],
    );
  }

  /// `Insert after current song and play`
  String get sheet_option_insert_after_and_play {
    return Intl.message(
      'Insert after current song and play',
      name: 'sheet_option_insert_after_and_play',
      desc: '',
      args: [],
    );
  }

  /// `Insert after current song`
  String get sheet_option_insert_after {
    return Intl.message(
      'Insert after current song',
      name: 'sheet_option_insert_after',
      desc: '',
      args: [],
    );
  }

  /// `Append to end`
  String get sheet_option_append_to_end {
    return Intl.message(
      'Append to end',
      name: 'sheet_option_append_to_end',
      desc: '',
      args: [],
    );
  }

  /// `Replace playlist with this song`
  String get sheet_option_replace_by_single_song {
    return Intl.message(
      'Replace playlist with this song',
      name: 'sheet_option_replace_by_single_song',
      desc: '',
      args: [],
    );
  }

  /// `Search History`
  String get weight_search_label_serach_history {
    return Intl.message(
      'Search History',
      name: 'weight_search_label_serach_history',
      desc: '',
      args: [],
    );
  }

  /// `Clear history?`
  String get weight_search_label_confirm_clean_history_message {
    return Intl.message(
      'Clear history?',
      name: 'weight_search_label_confirm_clean_history_message',
      desc: '',
      args: [],
    );
  }

  /// `Playlist`
  String get weight_play_list_label_name {
    return Intl.message(
      'Playlist',
      name: 'weight_play_list_label_name',
      desc: '',
      args: [],
    );
  }

  /// `Clear Playlist`
  String get weight_play_list_label_confirm_clean_playlist_title {
    return Intl.message(
      'Clear Playlist',
      name: 'weight_play_list_label_confirm_clean_playlist_title',
      desc: '',
      args: [],
    );
  }

  /// `Clear current playlist?`
  String get weight_play_list_label_confirm_clean_message {
    return Intl.message(
      'Clear current playlist?',
      name: 'weight_play_list_label_confirm_clean_message',
      desc: '',
      args: [],
    );
  }

  /// `Switch Play Mode`
  String get weight_play_control_label_switch_paly_mode {
    return Intl.message(
      'Switch Play Mode',
      name: 'weight_play_control_label_switch_paly_mode',
      desc: '',
      args: [],
    );
  }

  /// `Download this song?`
  String get weight_video_detail_download_confirm_message {
    return Intl.message(
      'Download this song?',
      name: 'weight_video_detail_download_confirm_message',
      desc: '',
      args: [],
    );
  }

  /// `Downloaded`
  String get weight_video_detail_download_downloaded {
    return Intl.message(
      'Downloaded',
      name: 'weight_video_detail_download_downloaded',
      desc: '',
      args: [],
    );
  }

  /// `Added to download queue`
  String get weight_video_detail_added_to_download_queue {
    return Intl.message(
      'Added to download queue',
      name: 'weight_video_detail_added_to_download_queue',
      desc: '',
      args: [],
    );
  }

  /// `Enable Recommend Next`
  String get weight_video_detail_enable_auto_continue_title {
    return Intl.message(
      'Enable Recommend Next',
      name: 'weight_video_detail_enable_auto_continue_title',
      desc: '',
      args: [],
    );
  }

  /// `If enabled, switching to the next video will automatically fetch recommendations and replace the current playlist.\n\nThis conflicts with loop mode. Enabling this will disable loop mode and take over the playlist.`
  String get weight_video_detail_enable_auto_continue_message {
    return Intl.message(
      'If enabled, switching to the next video will automatically fetch recommendations and replace the current playlist.\n\nThis conflicts with loop mode. Enabling this will disable loop mode and take over the playlist.',
      name: 'weight_video_detail_enable_auto_continue_message',
      desc: '',
      args: [],
    );
  }

  /// `Replace playlist with this collection?`
  String get weight_video_detail_replace_by_this_collection_title {
    return Intl.message(
      'Replace playlist with this collection?',
      name: 'weight_video_detail_replace_by_this_collection_title',
      desc: '',
      args: [],
    );
  }

  /// `\n\nNote: Recommend Next is enabled. Collection playback will be interrupted. Disable Recommend Next to play collection fully.`
  String get weight_video_detail_replace_by_this_collection_recommend_alert {
    return Intl.message(
      '\n\nNote: Recommend Next is enabled. Collection playback will be interrupted. Disable Recommend Next to play collection fully.',
      name: 'weight_video_detail_replace_by_this_collection_recommend_alert',
      desc: '',
      args: [],
    );
  }

  /// `Please login first`
  String get weight_video_detail_please_login_first {
    return Intl.message(
      'Please login first',
      name: 'weight_video_detail_please_login_first',
      desc: '',
      args: [],
    );
  }

  /// `Cannot load video detail`
  String get weight_video_detail_cannot_load_detail {
    return Intl.message(
      'Cannot load video detail',
      name: 'weight_video_detail_cannot_load_detail',
      desc: '',
      args: [],
    );
  }

  /// `More replies >`
  String get weight_video_detail_more_comments {
    return Intl.message(
      'More replies >',
      name: 'weight_video_detail_more_comments',
      desc: '',
      args: [],
    );
  }

  /// `items`
  String get weight_video_detail_contants {
    return Intl.message(
      'items',
      name: 'weight_video_detail_contants',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get weight_user_space_logout_title {
    return Intl.message(
      'Logout',
      name: 'weight_user_space_logout_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to logout?`
  String get weight_user_space_logout_conntent {
    return Intl.message(
      'Are you sure to logout?',
      name: 'weight_user_space_logout_conntent',
      desc: '',
      args: [],
    );
  }

  /// `No public collections?`
  String get weight_user_space_no_public_connection {
    return Intl.message(
      'No public collections?',
      name: 'weight_user_space_no_public_connection',
      desc: '',
      args: [],
    );
  }

  /// `Premium`
  String get weight_user_space_vip {
    return Intl.message(
      'Premium',
      name: 'weight_user_space_vip',
      desc: '',
      args: [],
    );
  }

  /// `User`
  String get weight_user_space_normal {
    return Intl.message(
      'User',
      name: 'weight_user_space_normal',
      desc: '',
      args: [],
    );
  }

  /// `Annual Premium`
  String get weight_user_space_annual_vip {
    return Intl.message(
      'Annual Premium',
      name: 'weight_user_space_annual_vip',
      desc: '',
      args: [],
    );
  }

  /// `Newest`
  String get weight_user_space_newest {
    return Intl.message(
      'Newest',
      name: 'weight_user_space_newest',
      desc: '',
      args: [],
    );
  }

  /// `Most Played`
  String get weight_user_space_most_play {
    return Intl.message(
      'Most Played',
      name: 'weight_user_space_most_play',
      desc: '',
      args: [],
    );
  }

  /// `Created Favorites`
  String get weight_user_space_created_faviourite_folder {
    return Intl.message(
      'Created Favorites',
      name: 'weight_user_space_created_faviourite_folder',
      desc: '',
      args: [],
    );
  }

  /// `Subscribed Favorites`
  String get weight_user_space_subscribe_faviourite_folder {
    return Intl.message(
      'Subscribed Favorites',
      name: 'weight_user_space_subscribe_faviourite_folder',
      desc: '',
      args: [],
    );
  }

  /// `No Favorites`
  String get weight_user_space_no_faviourite_folder {
    return Intl.message(
      'No Favorites',
      name: 'weight_user_space_no_faviourite_folder',
      desc: '',
      args: [],
    );
  }

  /// `New Version Found`
  String get weight_update_new_version_found {
    return Intl.message(
      'New Version Found',
      name: 'weight_update_new_version_found',
      desc: '',
      args: [],
    );
  }

  /// `Beta`
  String get weight_update_test_version {
    return Intl.message(
      'Beta',
      name: 'weight_update_test_version',
      desc: '',
      args: [],
    );
  }

  /// `Release`
  String get weight_update_release_version {
    return Intl.message(
      'Release',
      name: 'weight_update_release_version',
      desc: '',
      args: [],
    );
  }

  /// `From`
  String get weight_update_from {
    return Intl.message('From', name: 'weight_update_from', desc: '', args: []);
  }

  /// `Ignore Version`
  String get weight_update_ignore_this_version {
    return Intl.message(
      'Ignore Version',
      name: 'weight_update_ignore_this_version',
      desc: '',
      args: [],
    );
  }

  /// `Ignore this version update?`
  String get weight_update_ignore_this_version_message {
    return Intl.message(
      'Ignore this version update?',
      name: 'weight_update_ignore_this_version_message',
      desc: '',
      args: [],
    );
  }

  /// `Add to Local Playlist`
  String get weight_song_list_add_to_local {
    return Intl.message(
      'Add to Local Playlist',
      name: 'weight_song_list_add_to_local',
      desc: '',
      args: [],
    );
  }

  /// `Add to Playlist`
  String get weight_song_list_add_to_list {
    return Intl.message(
      'Add to Playlist',
      name: 'weight_song_list_add_to_list',
      desc: '',
      args: [],
    );
  }

  /// `Added to Playlist`
  String get weight_song_list_added_to_list {
    return Intl.message(
      'Added to Playlist',
      name: 'weight_song_list_added_to_list',
      desc: '',
      args: [],
    );
  }

  /// `Rename Locally`
  String get weight_song_list_rename_add {
    return Intl.message(
      'Rename Locally',
      name: 'weight_song_list_rename_add',
      desc: '',
      args: [],
    );
  }

  /// `New Playlist`
  String get weight_song_list_new_list {
    return Intl.message(
      'New Playlist',
      name: 'weight_song_list_new_list',
      desc: '',
      args: [],
    );
  }

  /// `Saved as Local Playlist`
  String get weight_player_saved_as_local {
    return Intl.message(
      'Saved as Local Playlist',
      name: 'weight_player_saved_as_local',
      desc: '',
      args: [],
    );
  }

  /// `Save as Local Playlist`
  String get weight_player_saved_as_local_playlist {
    return Intl.message(
      'Save as Local Playlist',
      name: 'weight_player_saved_as_local_playlist',
      desc: '',
      args: [],
    );
  }

  /// `Stop after current song`
  String get weight_player_timer_stop_at_end {
    return Intl.message(
      'Stop after current song',
      name: 'weight_player_timer_stop_at_end',
      desc: '',
      args: [],
    );
  }

  /// `Stop after current song finishes`
  String get weight_player_timer_stop_at_end_message {
    return Intl.message(
      'Stop after current song finishes',
      name: 'weight_player_timer_stop_at_end_message',
      desc: '',
      args: [],
    );
  }

  /// `(After finish)`
  String get weight_player_timer_over_at {
    return Intl.message(
      '(After finish)',
      name: 'weight_player_timer_over_at',
      desc: '',
      args: [],
    );
  }

  /// `Stop in`
  String get weight_player_timer_over_discount {
    return Intl.message(
      'Stop in',
      name: 'weight_player_timer_over_discount',
      desc: '',
      args: [],
    );
  }

  /// `Loading Danmuku...`
  String get weight_player_loading_danmuku {
    return Intl.message(
      'Loading Danmuku...',
      name: 'weight_player_loading_danmuku',
      desc: '',
      args: [],
    );
  }

  /// `No Danmuku`
  String get weight_player_no_danmuku {
    return Intl.message(
      'No Danmuku',
      name: 'weight_player_no_danmuku',
      desc: '',
      args: [],
    );
  }

  /// `Stop Timer`
  String get weight_player_stop_timer {
    return Intl.message(
      'Stop Timer',
      name: 'weight_player_stop_timer',
      desc: '',
      args: [],
    );
  }

  /// `Stop at`
  String get weight_player_timer_stop_at {
    return Intl.message(
      'Stop at',
      name: 'weight_player_timer_stop_at',
      desc: '',
      args: [],
    );
  }

  /// `Select Speed`
  String get weight_player_select_speed {
    return Intl.message(
      'Select Speed',
      name: 'weight_player_select_speed',
      desc: '',
      args: [],
    );
  }

  /// `Cannot fetch video info`
  String get weight_player_no_video_fetched {
    return Intl.message(
      'Cannot fetch video info',
      name: 'weight_player_no_video_fetched',
      desc: '',
      args: [],
    );
  }

  /// `Cannot fetch user info`
  String get weight_player_no_user_fetched {
    return Intl.message(
      'Cannot fetch user info',
      name: 'weight_player_no_user_fetched',
      desc: '',
      args: [],
    );
  }

  /// `Custom Timer`
  String get weight_player_timer_custom {
    return Intl.message(
      'Custom Timer',
      name: 'weight_player_timer_custom',
      desc: '',
      args: [],
    );
  }

  /// `Countdown`
  String get weight_player_timer_discount_stop {
    return Intl.message(
      'Countdown',
      name: 'weight_player_timer_discount_stop',
      desc: '',
      args: [],
    );
  }

  /// `Specific Time`
  String get weight_player_timer_timestemp_stop {
    return Intl.message(
      'Specific Time',
      name: 'weight_player_timer_timestemp_stop',
      desc: '',
      args: [],
    );
  }

  /// `Select Time`
  String get weight_player_timer_select_time {
    return Intl.message(
      'Select Time',
      name: 'weight_player_timer_select_time',
      desc: '',
      args: [],
    );
  }

  /// `Default Quality`
  String get weight_player_audio_quilty_default {
    return Intl.message(
      'Default Quality',
      name: 'weight_player_audio_quilty_default',
      desc: '',
      args: [],
    );
  }

  /// `Available`
  String get weight_player_audio_quilty_for_this {
    return Intl.message(
      'Available',
      name: 'weight_player_audio_quilty_for_this',
      desc: '',
      args: [],
    );
  }

  /// `No quality info available`
  String get weight_player_audio_quilty_no_available {
    return Intl.message(
      'No quality info available',
      name: 'weight_player_audio_quilty_no_available',
      desc: '',
      args: [],
    );
  }

  /// `Available qualities are fetched from API based on login status, premium status, and source. It does not mean only these qualities exist.\nDownloaded songs only use the quality at download time.`
  String get weight_player_audio_quilty_for_this_message {
    return Intl.message(
      'Available qualities are fetched from API based on login status, premium status, and source. It does not mean only these qualities exist.\nDownloaded songs only use the quality at download time.',
      name: 'weight_player_audio_quilty_for_this_message',
      desc: '',
      args: [],
    );
  }

  /// `Current`
  String get weight_player_audio_quilty_for_this_using {
    return Intl.message(
      'Current',
      name: 'weight_player_audio_quilty_for_this_using',
      desc: '',
      args: [],
    );
  }

  /// `Scan QR`
  String get weight_login_scan_qr {
    return Intl.message(
      'Scan QR',
      name: 'weight_login_scan_qr',
      desc: '',
      args: [],
    );
  }

  /// `Screenshot and scan with Bilibili App`
  String get weight_login_screenshoot_to_qr_hint {
    return Intl.message(
      'Screenshot and scan with Bilibili App',
      name: 'weight_login_screenshoot_to_qr_hint',
      desc: '',
      args: [],
    );
  }

  /// `Scanned, please confirm on phone`
  String get weight_login_scan_confirm {
    return Intl.message(
      'Scanned, please confirm on phone',
      name: 'weight_login_scan_confirm',
      desc: '',
      args: [],
    );
  }

  /// `QR Code Expired`
  String get weight_login_qr_expired {
    return Intl.message(
      'QR Code Expired',
      name: 'weight_login_qr_expired',
      desc: '',
      args: [],
    );
  }

  /// `Refresh QR`
  String get weight_login_refresh_qr {
    return Intl.message(
      'Refresh QR',
      name: 'weight_login_refresh_qr',
      desc: '',
      args: [],
    );
  }

  /// `Cookie Login`
  String get weight_login_cookie {
    return Intl.message(
      'Cookie Login',
      name: 'weight_login_cookie',
      desc: '',
      args: [],
    );
  }

  /// `Manual Cookie`
  String get weight_login_cookie_tips {
    return Intl.message(
      'Manual Cookie',
      name: 'weight_login_cookie_tips',
      desc: '',
      args: [],
    );
  }

  /// `Copy full Cookie string from browser and paste below.`
  String get weight_login_cookie_hint {
    return Intl.message(
      'Copy full Cookie string from browser and paste below.',
      name: 'weight_login_cookie_hint',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get weight_login_logout {
    return Intl.message(
      'Logout',
      name: 'weight_login_logout',
      desc: '',
      args: [],
    );
  }

  /// `Logged in, enjoy!`
  String get weight_login_over {
    return Intl.message(
      'Logged in, enjoy!',
      name: 'weight_login_over',
      desc: '',
      args: [],
    );
  }

  /// `Welcome Back`
  String get weight_login_welcome_back {
    return Intl.message(
      'Welcome Back',
      name: 'weight_login_welcome_back',
      desc: '',
      args: [],
    );
  }

  /// `Hi-Res`
  String get util_audio_quality_hires {
    return Intl.message(
      'Hi-Res',
      name: 'util_audio_quality_hires',
      desc: '',
      args: [],
    );
  }

  /// `Hi-Res (Premium)`
  String get util_audio_quality_hires_detail {
    return Intl.message(
      'Hi-Res (Premium)',
      name: 'util_audio_quality_hires_detail',
      desc: '',
      args: [],
    );
  }

  /// `Dolby Atmos`
  String get util_audio_quality_dolby {
    return Intl.message(
      'Dolby Atmos',
      name: 'util_audio_quality_dolby',
      desc: '',
      args: [],
    );
  }

  /// `Dolby Atmos (Premium)`
  String get util_audio_quality_dolby_detail {
    return Intl.message(
      'Dolby Atmos (Premium)',
      name: 'util_audio_quality_dolby_detail',
      desc: '',
      args: [],
    );
  }

  /// `High`
  String get util_audio_quality_high {
    return Intl.message(
      'High',
      name: 'util_audio_quality_high',
      desc: '',
      args: [],
    );
  }

  /// `High (192k)`
  String get util_audio_quality_high_detail {
    return Intl.message(
      'High (192k)',
      name: 'util_audio_quality_high_detail',
      desc: '',
      args: [],
    );
  }

  /// `Standard`
  String get util_audio_quality_middle {
    return Intl.message(
      'Standard',
      name: 'util_audio_quality_middle',
      desc: '',
      args: [],
    );
  }

  /// `Standard (132K)`
  String get util_audio_quality_middle_detail {
    return Intl.message(
      'Standard (132K)',
      name: 'util_audio_quality_middle_detail',
      desc: '',
      args: [],
    );
  }

  /// `Low`
  String get util_audio_quality_low {
    return Intl.message(
      'Low',
      name: 'util_audio_quality_low',
      desc: '',
      args: [],
    );
  }

  /// `Low (64k)`
  String get util_audio_quality_low_detail {
    return Intl.message(
      'Low (64k)',
      name: 'util_audio_quality_low_detail',
      desc: '',
      args: [],
    );
  }

  /// `Cannot open link`
  String get util_scheme_lauch_fail {
    return Intl.message(
      'Cannot open link',
      name: 'util_scheme_lauch_fail',
      desc: '',
      args: [],
    );
  }

  /// `Checking for updates...`
  String get util_update_checking {
    return Intl.message(
      'Checking for updates...',
      name: 'util_update_checking',
      desc: '',
      args: [],
    );
  }

  /// `Already latest version`
  String get util_update_already_newest {
    return Intl.message(
      'Already latest version',
      name: 'util_update_already_newest',
      desc: '',
      args: [],
    );
  }

  /// `Download Manager`
  String get pages_library_download_manager {
    return Intl.message(
      'Download Manager',
      name: 'pages_library_download_manager',
      desc: '',
      args: [],
    );
  }

  /// `Delete All`
  String get pages_library_download_delete_all {
    return Intl.message(
      'Delete All',
      name: 'pages_library_download_delete_all',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to delete all download tasks and files?`
  String get pages_library_download_delete_all_confirm {
    return Intl.message(
      'Are you sure to delete all download tasks and files?',
      name: 'pages_library_download_delete_all_confirm',
      desc: '',
      args: [],
    );
  }

  /// `Pause All`
  String get pages_library_download_pause_all {
    return Intl.message(
      'Pause All',
      name: 'pages_library_download_pause_all',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to pause all active downloads?`
  String get pages_library_download_pause_all_confirm {
    return Intl.message(
      'Are you sure to pause all active downloads?',
      name: 'pages_library_download_pause_all_confirm',
      desc: '',
      args: [],
    );
  }

  /// `Resume All`
  String get pages_library_download_resume_all {
    return Intl.message(
      'Resume All',
      name: 'pages_library_download_resume_all',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to resume all downloads?`
  String get pages_library_download_resume_all_confirm {
    return Intl.message(
      'Are you sure to resume all downloads?',
      name: 'pages_library_download_resume_all_confirm',
      desc: '',
      args: [],
    );
  }

  /// `No downloads`
  String get pages_library_download_empty {
    return Intl.message(
      'No downloads',
      name: 'pages_library_download_empty',
      desc: '',
      args: [],
    );
  }

  /// `Downloading`
  String get pages_library_download_status_downloading {
    return Intl.message(
      'Downloading',
      name: 'pages_library_download_status_downloading',
      desc: '',
      args: [],
    );
  }

  /// `Queued`
  String get pages_library_download_status_queued {
    return Intl.message(
      'Queued',
      name: 'pages_library_download_status_queued',
      desc: '',
      args: [],
    );
  }

  /// `Downloaded`
  String get pages_library_download_status_completed {
    return Intl.message(
      'Downloaded',
      name: 'pages_library_download_status_completed',
      desc: '',
      args: [],
    );
  }

  /// `Failed`
  String get pages_library_download_status_failed {
    return Intl.message(
      'Failed',
      name: 'pages_library_download_status_failed',
      desc: '',
      args: [],
    );
  }

  /// `Cancel Download`
  String get pages_library_download_action_cancel {
    return Intl.message(
      'Cancel Download',
      name: 'pages_library_download_action_cancel',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get pages_library_download_action_delete {
    return Intl.message(
      'Delete',
      name: 'pages_library_download_action_delete',
      desc: '',
      args: [],
    );
  }

  /// `Add to Playlist`
  String get pages_library_download_action_add_to_playlist {
    return Intl.message(
      'Add to Playlist',
      name: 'pages_library_download_action_add_to_playlist',
      desc: '',
      args: [],
    );
  }

  /// `Add to Playlist Sheet`
  String get pages_library_download_action_add_to_sheet {
    return Intl.message(
      'Add to Playlist Sheet',
      name: 'pages_library_download_action_add_to_sheet',
      desc: '',
      args: [],
    );
  }

  /// `View Details`
  String get pages_library_download_action_detail {
    return Intl.message(
      'View Details',
      name: 'pages_library_download_action_detail',
      desc: '',
      args: [],
    );
  }

  /// `Create Playlist`
  String get pages_library_playlist_create {
    return Intl.message(
      'Create Playlist',
      name: 'pages_library_playlist_create',
      desc: '',
      args: [],
    );
  }

  /// `Edit Playlist`
  String get pages_library_playlist_edit {
    return Intl.message(
      'Edit Playlist',
      name: 'pages_library_playlist_edit',
      desc: '',
      args: [],
    );
  }

  /// `Playlist Name`
  String get pages_library_playlist_name {
    return Intl.message(
      'Playlist Name',
      name: 'pages_library_playlist_name',
      desc: '',
      args: [],
    );
  }

  /// `Description (Optional)`
  String get pages_library_playlist_desc {
    return Intl.message(
      'Description (Optional)',
      name: 'pages_library_playlist_desc',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to delete playlist "{title}"?`
  String pages_library_playlist_delete_confirm(Object title) {
    return Intl.message(
      'Are you sure to delete playlist "$title"?',
      name: 'pages_library_playlist_delete_confirm',
      desc: '',
      args: [title],
    );
  }

  /// `Download this playlist?`
  String get pages_library_playlist_download_confirm {
    return Intl.message(
      'Download this playlist?',
      name: 'pages_library_playlist_download_confirm',
      desc: '',
      args: [],
    );
  }

  /// `All added to download queue`
  String get pages_library_playlist_download_started {
    return Intl.message(
      'All added to download queue',
      name: 'pages_library_playlist_download_started',
      desc: '',
      args: [],
    );
  }

  /// `Current playlist is not empty. Replace it?`
  String get pages_library_playlist_play_replace_confirm {
    return Intl.message(
      'Current playlist is not empty. Replace it?',
      name: 'pages_library_playlist_play_replace_confirm',
      desc: '',
      args: [],
    );
  }

  /// `No songs`
  String get pages_library_playlist_empty {
    return Intl.message(
      'No songs',
      name: 'pages_library_playlist_empty',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get pages_library_playlist_menu_rename {
    return Intl.message(
      'Rename',
      name: 'pages_library_playlist_menu_rename',
      desc: '',
      args: [],
    );
  }

  /// `Reset to Original Title`
  String get pages_library_playlist_menu_reset_title {
    return Intl.message(
      'Reset to Original Title',
      name: 'pages_library_playlist_menu_reset_title',
      desc: '',
      args: [],
    );
  }

  /// `Remove from Playlist`
  String get pages_library_playlist_menu_remove {
    return Intl.message(
      'Remove from Playlist',
      name: 'pages_library_playlist_menu_remove',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get pages_library_playlist_rename_dialog_title {
    return Intl.message(
      'Rename',
      name: 'pages_library_playlist_rename_dialog_title',
      desc: '',
      args: [],
    );
  }

  /// `Title`
  String get pages_library_playlist_rename_dialog_label {
    return Intl.message(
      'Title',
      name: 'pages_library_playlist_rename_dialog_label',
      desc: '',
      args: [],
    );
  }

  /// `Favorites`
  String get pages_library_category_favorites {
    return Intl.message(
      'Favorites',
      name: 'pages_library_category_favorites',
      desc: '',
      args: [],
    );
  }

  /// `Collections`
  String get pages_library_category_collections {
    return Intl.message(
      'Collections',
      name: 'pages_library_category_collections',
      desc: '',
      args: [],
    );
  }

  /// `Local Playlists`
  String get pages_library_category_local {
    return Intl.message(
      'Local Playlists',
      name: 'pages_library_category_local',
      desc: '',
      args: [],
    );
  }

  /// `Not logged in. Please login to view.`
  String get pages_library_category_not_logged_in {
    return Intl.message(
      'Not logged in. Please login to view.',
      name: 'pages_library_category_not_logged_in',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get pages_library_category_login {
    return Intl.message(
      'Login',
      name: 'pages_library_category_login',
      desc: '',
      args: [],
    );
  }

  /// `No local playlists`
  String get pages_library_category_empty_local {
    return Intl.message(
      'No local playlists',
      name: 'pages_library_category_empty_local',
      desc: '',
      args: [],
    );
  }

  /// `No {title}. Go to Bilibili to create one.`
  String pages_library_category_empty_online(Object title) {
    return Intl.message(
      'No $title. Go to Bilibili to create one.',
      name: 'pages_library_category_empty_online',
      desc: '',
      args: [title],
    );
  }

  /// `Go to Bilibili`
  String get pages_library_category_go_bilibili {
    return Intl.message(
      'Go to Bilibili',
      name: 'pages_library_category_go_bilibili',
      desc: '',
      args: [],
    );
  }

  /// `New Playlist`
  String get pages_library_category_create_local {
    return Intl.message(
      'New Playlist',
      name: 'pages_library_category_create_local',
      desc: '',
      args: [],
    );
  }

  /// `Clone Playlist`
  String get pages_library_online_clone {
    return Intl.message(
      'Clone Playlist',
      name: 'pages_library_online_clone',
      desc: '',
      args: [],
    );
  }

  /// `Clone "{title}" to local playlist?`
  String pages_library_online_clone_confirm(Object title) {
    return Intl.message(
      'Clone "$title" to local playlist?',
      name: 'pages_library_online_clone_confirm',
      desc: '',
      args: [title],
    );
  }

  /// `Cloned to local playlist`
  String get pages_library_online_clone_success {
    return Intl.message(
      'Cloned to local playlist',
      name: 'pages_library_online_clone_success',
      desc: '',
      args: [],
    );
  }

  /// `Clone failed: {error}`
  String pages_library_online_clone_failed(Object error) {
    return Intl.message(
      'Clone failed: $error',
      name: 'pages_library_online_clone_failed',
      desc: '',
      args: [error],
    );
  }

  /// `Remove Video`
  String get pages_library_online_remove_video {
    return Intl.message(
      'Remove Video',
      name: 'pages_library_online_remove_video',
      desc: '',
      args: [],
    );
  }

  /// `Remove "{title}" from this favorite folder?`
  String pages_library_online_remove_video_confirm(Object title) {
    return Intl.message(
      'Remove "$title" from this favorite folder?',
      name: 'pages_library_online_remove_video_confirm',
      desc: '',
      args: [title],
    );
  }

  /// `Removed`
  String get pages_library_online_remove_success {
    return Intl.message(
      'Removed',
      name: 'pages_library_online_remove_success',
      desc: '',
      args: [],
    );
  }

  /// `Remove failed`
  String get pages_library_online_remove_failed {
    return Intl.message(
      'Remove failed',
      name: 'pages_library_online_remove_failed',
      desc: '',
      args: [],
    );
  }

  /// `Edit Favorites`
  String get pages_library_online_edit_fav {
    return Intl.message(
      'Edit Favorites',
      name: 'pages_library_online_edit_fav',
      desc: '',
      args: [],
    );
  }

  /// `Delete Favorites`
  String get pages_library_online_delete_fav {
    return Intl.message(
      'Delete Favorites',
      name: 'pages_library_online_delete_fav',
      desc: '',
      args: [],
    );
  }

  /// `Delete this favorite folder? This cannot be undone.`
  String get pages_library_online_delete_fav_confirm {
    return Intl.message(
      'Delete this favorite folder? This cannot be undone.',
      name: 'pages_library_online_delete_fav_confirm',
      desc: '',
      args: [],
    );
  }

  /// `Deleted successfully`
  String get pages_library_online_delete_success {
    return Intl.message(
      'Deleted successfully',
      name: 'pages_library_online_delete_success',
      desc: '',
      args: [],
    );
  }

  /// `Delete failed`
  String get pages_library_online_delete_failed {
    return Intl.message(
      'Delete failed',
      name: 'pages_library_online_delete_failed',
      desc: '',
      args: [],
    );
  }

  /// `Title`
  String get pages_library_online_edit_title {
    return Intl.message(
      'Title',
      name: 'pages_library_online_edit_title',
      desc: '',
      args: [],
    );
  }

  /// `Intro`
  String get pages_library_online_edit_intro {
    return Intl.message(
      'Intro',
      name: 'pages_library_online_edit_intro',
      desc: '',
      args: [],
    );
  }

  /// `Public Favorites`
  String get pages_library_online_edit_public {
    return Intl.message(
      'Public Favorites',
      name: 'pages_library_online_edit_public',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get pages_library_online_edit_save {
    return Intl.message(
      'Save',
      name: 'pages_library_online_edit_save',
      desc: '',
      args: [],
    );
  }

  /// `Edited successfully`
  String get pages_library_online_edit_success {
    return Intl.message(
      'Edited successfully',
      name: 'pages_library_online_edit_success',
      desc: '',
      args: [],
    );
  }

  /// `Edit failed`
  String get pages_library_online_edit_failed {
    return Intl.message(
      'Edit failed',
      name: 'pages_library_online_edit_failed',
      desc: '',
      args: [],
    );
  }

  /// `Tap again to refresh`
  String get pages_discover_refresh_too_frequent {
    return Intl.message(
      'Tap again to refresh',
      name: 'pages_discover_refresh_too_frequent',
      desc: '',
      args: [],
    );
  }

  /// `Recommend`
  String get pages_discover_category_recommend {
    return Intl.message(
      'Recommend',
      name: 'pages_discover_category_recommend',
      desc: '',
      args: [],
    );
  }

  /// `Feed`
  String get pages_discover_category_feed {
    return Intl.message(
      'Feed',
      name: 'pages_discover_category_feed',
      desc: '',
      args: [],
    );
  }

  /// `History`
  String get pages_discover_category_history {
    return Intl.message(
      'History',
      name: 'pages_discover_category_history',
      desc: '',
      args: [],
    );
  }

  /// `Following`
  String get pages_discover_category_subscribe {
    return Intl.message(
      'Following',
      name: 'pages_discover_category_subscribe',
      desc: '',
      args: [],
    );
  }

  /// `Live`
  String get pages_discover_category_live {
    return Intl.message(
      'Live',
      name: 'pages_discover_category_live',
      desc: '',
      args: [],
    );
  }

  /// `Ranking`
  String get pages_discover_category_rank {
    return Intl.message(
      'Ranking',
      name: 'pages_discover_category_rank',
      desc: '',
      args: [],
    );
  }

  /// `Music Ranking`
  String get pages_discover_category_music_rank {
    return Intl.message(
      'Music Ranking',
      name: 'pages_discover_category_music_rank',
      desc: '',
      args: [],
    );
  }

  /// `Kichiku Ranking`
  String get pages_discover_category_kichiku_rank {
    return Intl.message(
      'Kichiku Ranking',
      name: 'pages_discover_category_kichiku_rank',
      desc: '',
      args: [],
    );
  }

  /// `Not logged in. Cannot view feed.`
  String get pages_discover_feed_not_logged_in {
    return Intl.message(
      'Not logged in. Cannot view feed.',
      name: 'pages_discover_feed_not_logged_in',
      desc: '',
      args: [],
    );
  }

  /// `Not logged in. Cannot view history.`
  String get pages_discover_history_not_logged_in {
    return Intl.message(
      'Not logged in. Cannot view history.',
      name: 'pages_discover_history_not_logged_in',
      desc: '',
      args: [],
    );
  }

  /// `Not logged in. Cannot view following list.`
  String get pages_discover_subscribe_not_logged_in {
    return Intl.message(
      'Not logged in. Cannot view following list.',
      name: 'pages_discover_subscribe_not_logged_in',
      desc: '',
      args: [],
    );
  }

  /// `Live feature under development`
  String get pages_discover_live_developing {
    return Intl.message(
      'Live feature under development',
      name: 'pages_discover_live_developing',
      desc: '',
      args: [],
    );
  }

  /// `Network error or API restricted. Please retry.`
  String get pages_discover_error_network {
    return Intl.message(
      'Network error or API restricted. Please retry.',
      name: 'pages_discover_error_network',
      desc: '',
      args: [],
    );
  }

  /// `Network error or API restricted. Please retry.\nRankings have strict restrictions. Try logging in if not already.`
  String get pages_discover_error_rank_risk {
    return Intl.message(
      'Network error or API restricted. Please retry.\nRankings have strict restrictions. Try logging in if not already.',
      name: 'pages_discover_error_rank_risk',
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
