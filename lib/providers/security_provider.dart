import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:privacy_screen/privacy_screen.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SECURITY_PROVIDER";

enum LockDelayOption {
  immediate,
  oneMinute,
  threeMinutes,
  fiveMinutes,
  tenMinutes,
  thirtyMinutes,
  custom,
}

class SecurityProvider extends ChangeNotifier {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lockDelayOptionKey = 'lock_delay_option';
  static const String _customLockDelayKey = 'custom_lock_delay';
  static const String _privacyScreenEnabledKey = 'privacy_screen_enabled';

  final LocalAuthentication _auth = LocalAuthentication();
  bool _biometricEnabled = false;
  LockDelayOption _lockDelayOption = LockDelayOption.immediate;
  int _customLockDelayMinutes = 0;
  bool _privacyScreenEnabled = false;
  
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _lastPausedTime;

  bool get biometricEnabled => _biometricEnabled;
  LockDelayOption get lockDelayOption => _lockDelayOption;
  int get customLockDelayMinutes => _customLockDelayMinutes;
  bool get isLocked => _isLocked;
  bool get privacyScreenEnabled => _privacyScreenEnabled;

  SecurityProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    
    final optionIndex = prefs.getInt(_lockDelayOptionKey) ?? LockDelayOption.immediate.index;
    if (optionIndex >= 0 && optionIndex < LockDelayOption.values.length) {
      _lockDelayOption = LockDelayOption.values[optionIndex];
    }
    
    _customLockDelayMinutes = prefs.getInt(_customLockDelayKey) ?? 0;
    
    _privacyScreenEnabled = prefs.getBool(_privacyScreenEnabledKey) ?? false;

    if (_biometricEnabled) {
      _isLocked = true;
      _privacyScreenEnabled = true;
      try {
        await PrivacyScreen.instance.enable();
      } catch (e) {
        Log.w(_tag, 'Error enabling privacy screen: $e');
      }

    } else if (_privacyScreenEnabled) {
      try {
        await PrivacyScreen.instance.enable();
      } catch (e) {
        Log.w(_tag, 'Error enabling privacy screen: $e');
      }
    } else {
      try {
        await PrivacyScreen.instance.disable();
      } catch (e) {
        Log.w(_tag, 'Error disabling privacy screen: $e');
      }
    }
    
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    Log.d(_tag, 'setBiometricEnabled called with enabled=$enabled');
    if (enabled) {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      Log.d(_tag, 'canCheckBiometrics=$canAuthenticateWithBiometrics, isDeviceSupported=$canAuthenticate');

      if (!canAuthenticate) {
        Log.d(_tag, 'Device not supported for authentication');
        return;
      }
      
      try {
        Log.d(_tag, 'Starting authentication...');
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: '请验证身份以启用生物识别',
          biometricOnly: true,
        );
        Log.d(_tag, 'Authentication result=$didAuthenticate');
        if (!didAuthenticate) {
          return;
        }
      } catch (e) {
        Log.w(_tag, 'Authentication error: $e');
        return;
      }
    }

    _biometricEnabled = enabled;

    if (enabled) {
      _privacyScreenEnabled = true;
      try {
        await PrivacyScreen.instance.enable();
      } catch (e) {
        Log.w(_tag, 'Error enabling privacy screen: $e');
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      bool storedPrivacy = prefs.getBool(_privacyScreenEnabledKey) ?? false;
      _privacyScreenEnabled = storedPrivacy;
      if (_privacyScreenEnabled) {
        try {
          await PrivacyScreen.instance.enable();
        } catch (e) {
          Log.w(_tag, 'Error enabling privacy screen: $e');
        }
      } else {
        try {
          await PrivacyScreen.instance.disable();
        } catch (e) {
          Log.w(_tag, 'Error disabling privacy screen: $e');
        }
      }
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    Log.i(_tag, 'Biometric enabled state saved: $enabled');
  }

  Future<void> setPrivacyScreenEnabled(bool enabled) async {
    if (_biometricEnabled && !enabled) {
      return;
    }

    _privacyScreenEnabled = enabled;
    if (enabled) {
      try {
        await PrivacyScreen.instance.enable();
      } catch (e) {
        Log.w(_tag, 'Error enabling privacy screen: $e');
      }
    } else {
      try {
        await PrivacyScreen.instance.disable();
      } catch (e) {
        Log.w(_tag, 'Error disabling privacy screen: $e');
      }
    }
    
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyScreenEnabledKey, enabled);
  }

  Future<void> setLockDelayOption(LockDelayOption option) async {
    _lockDelayOption = option;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lockDelayOptionKey, option.index);
  }

  Future<void> setCustomLockDelay(int minutes) async {
    _customLockDelayMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customLockDelayKey, minutes);
  }

  void setAppPaused() {
    if (!_biometricEnabled) return;
    _lastPausedTime = DateTime.now();
  }

  void setAppResumed() {
    if (!_biometricEnabled) return;
    if (_lastPausedTime == null) return;

    final now = DateTime.now();
    final difference = now.difference(_lastPausedTime!);
    
    int delayMinutes = 0;
    switch (_lockDelayOption) {
      case LockDelayOption.immediate:
        delayMinutes = 0;
        break;
      case LockDelayOption.oneMinute:
        delayMinutes = 1;
        break;
      case LockDelayOption.threeMinutes:
        delayMinutes = 3;
        break;
      case LockDelayOption.fiveMinutes:
        delayMinutes = 5;
        break;
      case LockDelayOption.tenMinutes:
        delayMinutes = 10;
        break;
      case LockDelayOption.thirtyMinutes:
        delayMinutes = 30;
        break;
      case LockDelayOption.custom:
        delayMinutes = _customLockDelayMinutes;
        break;
    }

    if (_lockDelayOption == LockDelayOption.immediate || difference.inMinutes >= delayMinutes) {
      _isLocked = true;
      notifyListeners();
    }
    
    _lastPausedTime = null;
  }

  Future<void> authenticate() async {
    if (_isAuthenticating) return;
    
    _isAuthenticating = true;
    try {
      await _auth.stopAuthentication();
      
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: '请验证身份以解锁应用',
        biometricOnly: true,
      );
      if (didAuthenticate) {
        _isLocked = false;
        notifyListeners();
      }
    } catch (e) {
      Log.w(_tag, 'Unlock authentication error: $e');
    } finally {
      _isAuthenticating = false;
    }
  }
  
  Future<void> resetToDefaults() async {
    _biometricEnabled = false;
    _lockDelayOption = LockDelayOption.immediate;
    _customLockDelayMinutes = 0;
    _privacyScreenEnabled = false;
    _isLocked = false;
    
    try {
      await PrivacyScreen.instance.disable();
    } catch (e) {
      Log.w(_tag, 'Error disabling privacy screen: $e');
    }
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_lockDelayOptionKey);
    await prefs.remove(_customLockDelayKey);
    await prefs.remove(_privacyScreenEnabledKey);
  }
}
