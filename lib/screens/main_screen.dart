import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'map/map_screen.dart';
import 'conversion/conversion_screen.dart';
import 'profile/profile_screen.dart';
import 'planner/planner_screen.dart';

/// Layar utama dengan bottom navigation untuk navigasi antar fitur.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    MapScreen(),
    ConversionScreen(),
    PlannerScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Beranda'),
              BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Peta'),
              BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), activeIcon: Icon(Icons.calculate), label: 'Konversi'),
              BottomNavigationBarItem(icon: Icon(Icons.alarm_add_outlined), activeIcon: Icon(Icons.alarm), label: 'Perencana'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF0077B6),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            onTap: (index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }
}
