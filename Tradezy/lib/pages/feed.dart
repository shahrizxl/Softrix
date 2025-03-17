import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:Tradezy/main.dart';

class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final _postController = TextEditingController();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final postResponse = await supabase
          .from('posts')
          .select('id, user_id, content, created_at')
          .order('created_at', ascending: false);

      final posts = postResponse as List<Map<String, dynamic>>;

      final userIds = posts.map((post) => post['user_id'] as String).toSet().toList();

      final profileResponse = await supabase
          .from('profiles')
          .select('id, name, institution')
          .inFilter('id', userIds);

      final profiles = (profileResponse as List<Map<String, dynamic>>)
          .asMap()
          .map((_, profile) => MapEntry(profile['id'], profile));

      for (var post in posts) {
        final profile = profiles[post['user_id']];
        if (profile == null) {
          post['profiles'] = {'name': 'Unnamed User', 'institution': 'N/A'};
        } else {
          post['profiles'] = profile;
        }
      }

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading posts: $error')),
      );
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content')),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to post')),
        );
        return;
      }

      final profileResponse = await supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email ?? '',
          'name': user.email?.split('@')[0] ?? 'User ${user.id.substring(0, 8)}',
          'institution': 'N/A',
          'gender': 'N/A',
          'phone': '',
        });
      }

      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': _postController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _postController.clear();
      await _fetchPosts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat sent successfully!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $error')),
        );
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[900], 
    appBar: AppBar(
      centerTitle: true,
      title: const Text('Traders chat', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.grey[900], 
      elevation: 0, 
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchPosts, 
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _postController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800], 
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('Chat'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _posts.isEmpty
                  ? const Center(
                      child: Text(
                        'No chats yet. Be the first to share!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        final profile = post['profiles'];
                        final createdAt = DateTime.parse(post['created_at']);
                        final formattedDate = DateFormat('MMM d, yyyy • HH:mm').format(createdAt);

                        return Card(
                          color: Colors.grey[850], 
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Text(
                                        profile['name'][0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          profile['institution'] ?? 'N/A',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  post['content'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}
}