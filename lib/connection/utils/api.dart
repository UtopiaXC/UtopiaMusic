class Api {
  static const String urlBase = 'https://api.bilibili.com';
  static const String urlLiveBase = 'https://api.live.bilibili.com';
  static const String urlLoginBase = 'https://passport.bilibili.com';
  static const String urlSearchBase = 'https://s.search.bilibili.com';

  static const String urlRecommentList =
      '/x/web-interface/wbi/index/top/feed/rcmd';
  static const String urlPopularList = '/x/web-interface/popular';
  static const String urlVideoPlay = '/x/player/playurl';
  static const String urlNav = '/x/web-interface/nav';
  static const String urlRanking= '/x/web-interface/ranking/v2';
  static const String urlRankingRegion = '/x/web-interface/ranking/region';
  static const String urlPlayUrlWbi = '/x/player/wbi/playurl';
  static const String urlSearch = '/x/web-interface/search/type';
  static const String urlVideoDetail = '/x/web-interface/wbi/view';
  static const String urlDynamicFeed = '/x/polymer/web-dynamic/v1/feed/all';

  // Playlist APIs
  static const String urlFavoriteFolderList = '/x/v3/fav/folder/list';
  static const String urlFavoriteResourceList = '/x/v3/fav/resource/list';
  static const String urlCollectionResourceList = '/x/v3/fav/resource/list';

  // Login APIs
  static const String urlLoginQRCodeGenerate = '/x/passport-login/web/qrcode/generate';
  static const String urlLoginQRCodePoll = '/x/passport-login/web/qrcode/poll';
  static const String urlUserInfo = '/x/space/wbi/acc/info';
}
