import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:utopia_music/connection/user/login.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/widgets/login/web_login_page.dart';

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
  bool get _isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isMobile ? 3 : 2, vsync: this);
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
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isExpired = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isExpired = true;
        });
      }
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.of(context).common_succeed)),
              );
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
        ).showSnackBar(SnackBar(content: Text(S.of(context).common_succeed)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).common_failed}: $e')),
      );
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
                const SizedBox(height: 48),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    labelColor: Theme.of(context).colorScheme.onPrimary,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    tabs: [
                      if (_isMobile)
                        Tab(text: S.of(context).weight_login_web_login),
                      Tab(text: S.of(context).weight_login_scan_qr),
                      Tab(text: S.of(context).weight_login_cookie),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      if (_isMobile) _buildWebLoginView(),
                      _buildQrLoginView(),
                      _buildCookieLoginView(),
                    ],
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
                tooltip: S.of(context).common_cancel,
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
                    '${S.of(context).weight_login_welcome_back} ${auth.userInfo?.name ?? S.of(context).pages_search_tag_user}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.of(context).weight_login_over,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: Text(S.of(context).weight_login_logout),
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
                tooltip: S.of(context).common_close,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLoginView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.language, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            S.of(context).weight_login_web_login_hint,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => const WebLoginPage(),
                ),
              );
              if (result == true && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.login),
            label: Text(S.of(context).weight_login_web_login_button),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
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
              Text(S.of(context).weight_login_qr_expired),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadQrCode,
                child: Text(S.of(context).common_refresh),
              ),
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
                Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(height: 8),
                    Text(
                      S.of(context).weight_login_scan_confirm,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else
                Text(S.of(context).weight_login_screenshoot_to_qr_hint),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadQrCode,
                child: Text(S.of(context).weight_login_refresh_qr),
              ),
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
          Text(
            S.of(context).weight_login_cookie_tips,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).weight_login_cookie_hint,
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
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }
}
