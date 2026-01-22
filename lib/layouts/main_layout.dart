import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/layouts/desktop_layout.dart';
import 'package:utopia_music/layouts/mobile_layout.dart';
import 'package:utopia_music/pages/main/home/home_page.dart';
import 'package:utopia_music/pages/main/library_page.dart';
import 'package:utopia_music/pages/main/settings/settings_page.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _pages = [
      HomePage(key: _homePageKey, onSongSelected: playerProvider.playSong),
      const MusicPage(),
      const SettingsPage(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final settingsProvider = Provider.of<SettingsProvider>(context);
      if (settingsProvider.isLoaded) {
        int startIndex = settingsProvider.startPageIndex;
        if (startIndex < 0 || startIndex >= _pages.length) {
          startIndex = 0;
        }
        _selectedIndex = startIndex;
        _isInit = true;
        // Force rebuild to show correct page
        setState(() {});
      }
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index && index == 0) {
      _homePageKey.currentState?.handleBottomTabReselect();
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
    // If settings are not loaded yet, we might want to show a loading screen or just default to home
    // But since SettingsProvider loads async, we rely on the listener in didChangeDependencies

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
