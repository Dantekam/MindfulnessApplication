import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uncw_app/classes/week.dart';
import 'package:uncw_app/screens/survey_screen.dart';
import 'package:uncw_app/screens/week_screen.dart';
import 'package:uncw_app/screens/login.dart';
import 'package:uncw_app/services/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  String? pendingSurveyWeekLabel;
  bool _surveyScreenOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeProgressScreen();
  }

  Future<void> _initializeProgressScreen() async {
    await _checkForUnlockedWeeks();
    await _checkSurveyRequirement();
    _startMidnightTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      debugPrint("[ProgressScreen] Resumed with focus. Checking for surveys.");
      _checkSurveyRequirement(fromReturn: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        debugPrint(
          "[ProgressScreen] Returned to ProgressScreen. Checking for surveys.",
        );
        _checkSurveyRequirement(fromReturn: true);
      }
    });
  }

  Future<void> _checkForUnlockedWeeks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await checkAndUnlockWeeks(userId: user.uid);
    }
  }

  Future<void> _checkSurveyRequirement({bool fromReturn = false}) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final surveyWeekLabel = await checkPendingSurvey(userId: userId);

    if (surveyWeekLabel != null) {
      setState(() {
        pendingSurveyWeekLabel = surveyWeekLabel;
      });

      if (mounted &&
          !_surveyScreenOpened &&
          ModalRoute.of(context)?.isCurrent == true &&
          !fromReturn) {
        _surveyScreenOpened = true;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder:
                    (context) =>
                        SurveyScreen(requiredWeekLabel: surveyWeekLabel),
              ),
            )
            .then((result) async {
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return;

              if (result == true) {
                await _checkForUnlockedWeeks();
                setState(() {
                  pendingSurveyWeekLabel = null;
                  _surveyScreenOpened = false;
                });
              } else {
                await _checkSurveyRequirement(fromReturn: true);
                setState(() {
                  _surveyScreenOpened = false;
                });
              }
            });
      }
    } else {
      setState(() {
        pendingSurveyWeekLabel = null;
      });
    }
  }

  void _startMidnightTimer() {
    DateTime now = DateTime.now();
    DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    Duration durationUntilMidnight = nextMidnight.difference(now);

    _midnightTimer = Timer(durationUntilMidnight, () async {
      await _checkForUnlockedWeeks();
      _startMidnightTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _midnightTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final weeksStream =
        FirebaseFirestore.instance
            .collection('Weeks')
            .orderBy('order')
            .snapshots();
    final userProgressStream =
        FirebaseFirestore.instance
            .collection('UserProgress')
            .doc(userId)
            .collection('Weeks')
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: const Icon(
          Icons.self_improvement,
          size: 40,
          color: Colors.white,
        ),
        title: const Text(
          "H O M E",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF607D8B),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 8.0),
            child: ElevatedButton(
              onPressed: () async {
                await resetUserProgress(userId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Progress reset to beginning.")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[200],
              ),
              child: const Text(
                "Reset",
                style: TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: ElevatedButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black),
              ),
            ),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: userProgressStream,
          builder: (context, userProgressSnapshot) {
            if (!userProgressSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userStatus = {
              for (var doc in userProgressSnapshot.data!.docs)
                doc.id: doc['status'] as String,
            };

            final totalWeeks = userProgressSnapshot.data!.docs.length;
            final completedWeeks =
                userProgressSnapshot.data!.docs
                    .where((doc) => doc['status'] == 'completed')
                    .length;
            final progress =
                totalWeeks == 0 ? 0.0 : completedWeeks / totalWeeks;

            return StreamBuilder<QuerySnapshot>(
              stream: weeksStream,
              builder: (context, weekSnapshot) {
                if (!weekSnapshot.hasData || weekSnapshot.data!.docs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final weekDocs = weekSnapshot.data!.docs;

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ProgressBar(progress: progress),
                      const SizedBox(height: 10),
                      const SurveyButton(),
                      Expanded(
                        child: WeekLayout(
                          weekDocs: weekDocs,
                          userStatus: userStatus,
                          isLocked: pendingSurveyWeekLabel != null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey[300],
      ),
      height: 60.0,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              color: Colors.lightBlueAccent,
              backgroundColor: Colors.transparent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Text(
              "Your Progress: ${(progress * 100).toStringAsFixed(1)}%",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SurveyButton extends StatelessWidget {
  const SurveyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final progressState =
        context.findAncestorStateOfType<_ProgressScreenState>();

    return GestureDetector(
      onTap: () {
        final String? requiredSurvey = progressState?.pendingSurveyWeekLabel;

        if (requiredSurvey != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => SurveyScreen(requiredWeekLabel: requiredSurvey),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No pending surveys to complete.")),
          );
        }
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: Color.fromARGB(255, 44, 64, 77),
        ),
        height: 60.0,
        width: double.infinity,
        child: const Center(
          child: Text(
            "S U R V E Y S",
            style: TextStyle(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class WeekLayout extends StatelessWidget {
  final List<QueryDocumentSnapshot> weekDocs;
  final Map<String, String> userStatus;
  final bool isLocked;

  const WeekLayout({
    required this.weekDocs,
    required this.userStatus,
    required this.isLocked,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: weekDocs.length,
      itemBuilder: (context, index) {
        final weekDoc = weekDocs[index];
        Week curWeek = Week.fromFirestore(weekDoc);

        if (userStatus.containsKey(curWeek.label)) {
          curWeek.status = userStatus[curWeek.label]!;
        }

        return WeekCard(week: curWeek, isLocked: isLocked);
      },
    );
  }
}

class WeekCard extends StatelessWidget {
  const WeekCard({required this.week, required this.isLocked, super.key});

  final Week week;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(255, 60, 85, 100),
      margin: const EdgeInsets.all(8),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          if (isLocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please complete the required survey first.'),
              ),
            );
            return;
          }
          if (week.status == "completed" ||
              week.status == "partially completed (in progress)" ||
              week.status == "available but not started") {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => WeekScreen(week: week)),
            );
          } else if (week.status ==
              "available but locked because previous weeks are incomplete") {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Week ${week.order} is locked until you finish previous content!",
                ),
                duration: Duration(milliseconds: 1500),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Week ${week.order} is time locked!"),
                duration: Duration(milliseconds: 1500),
              ),
            );
          }
        },
        title: Text(
          "Week ${week.order}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        trailing: Icon(Week.iconMap[week.status], color: Colors.white70),
        minTileHeight: 80.0,
      ),
    );
  }
}
