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
  static const String urlRanking = '/x/web-interface/ranking/v2';
  static const String urlRankingRegion = '/x/web-interface/ranking/region';
  static const String urlPlayUrlWbi = '/x/player/wbi/playurl';
  static const String urlSearch = '/x/web-interface/search/type';
  static const String urlVideoDetail = '/x/web-interface/wbi/view';
  static const String urlDynamicFeed = '/x/polymer/web-dynamic/v1/feed/all';
  static const String urlFavoriteFolderList = '/x/v3/fav/folder/list';
  static const String urlFavFolderCreatedListAll =
      '/x/v3/fav/folder/created/list-all';
  static const String urlFavFolderCollectedList =
      '/x/v3/fav/folder/collected/list';
  static const String urlFavFolderInfo = '/x/v3/fav/folder/info';
  static const String urlFavoriteResourceList = '/x/v3/fav/resource/list';
  static const String urlCollectionResourceList = '/x/v3/fav/resource/list';
  static const String urlLoginQRCodeGenerate =
      '/x/passport-login/web/qrcode/generate';
  static const String urlLoginQRCodePoll = '/x/passport-login/web/qrcode/poll';
  static const String urlUserInfo = '/x/space/wbi/acc/info';
  static const String passportTvBase = 'https://passport.bilibili.com';
  static const String urlTvLoginQRCodeAuthCode =
      '/x/passport-tv-login/qrcode/auth_code';
  static const String urlTvLoginQRCodePoll = '/x/passport-tv-login/qrcode/poll';
  static const String tvAppKey = '4409e2ce8ffd12b8';
  static const String tvAppSecret = '59b43e04ad6965f34319062b478f83dd';
  static const String urlExit = '/login/exit/v2';
}
