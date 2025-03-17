import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Tradezy/pages/com.dart'; 
import 'package:Tradezy/pages/bottomnav.dart';
import 'package:intl/intl.dart'; 

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _notes = [];

  final _noteController = TextEditingController();
  DateTime? _selectedDate; 

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view notes.');
      }

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: true);

      setState(() {
        _notes = response;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch notes: $error';
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      setState(() {
        _errorMessage = _selectedDate == null ? 'Please select a date' : null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to save notes.');
      }

      final note = {
        'user_id': user.id,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'note': _noteController.text.trim(),
      };

      await supabase.from('notes').insert(note);

      setState(() {
        _notes.add(note);
        _noteController.clear();
        _selectedDate = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved successfully!')),
      );
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to save note: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to delete notes.');
      }

      await supabase
          .from('notes')
          .delete()
          .eq('user_id', user.id)
          .eq('date', note['date'])
          .eq('note', note['note']);

      setState(() {
        _notes.remove(note);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted successfully!')),
      );
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to delete note: $error';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Notes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BottomNav()));
          },
        ),
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : 'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _selectDate(context),
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a note';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveNote,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Note'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            Expanded(
              child: _notes.isEmpty
                  ? const Center(
                      child: Text(
                        'No notes added yet.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(
                              'Date: ${note['date']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              note['note'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteNote(note),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}