import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:utopia_music/connection/user/login.dart';
import 'package:utopia_music/providers/auth_provider.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  String? _qrCodeUrl;
  String? _qrCodeKey;
  Timer? _pollTimer;
  bool _isScanned = false;
  bool _isExpired = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showManualInput = false;
  final TextEditingController _cookieController = TextEditingController();
  Map<String, String>? _parsedCookies;
  final LoginApi _loginApi = LoginApi();

  @override
  void initState() {
    super.initState();
    _generateQrCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _generateQrCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isExpired = false;
      _isScanned = false;
    });

    final data = await _loginApi.generateQrCode();
    
    if (data != null) {
      final url = data['url'];
      final key = data['qrcode_key'];
      
      if (mounted) {
        setState(() {
          _qrCodeUrl = url;
          _qrCodeKey = key;
          _isLoading = false;
        });
        _startPolling();
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = '获取二维码失败';
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_qrCodeKey == null) return;

      final result = await _loginApi.pollQrCode(_qrCodeKey!);

      if (result != null) {
        final code = result['code'];
        
        if (code == 0) {
          timer.cancel();
          final cookieString = result['cookie'];
          
          if (cookieString != null) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
              
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.saveCookies(cookieString);
              
              if (authProvider.isLoggedIn) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('登录成功')),
                  );
                }
              } else {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = '登录验证失败，请刷新二维码重试';
                  });
                  _showLoginFailedDialog();
                  _generateQrCode();
                }
              }
            }
          } else {
             if (mounted) {
               setState(() {
                 _errorMessage = '登录成功但无法获取Cookie，请尝试手动输入';
               });
             }
          }
        } else if (code == 86090) {
          if (mounted) {
            setState(() {
              _isScanned = true;
            });
          }
        } else if (code == 86038) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isExpired = true;
            });
          }
        }
      }
    });
  }
  
  void _showLoginFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登录失败'),
        content: const Text('Cookie验证失败，请尝试重新扫码登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _handleManualInput() {
    setState(() {
      _showManualInput = true;
      _pollTimer?.cancel();
    });
  }

  void _parseCookies() {
    final text = _cookieController.text;
    final cookies = <String, String>{};
    
    final parts = text.split(';');
    for (var part in parts) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        cookies[kv[0]] = kv[1];
      }
    }

    final requiredKeys = ['DedeUserID', 'DedeUserID__ckMd5', 'SESSDATA', 'bili_jct'];
    bool hasAll = true;
    for (var key in requiredKeys) {
      if (!cookies.containsKey(key)) {
        hasAll = false;
        break;
      }
    }

    if (hasAll) {
      setState(() {
        _parsedCookies = cookies;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Cookie格式不正确，缺少必要字段';
      });
    }
  }

  Future<void> _verifyAndSaveCookies() async {
    if (_parsedCookies == null) return;

    setState(() {
      _isLoading = true;
    });

    final cookieString = _parsedCookies!.entries.map((e) => '${e.key}=${e.value}').join('; ');
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.saveCookies(cookieString);
    
    if (authProvider.isLoggedIn) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Cookie无效，请检查后重试';
        });
        _showLoginFailedDialog();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Do nothing, force user to use buttons
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '登录 Bilibili',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '请通过手机Bilibili进行扫码',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (_showManualInput)
                _buildManualInput()
              else
                _buildQrCodeView(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('取消'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodeView() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_qrCodeUrl != null)
                QrImageView(
                  data: _qrCodeUrl!,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              
              if (_isScanned)
                Container(
                  color: Colors.white.withValues(alpha: 0.9),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text('已扫描\n请在手机上确认', textAlign: TextAlign.center),
                    ],
                  ),
                ),

              if (_isExpired)
                Container(
                  color: Colors.white.withValues(alpha: 0.9),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      const Text('二维码已失效', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _generateQrCode,
                        child: const Text('刷新'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _generateQrCode,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新二维码'),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: _handleManualInput,
              icon: const Icon(Icons.edit),
              label: const Text('手动输入Cookie'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    if (_parsedCookies != null) {
      return Column(
        children: [
          const Text('确认Cookie信息'),
          const SizedBox(height: 16),
          ..._parsedCookies!.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(e.value, overflow: TextOverflow.ellipsis)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            FilledButton(
              onPressed: _verifyAndSaveCookies,
              child: const Text('验证并登录'),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                _parsedCookies = null;
              });
            },
            child: const Text('重新输入'),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextField(
          controller: _cookieController,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '请粘贴完整的Cookie字符串',
            labelText: 'Cookie',
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _parseCookies,
          child: const Text('解析'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _showManualInput = false;
              _generateQrCode();
            });
          },
          child: const Text('返回扫码登录'),
        ),
      ],
    );
  }
}
