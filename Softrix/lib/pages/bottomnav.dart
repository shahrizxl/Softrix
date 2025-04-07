import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:Tradezy/pages/home.dart';
import 'package:Tradezy/pages/ai.dart';
import 'package:Tradezy/pages/com.dart';
import 'package:Tradezy/pages/trad.dart';
import 'package:Tradezy/pages/money.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _currentIndex = 0;

  final List<Widget> pages = [
    const Home(),
    FinanceApp(),
    const LearnPage(),
    const EduNavPage(),
    const Ai(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        color: Colors.blueAccent,
        animationDuration: const Duration(milliseconds: 500),
        items: const [
          Icon(Icons.home, size: 30),
          Icon(Icons.money, size: 30),
          Icon(Icons.school, size: 30),
          Icon(Icons.chat, size: 30),
          Icon(Icons.android, size: 30),

        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
