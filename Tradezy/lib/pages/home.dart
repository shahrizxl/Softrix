import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Tradezy/pages/money.dart';
import 'package:Tradezy/pages/com.dart';
import 'package:Tradezy/pages/trad.dart';
import 'package:Tradezy/pages/profile.dart';
import 'package:Tradezy/pages/news.dart'; // Import Newspage
import 'package:Tradezy/pages/notes.dart'; // Import Newspage



class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final supabase = Supabase.instance.client;
  String userName = "User"; // Default value
  String userGender = "male";
  double? _totalMoney; // Income - Expenses
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasNotes = false; // To track if the user has notes

  final List<Map<String, String>> images = [
    {"url": "images/barcamp.png", "link": "https://www.instagram.com/barcamp_cyberjaya/"},
    {"url": "images/umhack.jpeg", "link": "https://www.instagram.com/umhackathon/"},
    {"url": "images/usmhack.jpeg", "link": "https://www.instagram.com/vhack.usm/"},
  ];

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _handleLogout() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchTotalMoney();
    fetchNotesStatus(); // Fetch notes status on init
  }

  Future<void> fetchUserName() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('profiles')
          .select('name,gender')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          userName = data['name'] ?? "User";
          userGender = data['gender'] ?? "male";
        });
      }
    } catch (e) {
    }
  }

  Future<void> fetchTotalMoney() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to fetch money data.');
      }

      // Fetch total income from 'incomes' table
      final incomeResponse = await supabase
          .from('incomes')
          .select('amount')
          .eq('user_id', user.id);
      final incomes = (incomeResponse as List<dynamic>)
          .map((item) => (item['amount'] as num).toDouble())
          .toList();

      // Fetch transactions (Income and Expense)
      final transactionResponse = await supabase
          .from('transactions')
          .select('amount, type')
          .eq('user_id', user.id);
      final transactions = transactionResponse;

      double totalIncome = incomes.fold(0, (sum, amount) => sum + amount);
      double transactionIncome = transactions
          .where((t) => t['type'] == 'Income')
          .fold(0, (sum, t) => sum + (t['amount'] as num).toDouble());
      double totalExpense = transactions
          .where((t) => t['type'] == 'Expense')
          .fold(0, (sum, t) => sum + (t['amount'] as num).toDouble());

      setState(() {
        _totalMoney = (totalIncome + transactionIncome) - totalExpense;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch money data: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> fetchNotesStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to fetch notes data.');
      }

      final response = await supabase
          .from('notes')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      setState(() {
        _hasNotes = (response as List).isNotEmpty;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch notes status: $error';
      });
    }
  }

  String _getMoneyCondition() {
    if (_totalMoney == null) return "Loading...";
    return _totalMoney! > 100 ? "Above RM 100" : "Below RM 100";
  }


  String _getNotesCondition() {
    if (_isLoading) return "Loading...";
    return _hasNotes ? "Notes Available" : "No Notes";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        margin: const EdgeInsets.only(top: 30, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  "images/wave.png",
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 10),
                Text(
                  "Hello, $userName",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      _handleLogout();
                    } else if (value == 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Profile()),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Profile()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2.0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          userGender.toLowerCase() == "female" ? "images/female.png" : "images/male.png",
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Welcome to,",
              style: TextStyle(
                color: Color.fromARGB(186, 255, 255, 255),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Text(
                  "Trad",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "ezy",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: CarouselSlider(
                items: images.map((image) {
                  return GestureDetector(
                    onTap: () => _launchURL(image["link"]!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.asset(
                        image["url"]!,
                        fit: BoxFit.contain,
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: 220,
                      ),
                    ),
                  );
                }).toList(),
                options: CarouselOptions(
                  height: 140,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.85,
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Three vertical boxes for Money, News, Notes
            Expanded(
              child: Column(
                children: [
                  _buildConditionBox(
                    "Money",
                    _getMoneyCondition(),
                    Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomeScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildConditionBox(
                    "News",
                    "View Latest Updates",
                    Colors.orangeAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Newspage()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildConditionBox(
                    "Notes",
                    _getNotesCondition(),
                    Colors.purpleAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotesPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionBox(String title, String condition, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              condition,
              style: TextStyle(
                color: condition.contains("Above")||condition.contains("Available") ? Colors.green : condition.contains("Below") ||condition.contains("No")? Colors.red : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}