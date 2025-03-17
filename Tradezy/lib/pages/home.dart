import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Tradezy/pages/money.dart';
import 'package:Tradezy/pages/com.dart';
import 'package:Tradezy/pages/trad.dart';
import 'package:Tradezy/pages/profile.dart';
import 'package:Tradezy/pages/news.dart';
import 'package:Tradezy/pages/notes.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final supabase = Supabase.instance.client;
  String userName = "User";
  String userGender = "male";
  double? _totalMoney;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasNotes = false;

  final List<Map<String, String>> images = [
    {"url": "images/2.PNG", "link": "/"},
    {"url": "images/4.png", "link": "/"},
    {"url": "images/5.PNG", "link": "/"},
  ];

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
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
    fetchNotesStatus();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch user data')),
      );
    }
  }

  Future<void> fetchTotalMoney() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to fetch money data.');
      }

      final incomeResponse = await supabase
          .from('incomes')
          .select('amount')
          .eq('user_id', user.id);
      final incomes = (incomeResponse as List<dynamic>)
          .map((item) => (item['amount'] as num).toDouble())
          .toList();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
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

  String _getDailyMotivation() {
    final List<String> motivations = [
      "Keep pushing forward!",
      "You are stronger than you think.",
      "Every day is a new opportunity.",
      "Believe in yourself and all that you are.",
      "Success is built one step at a time.",
    ];
    final random = DateTime.now().day % motivations.length;
    return motivations[random];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, screenWidth),
                const SizedBox(height: 16),
                _buildWelcomeText(),
                const SizedBox(height: 16),
                _buildCarousel(screenWidth, screenHeight),
                const SizedBox(height: 24),
                _buildConditionBoxes(context),
                const SizedBox(height: 24),
                _buildDailyMotivationSection(),
              ],
            ),
          ),
        ),
      ),

    );
  }

  Widget _buildHeader(BuildContext context, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              "images/wave.png",
              width: screenWidth * 0.1,
              height: screenWidth * 0.1,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, color: Colors.red);
              },
            ),
            const SizedBox(width: 10),
            Text(
              "Hello, $userName",
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        GestureDetector(
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
                userGender.toLowerCase() == "female"
                    ? "images/female.png"
                    : "images/male.png",
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person, color: Colors.blueAccent);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildCarousel(double screenWidth, double screenHeight) {
    return Center(
      child: CarouselSlider(
        items: images.map((image) {
          return GestureDetector(
            onTap: () => _launchURL(image["link"]!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.asset(
                image["url"]!,
                fit: BoxFit.contain,
                width: screenWidth * 0.9,
                height: screenHeight * 0.25,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        "Unable to load image",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
        options: CarouselOptions(
          height: screenHeight * 0.25,
          autoPlay: true,
          enlargeCenterPage: true,
          viewportFraction: 0.9,
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
        ),
      ),
    );
  }

  Widget _buildConditionBoxes(BuildContext context) {
    return Column(
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
        const SizedBox(height: 16),
        _buildConditionBox(
          "News",
          "View Latest Updates",
          Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Newspage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildConditionBox(
          "Notes",
          _getNotesCondition(),
          Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotesPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildConditionBox(String title, String condition, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Flexible(
              child: Text(
                condition,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: condition.contains("Above") || condition.contains("Available")
                      ? Colors.green
                      : condition.contains("Below") || condition.contains("No")
                          ? Colors.red
                          : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMotivationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daily Motivation",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getDailyMotivation(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}