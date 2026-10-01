import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'search_journal_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  JournalScreenState createState() => JournalScreenState();
}

class JournalScreenState extends State<JournalScreen> {
  late PageController _pageController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  List<Map<String, dynamic>> journalEntries = [];
  int _currentPage = 0;
  bool isCreatingNewEntry = false;
  bool _isLoading = true;
  bool _isCreatingNewPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
              .orderBy('order')
              .get();

      if (mounted) {
        setState(() {
          _isLoading = false;
          journalEntries =
              snapshot.docs.map((doc) {
                return {
                  'id': doc.id,
                  'order': doc['order'],
                  'title': doc['title'],
                  'content': doc['content'],
                  'timestamp': (doc['timestamp'] as Timestamp).toDate(),
                };
              }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching journal entries: $e');
      setState(() {
        _isLoading = false;
        journalEntries = [];
      });
    }
  }

  void _saveJournalEntry() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final currentEntry = journalEntries[_currentPage];
    final updatedContent = _textController.text;

    await FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(userId)
        .collection('Journals')
        .doc(currentEntry['id'])
        .update({'content': updatedContent, 'timestamp': Timestamp.now()});

    setState(() {
      journalEntries[_currentPage]['content'] = updatedContent;
      isCreatingNewEntry = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Journal entry saved!')));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _nextPage() async {
    if (_currentPage < journalEntries.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _isCreatingNewPage = true;
      });
      await _createNewJournalEntry();
      setState(() {
        _isCreatingNewPage = false;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToSearchJournal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchJournalScreen()),
    );
  }

  Future<void> _createNewJournalEntry() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final newTitle = 'Journal ${journalEntries.length + 1}';
    final newOrder = journalEntries.length + 1;
    final newTimestamp = Timestamp.now();

    final docRef = await FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(userId)
        .collection('Journals')
        .add({
          'title': newTitle,
          'content': '',
          'timestamp': newTimestamp,
          'order': newOrder,
        });

    setState(() {
      journalEntries.add({
        'id': docRef.id,
        'title': newTitle,
        'content': '',
        'timestamp': newTimestamp.toDate(),
        'order': newOrder,
      });
      isCreatingNewEntry = true;
      _currentPage = journalEntries.length - 1;
      _textController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      FocusScope.of(context).requestFocus(_textFocusNode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(
          Icons.self_improvement,
          size: 40,
          color: Colors.white,
        ),
        title: const Text(
          'J O U R N A L',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF607D8B),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _navigateToSearchJournal,
          ),
        ],
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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : journalEntries.isEmpty
                ? Center(
                  child: ElevatedButton(
                    onPressed: _createNewJournalEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF607D8B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      minimumSize: const Size(180, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create New Entry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: journalEntries.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                            _textController.text =
                                journalEntries[index]['content'];
                          });
                        },
                        itemBuilder: (context, index) {
                          final entry = journalEntries[index];
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Card(
                              color: Colors.white,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _textFocusNode,
                                  maxLines: null,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    labelText: entry['title'],
                                    labelStyle: const TextStyle(
                                      color: Colors.black,
                                    ),
                                    border: const OutlineInputBorder(),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                    hintText: 'Write your journal...',
                                    hintStyle: const TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                  cursorColor: Colors.black,
                                  onChanged: (value) {
                                    setState(() {
                                      journalEntries[index]['content'] = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isCreatingNewPage)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _previousPage,
                          ),
                          ElevatedButton(
                            onPressed:
                                isCreatingNewEntry ? _saveJournalEntry : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF607D8B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(120, 50),
                            ),
                            child: const Text(
                              'Save Entry',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                            onPressed: _nextPage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
