import 'package:flutter/material.dart';
import 'package:Tradezy/pages/news.dart';
import 'package:Tradezy/pages/notes.dart'; 
import 'package:Tradezy/pages/feed.dart'; 
import 'package:Tradezy/pages/news.dart';

class EduNavPage extends StatefulWidget {
  const EduNavPage({super.key});

  @override
  _EduNavPageState createState() => _EduNavPageState();
}

class _EduNavPageState extends State<EduNavPage> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [const Feed(), const NotesPage(),const Newspage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Trader Community', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Traders chat'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
        ],
      ),
    );
  }
}