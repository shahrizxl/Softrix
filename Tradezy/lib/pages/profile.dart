import 'package:flutter/material.dart';
import 'package:Tradezy/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Tradezy/pages/bottomnav.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  late User? _user;
  Map<String, dynamic>? _userData;

  final List<String> _institutionOptions = [
    'Beginner Trader',
    'Amateur Trader',
    'Advanced trader',
    'Pro trader',
  ];

  final List<String> _genderOptions = [
    'Male',
    'Female'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _user = supabase.auth.currentUser;
    if (_user != null) {
      final response = await supabase.from('profiles').select().eq('id', _user!.id).single();
      setState(() {
        _userData = response;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        await supabase.from('profiles').update({
          'name': _userData!['name'],
          'phone': _userData!['phone'],
          'institution': _userData!['institution'],
          'gender': _userData!['gender'],
        }).eq('id', _user!.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $error')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BottomNav()));
          },
      ),
      ),
      backgroundColor: Colors.black,
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: _userData!['name'],
                      decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white)),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) => _userData!['name'] = value,
                    ),
                    TextFormField(
                      initialValue: _userData!['email'],
                      decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white)),
                      style: const TextStyle(color: Colors.white),
                      readOnly: true,
                    ),
                    TextFormField(
                      initialValue: _userData!['phone'],
                      decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.white)),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) => _userData!['phone'] = value,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Institution', labelStyle: TextStyle(color: Colors.white)),
                      value: _userData!['institution'],
                      dropdownColor: Colors.black,
                      items: _institutionOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _userData!['institution'] = newValue;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Gender', labelStyle: TextStyle(color: Colors.white)),
                      value: _userData!['gender'],
                      dropdownColor: Colors.black,
                      items: _genderOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _userData!['gender'] = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      child: const Text('Update Profile'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
