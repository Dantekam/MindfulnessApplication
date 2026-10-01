import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectedJournalScreen extends StatefulWidget {
  final String journalId;

  const SelectedJournalScreen({super.key, required this.journalId});

  @override
  SelectedJournalScreenState createState() => SelectedJournalScreenState();
}

class SelectedJournalScreenState extends State<SelectedJournalScreen> {
  late TextEditingController _textController;
  late Map<String, dynamic> journalEntry;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    journalEntry = {};
    _fetchJournalEntry();
  }

  // Fetch the journal entry based on journalId
  void _fetchJournalEntry() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('UserProgress')
              .doc(userId)
              .collection('Journals')
              .doc(widget.journalId)
              .get();

      if (snapshot.exists) {
        final entry = snapshot.data();
        if (mounted) {
          setState(() {
            journalEntry = entry!;
            _textController.text = journalEntry['content'];
          });
        }
      } else {
        debugPrint('Journal not found');
      }
    } catch (e) {
      debugPrint('Error fetching journal entry: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'E N T R Y',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF607D8B),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF607D8B), Color(0xFF455A64)],
          ),
        ),
        child:
            journalEntry.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: const Color.fromARGB(255, 239, 236, 230),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Expanded makes the text field take up remaining space
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              maxLines: null, // allows unlimited lines
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                labelText: 'Content',
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                hintText: 'Write your journal...',
                                hintStyle: TextStyle(color: Colors.black),
                              ),
                              cursorColor: Colors.black,
                              enabled:
                                  false, // Disable editing to just display the content
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}
