import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:utopia_music/generated/l10n.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SecurityProvider>(context, listen: false).authenticate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64),
            const SizedBox(height: 16),
            Text(
              S.of(context).pages_lock_screen_locked,
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Provider.of<SecurityProvider>(
                  context,
                  listen: false,
                ).authenticate();
              },
              child: Text(S.of(context).pages_lock_screen_unlock),
            ),
          ],
        ),
      ),
    );
  }
}
