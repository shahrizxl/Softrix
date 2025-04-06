import 'package:flutter/material.dart';
import 'package:Tradezy/pages/news.dart';
import 'package:Tradezy/pages/notes.dart';
import 'package:Tradezy/pages/feed.dart';

class EduNavPage extends StatefulWidget {
  const EduNavPage({super.key});

  @override
  _EduNavPageState createState() => _EduNavPageState();
}

class _EduNavPageState extends State<EduNavPage> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [const Feed(), const NotesPage(), const Newspage()];

  // Page titles for the app bar
  final List<String> _titles = ['Traders Community', 'Trading Notes', 'Financial News'];

  // Icons for the navigation bar
  final List<IconData> _activeIcons = [
    Icons.forum_rounded,
    Icons.note_rounded,
    Icons.newspaper_rounded
  ];

  final List<IconData> _inactiveIcons = [
    Icons.forum_outlined,
    Icons.note_outlined,
    Icons.newspaper_outlined
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Financial Community',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),

      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF007BFF),
            unselectedItemColor: Colors.grey[400],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
            ),
            elevation: 20,
            type: BottomNavigationBarType.fixed,
            items: List.generate(
              _titles.length,
                  (index) => BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Icon(
                    _selectedIndex == index ? _activeIcons[index] : _inactiveIcons[index],
                    size: _selectedIndex == index ? 26 : 22,
                  ),
                ),
                label: _selectedIndex == index
                    ? _titles[index].split(' ')[0]
                    : _titles[index].split(' ')[0],
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: () {
          // Action for creating a new post or starting a new chat
        },
        backgroundColor: const Color(0xFF007BFF),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }
}

