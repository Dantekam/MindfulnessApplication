import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uncw_app/classes/survey.dart';
import 'package:uncw_app/services/progress_service.dart';

class SurveyScreen extends StatefulWidget {
  final String? requiredWeekLabel;

  const SurveyScreen({super.key, this.requiredWeekLabel});

  @override
  SurveyScreenState createState() => SurveyScreenState();
}

class SurveyScreenState extends State<SurveyScreen> {
  List<Survey> _surveys = [];
  bool _isLoading = true;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _completedSurveys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showSnackbar("Please complete the required survey to continue.");
      }
    });
    debugPrint("[SurveyScreen] initState: loading surveys...");
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final surveySnapshot =
          await FirebaseFirestore.instance.collection('Surveys').get();
      final loadedSurveys =
          surveySnapshot.docs.map((doc) => Survey.fromFirestore(doc)).toList();
      debugPrint(
        "[SurveyScreen] Loaded ${loadedSurveys.length} total surveys from Firestore.",
      );

      final progressSnapshot =
          await FirebaseFirestore.instance
              .collection('UserProgress')
              .doc(userId)
              .collection('Surveys')
              .get();

      final completedSurveyLabels =
          progressSnapshot.docs
              .where((doc) => (doc.data()['completed'] == true))
              .map((doc) => doc.id)
              .toList();
      debugPrint(
        "[SurveyScreen] Found ${completedSurveyLabels.length} completed surveys for user.",
      );

      setState(() {
        _surveys = loadedSurveys;
        for (var survey in _surveys) {
          _controllers[survey.label] = TextEditingController();
          _completedSurveys[survey.label] = completedSurveyLabels.contains(
            survey.label,
          );
          debugPrint(
            "[SurveyScreen] Survey '${survey.label}' (Week: ${survey.weekLabel}) isCompleted: ${_completedSurveys[survey.label]}",
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("[SurveyScreen] Error loading surveys: $e");
      _showSnackbar('Failed to load surveys.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _validateCode(String code, Survey survey) async {
    debugPrint(
      "[SurveyScreen] User submitted code: '$code' for survey: '${survey.label}'",
    );

    if (code.isEmpty) {
      debugPrint(
        "[SurveyScreen] Code is empty. Prompting user to enter a valid code.",
      );
      _showSnackbar('Please enter a valid code.');
      return;
    }

    if (code == survey.code) {
      debugPrint(
        "[SurveyScreen] Code matches. Marking survey as completed for week: ${survey.weekLabel}",
      );
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance
            .collection('UserProgress')
            .doc(userId)
            .collection('Surveys')
            .doc(survey.weekLabel)
            .set({'completed': true});

        setState(() {
          _completedSurveys[survey.label] = true;
        });

        if (!mounted) return;
        _showSnackbar('Survey completed and saved!');

        // Unlock progress after survey completion
        await checkAndUnlockWeeks(userId: userId);

        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          debugPrint(
            "[SurveyScreen] Survey completed successfully. Popping back with true result.",
          );
          Navigator.of(context).pop(true);
        }
      } on FirebaseException catch (e) {
        debugPrint(
          "[SurveyScreen] FirebaseException during completion save: ${e.code}",
        );
        if (e.code == 'not-found') {
          _showSnackbar('Survey record not found. Please contact support.');
        } else {
          _showSnackbar('Failed to save survey completion.');
        }
      } catch (e) {
        debugPrint(
          "[SurveyScreen] Unexpected error during survey completion: $e",
        );
        _showSnackbar('Unexpected error occurred.');
      }
    } else {
      debugPrint(
        "[SurveyScreen] Submitted code '$code' does NOT match expected code '${survey.code}'.",
      );
      _showSnackbar('Invalid completion code. Please try again.');
    }
  }

  // void _openSurveyURL(String url) {
  //   debugPrint("[SurveyScreen] Open survey URL: $url");
  //   Implement URL launcher later
  // }

  @override
  void dispose() {
    debugPrint("[SurveyScreen] Disposing controllers...");
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "S U R V E Y S",
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
        child: Center(
          child:
              _isLoading
                  ? const CircularProgressIndicator()
                  : SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        ..._surveys.map(
                          (survey) => _buildSurveyWithCode(
                            survey: survey,
                            codeController: _controllers[survey.label]!,
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildSurveyWithCode({
    required Survey survey,
    required TextEditingController codeController,
  }) {
    final bool isCompleted = _completedSurveys[survey.label] ?? false;
    final bool matchesPendingSurvey =
        widget.requiredWeekLabel == survey.weekLabel;

    final bool enableInteraction =
        !isCompleted &&
        (widget.requiredWeekLabel == null || matchesPendingSurvey);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            if (enableInteraction) {
              _showSnackbar("${survey.label} code: ${survey.code}");
            } else {
              _showSnackbar('This survey is locked');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isCompleted
                    ? Colors.green
                    : const Color.fromARGB(255, 128, 158, 177),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(300, 50),
          ),
          child: Text(
            survey.label,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: codeController,
                enabled: enableInteraction,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Completion Code',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black.withAlpha(100),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                if (enableInteraction) {
                  _validateCode(codeController.text, survey);
                } else {
                  _showSnackbar('This survey is locked');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 128, 158, 177),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(120, 50),
              ),
              child: const Text(
                'Submit Code',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
