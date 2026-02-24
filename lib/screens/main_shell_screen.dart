import 'dart:ui';

import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'hebrew_basics_screen.dart';
import 'prayer_list_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school_rounded),
      label: 'Learn',
    ),
    NavigationDestination(
      icon: Icon(Icons.info_outline_rounded),
      selectedIcon: Icon(Icons.info_rounded),
      label: 'About',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          PrayerListScreen(),
          HebrewBasicsScreen(),
          AboutScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.85),
                  child: NavigationBar(
                    elevation: 8,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() => _selectedIndex = index);
                    },
                    destinations: _destinations,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
