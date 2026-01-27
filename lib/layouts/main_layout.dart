import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/layouts/desktop_layout.dart';
import 'package:utopia_music/layouts/mobile_layout.dart';
import 'package:utopia_music/pages/main/discover/discover_page.dart';
import 'package:utopia_music/pages/main/library/library_page.dart';
import 'package:utopia_music/pages/main/settings/settings_page.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/update_util.dart';

const String _tag = "MAIN_LAYOUT";

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
    Log.v(_tag, "initState");
    super.initState();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _pages = [
      DiscoverPage(key: _discoverPageKey, onSongSelected: playerProvider.playSong),
      const MusicPage(),
      const SettingsPage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Log.v(_tag, "PostFrameCallback");
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      if (!settingsProvider.isSettingsLoaded) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (mounted) {
        UpdateUtil.checkAndShow(context, isManualCheck: false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    Log.v(_tag, "didChangeDependencies");
    super.didChangeDependencies();
    if (!_isInit) {
      final settingsProvider = Provider.of<SettingsProvider>(context);
      if (settingsProvider.isSettingsLoaded) {
        int startIndex = settingsProvider.startPageIndex;
        if (startIndex < 0 || startIndex >= _pages.length) {
          startIndex = 0;
        }
        _selectedIndex = startIndex;
        _isInit = true;
      }
    }
  }

  void _onItemTapped(int index) {
    Log.v(_tag, "_onItemTapped");
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
    Log.v(_tag, "build");
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
