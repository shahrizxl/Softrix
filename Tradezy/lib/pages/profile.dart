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
  bool _isLoading = false;

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
    // Add this line to check image assets when the profile page loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkImageAssets());
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    _user = supabase.auth.currentUser;
    if (_user != null) {
      try {
        final response = await supabase.from('profiles').select().eq('id', _user!.id).single();
        setState(() {
          _userData = response;
          _isLoading = false;
        });
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $error'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await supabase.from('profiles').update({
          'name': _userData!['name'],
          'phone': _userData!['phone'],
          'institution': _userData!['institution'],
          'gender': _userData!['gender'],
        }).eq('id', _user!.id);

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF42a5f5), // Lighter blue
          ),
        );
      } catch (error) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkImageAssets() {
    // This method can be called to check if image assets are properly loaded
    try {
      // List all assets that should be available
      final assetPaths = [
        'images/profile_graphic.png',
        'images/wave_graphic.png',
        'images/male.png',
        'images/female.png'
      ];

      for (var path in assetPaths) {
        DefaultAssetBundle.of(context).load(path).then((_) {
          print('Successfully loaded asset: $path');
        }).catchError((error) {
          print('Failed to load asset: $path - Error: $error');
        });
      }
    } catch (e) {
      print('Error checking assets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BottomNav()),
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42a5f5)), // Lighter blue
        ),
      )
          : _userData == null
          ? const Center(child: Text('No profile data found'))
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildProfileForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF42a5f5), Color(0xFF1976d2)], // Lighter and darker blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Decorative graphic - 120x120 pixels
              Positioned(
                top: 10,
                right: 20,
                child: Image.asset(
                  'images/profile_graphic.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading profile graphic: $error');
                    return const SizedBox.shrink();
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: CircleAvatar(
                  radius: 50, // 100x100 pixels for the avatar
                  backgroundColor: Colors.white,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      _userData!['gender']?.toLowerCase() == 'female'
                          ? 'images/female.png'
                          : 'images/male.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading profile image: $error');
                        return Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey[400],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                _userData!['name'] ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _userData!['email'] ?? '',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _userData!['institution'] ?? 'Trader',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // Bottom decorative graphic - 150x80 pixels
        Positioned(
          bottom: -40,
          child: Image.asset(
            'images/wave_graphic.png',
            width: 150,
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading wave graphic: $error');
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Full Name',
              initialValue: _userData!['name'],
              icon: Icons.person,
              onChanged: (value) => _userData!['name'] = value,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Email',
              initialValue: _userData!['email'],
              icon: Icons.email,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Phone Number',
              initialValue: _userData!['phone'],
              icon: Icons.phone,
              onChanged: (value) => _userData!['phone'] = value,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Trading Level',
              value: _userData!['institution'],
              icon: Icons.trending_up,
              items: _institutionOptions,
              onChanged: (value) {
                setState(() {
                  _userData!['institution'] = value;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Gender',
              value: _userData!['gender'],
              icon: Icons.person_outline,
              items: _genderOptions,
              onChanged: (value) {
                setState(() {
                  _userData!['gender'] = value;
                });
              },
            ),
            const SizedBox(height: 30),
            _buildButton(
              label: 'Update Profile',
              icon: Icons.save,
              color: const Color(0xFF42a5f5), // Lighter blue
              onPressed: _updateProfile,
            ),
            const SizedBox(height: 16),
            _buildButton(
              label: 'Logout',
              icon: Icons.logout,
              color: const Color(0xFFFF7675),
              onPressed: _logout,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String? initialValue,
    required IconData icon,
    bool readOnly = false,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      readOnly: readOnly,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF2D3436),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: readOnly ? Colors.grey : const Color(0xFF42a5f5), // Lighter blue
          size: 22,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF42a5f5), // Lighter blue
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select an option';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF42a5f5), // Lighter blue
          size: 22,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF42a5f5), // Lighter blue
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      style: const TextStyle(
        color: Color(0xFF2D3436),
        fontSize: 16,
      ),
      icon: const Icon(
        Icons.arrow_drop_down,
        color: Color(0xFF42a5f5), // Lighter blue
      ),
      dropdownColor: Colors.white,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}