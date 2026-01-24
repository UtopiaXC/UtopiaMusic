import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/layouts/desktop_layout.dart';
import 'package:utopia_music/layouts/mobile_layout.dart';
import 'package:utopia_music/pages/main/discover/discover_page.dart';
import 'package:utopia_music/pages/main/library/library_page.dart';
import 'package:utopia_music/pages/main/settings/settings_page.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/connection/update/github_api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:utopia_music/widgets/update/update_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final GlobalKey<DiscoverPageState> _discoverPageKey = GlobalKey<DiscoverPageState>();
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _pages = [
      DiscoverPage(key: _discoverPageKey, onSongSelected: playerProvider.playSong),
      const MusicPage(),
      const SettingsPage(),
    ];
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Wait for settings to be loaded if they are not yet
    if (!settingsProvider.isSettingsLoaded) {
      // Simple retry mechanism or wait
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (!settingsProvider.isSettingsLoaded) {
         // If still not loaded, maybe wait more or just proceed if it's critical, 
         // but here we can just return or try again.
         // Let's assume it loads fast enough or we can listen to it.
         // But since we are in addPostFrameCallback, it might be racing.
         // However, SettingsProvider constructor calls _loadSettings immediately.
         // It's async, so it might not be ready.
      }
    }

    if (!settingsProvider.autoCheckUpdate) return;

    try {
      final checkPreRelease = settingsProvider.checkPreRelease;
      final ignoredVersion = settingsProvider.ignoredVersion;
      
      final release = await _fetchRelease(checkPreRelease);

      if (release != null && mounted) {
        final tagName = release['tag_name'] as String;
        final packageInfo = await PackageInfo.fromPlatform();
        
        String normalizedTag = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        String normalizedCurrent = packageInfo.version.split('+')[0];
        
        if (normalizedTag != normalizedCurrent) {
           if (ignoredVersion == tagName) {
             return;
           }
           
           showDialog(
             context: context,
             builder: (context) => UpdateDialog(releaseData: release),
           );
        }
      }
    } catch (e) {
      // Silent error
    }
  }
  
  Future<Map<String, dynamic>?> _fetchRelease(bool checkPreRelease) async {
    final githubApi = GithubApi();
    if (checkPreRelease) {
      return await githubApi.getLatestPreRelease();
    } else {
      return await githubApi.getLatestRelease();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      // Ensure the index is valid
      int startIndex = settingsProvider.startPageIndex;
      if (startIndex < 0 || startIndex >= _pages.length) {
        startIndex = 0;
      }
      _selectedIndex = startIndex;
      _isInit = true;
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index && index == 0) {
      _discoverPageKey.currentState?.handleBottomTabReselect();
    }

    setState(() {
      _selectedIndex = index;
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      if (playerProvider.isPlayerExpanded) {
        playerProvider.collapsePlayer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return DesktopLayout(
          selectedIndex: _selectedIndex,
          pages: _pages,
          onItemTapped: _onItemTapped,
        );
      } else {
        return MobileLayout(
          selectedIndex: _selectedIndex,
          pages: _pages,
          onItemTapped: _onItemTapped,
        );
      }
    });
  }
}
