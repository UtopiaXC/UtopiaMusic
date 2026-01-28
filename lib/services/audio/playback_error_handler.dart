import 'dart:async';
import 'package:flutter/material.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "PLAYBACK_ERROR_HANDLER";

enum PlaybackErrorType {
  network,
  resourceUnavailable,
  codecUnsupported,
  authExpired,
  rateLimit,
  unknown,
}

class PlaybackError {
  final PlaybackErrorType type;
  final String message;
  final String? bvid;
  final int? cid;
  final bool canRetry;
  final bool shouldSkip;

  PlaybackError({
    required this.type,
    required this.message,
    this.bvid,
    this.cid,
    this.canRetry = false,
    this.shouldSkip = false,
  });

  factory PlaybackError.fromException(dynamic e, {String? bvid, int? cid}) {
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        errorStr.contains('network')) {
      return PlaybackError(
        type: PlaybackErrorType.network,
        message: '网络连接失败，请检查网络设置',
        bvid: bvid,
        cid: cid,
        canRetry: true,
        shouldSkip: false,
      );
    }

    if (errorStr.contains('403') ||
        errorStr.contains('404') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('resource')) {
      return PlaybackError(
        type: PlaybackErrorType.resourceUnavailable,
        message: '资源不可用（可能是版权限制、充电视频或已删除）',
        bvid: bvid,
        cid: cid,
        canRetry: false,
        shouldSkip: true,
      );
    }

    if (errorStr.contains('401') ||
        errorStr.contains('auth') ||
        errorStr.contains('login') ||
        errorStr.contains('expired')) {
      return PlaybackError(
        type: PlaybackErrorType.authExpired,
        message: '登录状态已过期，请重新登录',
        bvid: bvid,
        cid: cid,
        canRetry: false,
        shouldSkip: false,
      );
    }

    if (errorStr.contains('429') ||
        errorStr.contains('rate') ||
        errorStr.contains('limit') ||
        errorStr.contains('频繁')) {
      return PlaybackError(
        type: PlaybackErrorType.rateLimit,
        message: '请求过于频繁，请稍后再试',
        bvid: bvid,
        cid: cid,
        canRetry: true,
        shouldSkip: false,
      );
    }

    if (errorStr.contains('codec') ||
        errorStr.contains('decode') ||
        errorStr.contains('format')) {
      return PlaybackError(
        type: PlaybackErrorType.codecUnsupported,
        message: '音频格式不支持',
        bvid: bvid,
        cid: cid,
        canRetry: false,
        shouldSkip: true,
      );
    }

    return PlaybackError(
      type: PlaybackErrorType.unknown,
      message: '播放出错：$e',
      bvid: bvid,
      cid: cid,
      canRetry: true,
      shouldSkip: false,
    );
  }
}

class PlaybackErrorHandler {
  static final PlaybackErrorHandler _instance = PlaybackErrorHandler._internal();
  factory PlaybackErrorHandler() => _instance;
  PlaybackErrorHandler._internal();

  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  DateTime? _lastSnackbarTime;
  static const Duration _snackbarCooldown = Duration(seconds: 2);

  Future<PlaybackErrorAction> handleError(
      PlaybackError error, {
        bool autoSkipEnabled = true,
      }) async {
    Log.e(_tag, "Handling playback error: ${error.type} - ${error.message}");

    _consecutiveErrors++;

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _showErrorDialog(
        '连续播放失败',
        '已连续 $_consecutiveErrors 首歌曲播放失败，请检查：\n'
            '1. 网络连接是否正常\n'
            '2. 是否已登录（部分资源需要登录）\n'
            '3. 播放列表中是否有过多无效资源',
        showRetryAll: true,
      );
      _consecutiveErrors = 0;
      return PlaybackErrorAction.stop;
    }

    switch (error.type) {
      case PlaybackErrorType.network:
        _showSnackbar(error.message, action: SnackBarAction(
          label: '重试',
          onPressed: () {
          },
        ));
        return error.canRetry ? PlaybackErrorAction.retry : PlaybackErrorAction.skip;

      case PlaybackErrorType.resourceUnavailable:
        if (autoSkipEnabled) {
          _showSnackbar('${error.message}，已自动跳过');
          return PlaybackErrorAction.skipAndRemove;
        } else {
          _showSnackbar(error.message);
          return PlaybackErrorAction.stop;
        }

      case PlaybackErrorType.authExpired:
        _showErrorDialog('登录已过期', error.message);
        return PlaybackErrorAction.stop;

      case PlaybackErrorType.rateLimit:
        _showSnackbar(error.message);
        await Future.delayed(const Duration(seconds: 3));
        return PlaybackErrorAction.retry;

      case PlaybackErrorType.codecUnsupported:
        _showSnackbar(error.message);
        return PlaybackErrorAction.skip;

      case PlaybackErrorType.unknown:
      default:
        _showSnackbar(error.message);
        return autoSkipEnabled ? PlaybackErrorAction.skip : PlaybackErrorAction.stop;
    }
  }

  void onPlaybackSuccess() {
    _consecutiveErrors = 0;
  }

  void _showSnackbar(String message, {SnackBarAction? action}) {
    final now = DateTime.now();
    if (_lastSnackbarTime != null &&
        now.difference(_lastSnackbarTime!) < _snackbarCooldown) {
      return;
    }
    _lastSnackbarTime = now;

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message, {bool showRetryAll = false}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (showRetryAll)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('清理无效资源'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }
}

enum PlaybackErrorAction {
  retry,
  skip,
  skipAndRemove,
  stop,
}