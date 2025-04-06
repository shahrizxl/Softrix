
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
const Home({Key? key}) : super(key: key);

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
backgroundColor: Colors.white,
body: SafeArea(
child: SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Removed the top gradient
Padding(
padding: const EdgeInsets.symmetric(horizontal: 20.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 20),
_buildHeader(context, screenWidth),
const SizedBox(height: 24),
_buildWelcomeText(),
const SizedBox(height: 24),
_buildCarousel(screenWidth, screenHeight),
const SizedBox(height: 30),
_buildQuickActions(context),
const SizedBox(height: 30),
_buildConditionBoxes(context),
const SizedBox(height: 30),
_buildDailyMotivationSection(),
const SizedBox(height: 30),
],
),
),
],
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
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(15),
boxShadow: [
BoxShadow(
color: Colors.grey.withOpacity(0.2),
spreadRadius: 2,
blurRadius: 5,
offset: const Offset(0, 3),
),
],
),
child: Image.asset(
"images/wave.png",
width: screenWidth * 0.08,
height: screenWidth * 0.08,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) {
return const Icon(Icons.waving_hand, color: Color(0xFF42a5f5)); // Lighter blue
},
),
),
const SizedBox(width: 15),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
"Hello,",
style: TextStyle(
color: Colors.grey[600],
fontSize: 14,
fontWeight: FontWeight.w500,
),
),
Text(
userName,
style: TextStyle(
color: Colors.grey[900],
fontSize: screenWidth * 0.05,
fontWeight: FontWeight.bold,
),
),
],
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
padding: const EdgeInsets.all(3),
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: const LinearGradient(
colors: [Color(0xFF42a5f5), Color(0xFF1976d2)], // Lighter and darker blue
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
boxShadow: [
BoxShadow(
color: const Color(0xFF42a5f5).withOpacity(0.3), // Lighter blue
spreadRadius: 1,
blurRadius: 4,
offset: const Offset(0, 2),
),
],
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
return Container(
width: screenWidth * 0.12, // Width: 12% of screen width
height: screenWidth * 0.12, // Height: 12% of screen width
color: Colors.white,
child: const Icon(Icons.person, color: Color(0xFF42a5f5)), // Lighter blue
);
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
Text(
"Welcome to SofTrix",
style: TextStyle(
color: Colors.grey[900],
fontSize: 32,
fontWeight: FontWeight.bold,
),
),
],
);
}

Widget _buildCarousel(double screenWidth, double screenHeight) {
return Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.grey.withOpacity(0.2),
spreadRadius: 2,
blurRadius: 10,
offset: const Offset(0, 5),
),
],
),
child: CarouselSlider(
items: images.map((image) {
return GestureDetector(
onTap: () => _launchURL(image["link"]!),
child: Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.grey.withOpacity(0.3),
spreadRadius: 1,
blurRadius: 5,
offset: const Offset(0, 3),
),
],
),
child: ClipRRect(
borderRadius: BorderRadius.circular(16),
child: Image.asset(
image["url"]!,
fit: BoxFit.cover,
width: screenWidth,
errorBuilder: (context, error, stackTrace) {
return Container(
decoration: BoxDecoration(
color: Colors.grey[200],
borderRadius: BorderRadius.circular(16),
),
width: screenWidth, // Width: screen width
height: screenHeight * 0.2, // Height: 20% of screen height
child: const Center(
child: Icon(
Icons.image_not_supported,
color: Colors.grey,
size: 40,
),
),
);
},
),
),
),
);
}).toList(),
options: CarouselOptions(
height: screenHeight * 0.2, // Height: 20% of screen height
autoPlay: true,
enlargeCenterPage: true,
viewportFraction: 0.9,
autoPlayAnimationDuration: const Duration(milliseconds: 800),
autoPlayCurve: Curves.fastOutSlowIn,
),
),
);
}

Widget _buildQuickActions(BuildContext context) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"Quick Actions",
style: TextStyle(
color: Color(0xFF2D3436),
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 16),
Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: [
_buildActionItem(
icon: Icons.account_balance_wallet,
label: "Money",
color: const Color(0xFF42a5f5), // Lighter blue
onTap: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => HomeScreen()),
);
},
),
_buildActionItem(
icon: Icons.newspaper,
label: "News",
color: const Color(0xFF00B894),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => const Newspage()),
);
},
),
_buildActionItem(
icon: Icons.note_alt,
label: "Notes",
color: const Color(0xFFFF7675),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => const NotesPage()),
);
},
),
_buildActionItem(
icon: Icons.person,
label: "Profile",
color: const Color(0xFFFDAA5E),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => const Profile()),
);
},
),
],
),
],
);
}

Widget _buildActionItem({
required IconData icon,
required String label,
required Color color,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap: onTap,
child: Column(
children: [
Container(
width: 60, // Width: 60px
height: 60, // Height: 60px
decoration: BoxDecoration(
color: color.withOpacity(0.1),
borderRadius: BorderRadius.circular(16),
),
child: Icon(
icon,
color: color,
size: 30,
),
),
const SizedBox(height: 8),
Text(
label,
style: TextStyle(
color: Colors.grey[800],
fontSize: 12,
fontWeight: FontWeight.w500,
),
),
],
),
);
}

Widget _buildConditionBoxes(BuildContext context) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"Financial Status",
style: TextStyle(
color: Color(0xFF2D3436),
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 16),
_buildConditionBox(
"Money",
_getMoneyCondition(),
const Color(0xFF42a5f5), // Lighter blue
Icons.account_balance_wallet,
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
const Color(0xFF00B894),
Icons.newspaper,
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
const Color(0xFFFF7675),
Icons.note_alt,
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

Widget _buildConditionBox(
String title,
String condition,
Color color,
IconData icon, {
VoidCallback? onTap,
}) {
return GestureDetector(
onTap: onTap,
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: color.withOpacity(0.1),
spreadRadius: 1,
blurRadius: 10,
offset: const Offset(0, 4),
),
],
border: Border.all(color: color.withOpacity(0.3), width: 1),
),
child: Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: color.withOpacity(0.1),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
icon,
color: color,
size: 24,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
color: Colors.grey[800],
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 4),
Text(
condition,
style: TextStyle(
color: condition.contains("Above") || condition.contains("Available")
? Colors.green[600]
    : condition.contains("Below") || condition.contains("No")
? Colors.red[600]
    : Colors.grey[600],
fontSize: 14,
fontWeight: FontWeight.w500,
),
),
],
),
),
Icon(
Icons.arrow_forward_ios,
color: Colors.grey[400],
size: 16,
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
gradient: const LinearGradient(
colors: [Color(0xFF42a5f5), Color(0xFF1976d2)], // Lighter and darker blue
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: const Color(0xFF42a5f5).withOpacity(0.3), // Lighter blue
spreadRadius: 1,
blurRadius: 10,
offset: const Offset(0, 4),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
borderRadius: BorderRadius.circular(12),
),
child: const Icon(
Icons.lightbulb,
color: Colors.white,
size: 24,
),
),
const SizedBox(width: 12),
const Text(
"Daily Motivation",
style: TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
],
),
const SizedBox(height: 16),
Text(
_getDailyMotivation(),
style: const TextStyle(
color: Colors.white,
fontSize: 16,
fontWeight: FontWeight.w500,
height: 1.5,
),
),
const SizedBox(height: 16),
Container(
padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(24),
),
child: const Text(
"Get Inspired",
style: TextStyle(
color: Color(0xFF42a5f5), // Lighter blue
fontSize: 14,
fontWeight: FontWeight.bold,
),
),
),
],
),
);
}
}