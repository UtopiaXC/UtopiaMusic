import 'package:flutter/material.dart';

class NetworkSettingsPage extends StatelessWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络')),
      body: const Center(child: Text('网络设置')),
    );
  }
}
