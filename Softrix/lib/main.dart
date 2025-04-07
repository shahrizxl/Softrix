import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:Tradezy/pages/consts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Tradezy/auth/login_page.dart';
import 'package:Tradezy/auth/signup_page.dart';
import 'package:Tradezy/pages/bottomnav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Gemini.init(apiKey:GEMINI_API_KEY);
  await Supabase.initialize(
    url: 'https://opgovzqatyktfntubhey.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZ292enFhdHlrdGZudHViaGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1ODk5NjksImV4cCI6MjA1NzE2NTk2OX0.wgdDx-AIQMqHWZMUmXMDEhNzl3Bl-F6w5V5TuQRUGHo',
  );
  
  runApp(MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Supabase Auth',
      initialRoute : '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/home': (context) => BottomNav(),
      },
    );
  }
}