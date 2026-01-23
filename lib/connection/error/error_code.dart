class ErrorCode {
  // 权限类
  static const int appBanned = -1; // 应用程序不存在或已被封禁
  static const int accessKeyError = -2; // Access Key 错误
  static const int signError = -3; // API 校验密匙错误
  static const int noPermission = -4; // 调用方对该 Method 没有权限
  static const int notLoggedIn = -101; // 账号未登录
  static const int accountBanned = -102; // 账号被封停
  static const int creditsInsufficient = -103; // 积分不足
  static const int coinsInsufficient = -104; // 硬币不足
  static const int captchaError = -105; // 验证码错误
  static const int notOfficialMember = -106; // 账号非正式会员或在适应期
  static const int appNotExists = -107; // 应用不存在或者被封禁
  static const int noPhoneBound1 = -108; // 未绑定手机
  static const int noPhoneBound2 = -110; // 未绑定手机
  static const int csrfError = -111; // csrf 校验失败
  static const int systemUpgrading = -112; // 系统升级中
  static const int notRealNameVerified = -113; // 账号尚未实名认证
  static const int bindPhoneFirst = -114; // 请先绑定手机
  static const int verifyRealNameFirst = -115; // 请先完成实名认证

  // 请求类
  static const int notModified = -304; // 木有改动
  static const int redirect = -307; // 撞车跳转
  static const int riskControlFail = -352; // 风控校验失败 (UA 或 wbi 参数不合法)
  static const int requestError = -400; // 请求错误
  static const int unauthorized = -401; // 未认证 (或非法请求)
  static const int accessDenied = -403; // 访问权限不足
  static const int notFound = -404; // 啥都木有
  static const int methodNotAllowed = -405; // 不支持该方法
  static const int conflict = -409; // 冲突
  static const int ipRiskControl = -412; // 请求被拦截 (客户端 ip 被服务端风控)
  static const int serverError = -500; // 服务器错误
  static const int serviceUnavailable = -503; // 过载保护,服务暂不可用
  static const int timeout = -504; // 服务调用超时
  static const int limitExceeded = -509; // 超出限制
  static const int fileNotExists = -616; // 上传文件不存在
  static const int fileTooLarge = -617; // 上传文件太大
  static const int tooManyLoginFailures = -625; // 登录失败次数太多
  static const int userNotExists = -626; // 用户不存在
  static const int passwordTooWeak = -628; // 密码太弱
  static const int usernameOrPasswordError = -629; // 用户名或密码错误
  static const int operationLimit = -632; // 操作对象数量限制
  static const int locked = -643; // 被锁定
  static const int levelTooLow = -650; // 用户等级太低
  static const int duplicateUser = -652; // 重复的用户
  static const int tokenExpired = -658; // Token 过期
  static const int passwordTimestampExpired = -662; // 密码时间戳过期
  static const int regionRestricted = -688; // 地理区域限制
  static const int copyrightRestricted = -689; // 版权限制
  static const int deductMoralFailed = -701; // 扣节操失败
  static const int tooFrequent = -799; // 请求过于频繁，请稍后再试
  static const int serverErrorCute = -8888; // 对不起，服务器开小差了~ (ಥ﹏ಥ)

  static String getMessage(int code) {
    switch (code) {
      case appBanned:
        return '应用程序不存在或已被封禁';
      case accessKeyError:
        return 'Access Key 错误';
      case signError:
        return 'API 校验密匙错误';
      case noPermission:
        return '调用方对该 Method 没有权限';
      case notLoggedIn:
        return '账号未登录';
      case accountBanned:
        return '账号被封停';
      case creditsInsufficient:
        return '积分不足';
      case coinsInsufficient:
        return '硬币不足';
      case captchaError:
        return '验证码错误';
      case notOfficialMember:
        return '账号非正式会员或在适应期';
      case appNotExists:
        return '应用不存在或者被封禁';
      case noPhoneBound1:
      case noPhoneBound2:
        return '未绑定手机';
      case csrfError:
        return 'csrf 校验失败';
      case systemUpgrading:
        return '系统升级中';
      case notRealNameVerified:
        return '账号尚未实名认证';
      case bindPhoneFirst:
        return '请先绑定手机';
      case verifyRealNameFirst:
        return '请先完成实名认证';
      case notModified:
        return '木有改动';
      case redirect:
        return '撞车跳转';
      case riskControlFail:
        return '风控校验失败';
      case requestError:
        return '请求错误';
      case unauthorized:
        return '未认证';
      case accessDenied:
        return '访问权限不足';
      case notFound:
        return '啥都木有';
      case methodNotAllowed:
        return '不支持该方法';
      case conflict:
        return '冲突';
      case ipRiskControl:
        return '请求被拦截';
      case serverError:
        return '服务器错误';
      case serviceUnavailable:
        return '服务暂不可用';
      case timeout:
        return '服务调用超时';
      case limitExceeded:
        return '超出限制';
      case fileNotExists:
        return '上传文件不存在';
      case fileTooLarge:
        return '上传文件太大';
      case tooManyLoginFailures:
        return '登录失败次数太多';
      case userNotExists:
        return '用户不存在';
      case passwordTooWeak:
        return '密码太弱';
      case usernameOrPasswordError:
        return '用户名或密码错误';
      case operationLimit:
        return '操作对象数量限制';
      case locked:
        return '被锁定';
      case levelTooLow:
        return '用户等级太低';
      case duplicateUser:
        return '重复的用户';
      case tokenExpired:
        return 'Token 过期';
      case passwordTimestampExpired:
        return '密码时间戳过期';
      case regionRestricted:
        return '地理区域限制';
      case copyrightRestricted:
        return '版权限制';
      case deductMoralFailed:
        return '扣节操失败';
      case tooFrequent:
        return '请求过于频繁，请稍后再试';
      case serverErrorCute:
        return '对不起，服务器开小差了';
      default:
        return '未知错误 ($code)';
    }
  }

  static bool isDefined(int code) {
    return !getMessage(code).startsWith('未知错误');
  }
}
