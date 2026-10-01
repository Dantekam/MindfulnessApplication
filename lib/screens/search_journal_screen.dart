import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'selected_journal_screen.dart'; // Import the SelectedJournalScreen

class SearchJournalScreen extends StatefulWidget {
  const SearchJournalScreen({super.key});

  @override
  SearchJournalScreenState createState() => SearchJournalScreenState();
}

class SearchJournalScreenState extends State<SearchJournalScreen> {
  List<Map<String, dynamic>> journalEntries = [];

  @override
  void initState() {
    super.initState();
    _fetchJournalEntries();
  }

  void _fetchJournalEntries() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('UserProgress')
              .doc(userId)
              .collection('Journals')
              .orderBy('timestamp') // Sort entries by timestamp
              .get();

      final entries =
          snapshot.docs.map((doc) {
            return {
              'id': doc.id, // Ensure this is the correct journalId
              'title': doc['title'],
              'timestamp': (doc['timestamp'] as Timestamp).toDate(),
            };
          }).toList();

      setState(() {
        journalEntries = entries;
      });
    } catch (e) {
      debugPrint('Error fetching journal entries: $e');
    }
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
          'S E L E C T',
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
            journalEntries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                  itemCount: journalEntries.length,
                  itemBuilder: (context, index) {
                    final entry = journalEntries[index];
                    // Format the timestamp using DateFormat
                    final formattedDate = DateFormat(
                      'MMM dd, yyyy, h:mm a',
                    ).format(entry['timestamp']);

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: const Color.fromARGB(255, 60, 85, 100),
                        child: ListTile(
                          title: Text(
                            entry['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'Created on: $formattedDate',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            // Navigate to SelectedJournalScreen with the correct journalId
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SelectedJournalScreen(
                                      journalId:
                                          entry['id'], // Pass the journalId
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
