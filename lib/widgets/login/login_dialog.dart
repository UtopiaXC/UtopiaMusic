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

class _LoginDialogState extends State<LoginDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _cookieController = TextEditingController();

  String? _qrUrl;
  String? _authCode;
  bool _isLoading = true;
  bool _isExpired = false;
  bool _isScanned = false;
  bool _isSuccess = false;
  Timer? _pollTimer;
  final LoginApi _loginApi = LoginApi();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _loadQrCode();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _tabController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadQrCode() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isExpired = false;
      _isScanned = false;
      _isSuccess = false;
    });

    try {
      final data = await _loginApi.generateTvQrCode();
      if (data != null && mounted) {
        setState(() {
          _qrUrl = data['url'];
          _authCode = data['auth_code'];
          _isLoading = false;
        });
        _startPolling();
      } else {
        if (mounted)
          setState(() {
            _isLoading = false;
            _isExpired = true;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _isExpired = true;
        });
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isSuccess || _authCode == null || !mounted) {
        timer.cancel();
        return;
      }

      final result = await _loginApi.pollTvQrCode(_authCode!);
      if (_isSuccess || !mounted) return;

      if (result != null) {
        final code = result['code'];
        if (code == 0) {
          _isSuccess = true;
          _stopPolling();
          if (mounted) {
            await Provider.of<AuthProvider>(
              context,
              listen: false,
            ).login(type: 'qr');
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('登录成功')));
            }
          }
        } else if (code == 86038) {
          _stopPolling();
          setState(() => _isExpired = true);
        } else if (code == 86090) {
          if (!_isScanned) setState(() => _isScanned = true);
        }
      }
    });
  }

  Future<void> _handleManualLogin() async {
    final cookieString = _cookieController.text.trim();
    if (cookieString.isEmpty) return;
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).saveCookies(cookieString);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录成功')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登录失败: $e')));
    }
  }

  Future<void> _handleLogout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    _loadQrCode();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoggedIn) {
      return _buildLoggedInView(authProvider);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 48), // Space for close button
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '扫码登录'),
                    Tab(text: 'Cookie 登录'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildQrLoginView(), _buildCookieLoginView()],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '取消',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView(AuthProvider auth) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 250),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (auth.userInfo?.avatarUrl != null)
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: NetworkImage(auth.userInfo!.avatarUrl),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '欢迎回来，${auth.userInfo?.name ?? "用户"}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('当前已登录，请尽情使用', style: TextStyle(color: Colors.grey)),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('退出登录'),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '关闭',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrLoginView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoading)
          const CircularProgressIndicator()
        else if (_isExpired)
          Column(
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('二维码已失效'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadQrCode, child: const Text('刷新')),
            ],
          )
        else if (_qrUrl != null)
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: _qrUrl!,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              if (_isScanned)
                const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(height: 8),
                    Text(
                      '扫描成功，请在手机上确认登录',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else
                const Text('请使用 哔哩哔哩客户端 扫码登录'),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadQrCode, child: const Text('刷新二维码')),
            ],
          ),
      ],
    );
  }

  Widget _buildCookieLoginView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '手动输入 Cookie',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '请从浏览器中复制完整的 Cookie 字符串粘贴到下方。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _cookieController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'DedeUserID=...; SESSDATA=...; ...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleManualLogin,
            child: const Text('确认登录'),
          ),
        ],
      ),
    );
  }
}
