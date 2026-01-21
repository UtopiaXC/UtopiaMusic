import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/layouts/desktop_layout.dart';
import 'package:utopia_music/layouts/mobile_layout.dart';
import 'package:utopia_music/pages/home_page.dart';
import 'package:utopia_music/pages/music_page.dart';
import 'package:utopia_music/pages/settings_page.dart';
import 'package:utopia_music/providers/player_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();

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