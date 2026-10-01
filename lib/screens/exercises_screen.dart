import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exercise_detail_screen.dart'; // Import ExerciseDetailScreen

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ExercisesScreenState createState() => ExercisesScreenState();
}

class ExercisesScreenState extends State<ExercisesScreen> {
  List<Map<String, dynamic>> exercises = []; // List to hold exercise data

  // Fetch exercises data from Firestore
  Future<void> _fetchExercises() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('Exercises')
              .orderBy('order')
              .get();

      final List<Map<String, dynamic>> fetchedExercises =
          snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'title': doc['title'],
              'content':
                  doc['content'], // This will be the audio file name (or URL)
              'order': doc['order'],
            };
          }).toList();

      setState(() {
        exercises = fetchedExercises;
      });
    } catch (e) {
      debugPrint('Error fetching exercises: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchExercises(); // Fetch exercises when the screen is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.self_improvement, size: 40, color: Colors.white),
        title: const Text(
          'E X E R C I S E S',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF607D8B),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF607D8B),
              Color(0xFF455A64),
            ], // Darker gradient similar to login page
          ),
        ),
        child:
            exercises.isEmpty
                ? const Center(
                  child: CircularProgressIndicator(),
                ) // Show a loading indicator if no data is loaded
                : ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: const Color.fromARGB(255, 60, 85, 100),
                      child: ListTile(
                        title: Text(
                          exercise['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        minTileHeight: 80,
                        onTap: () {
                          // Navigate to ExerciseDetailScreen with the audio URL and title
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ExerciseDetailScreen(
                                    exerciseTitle: exercise['title'],
                                    audioUrl:
                                        exercise['content'], // Pass the audio URL to the detail screen
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
