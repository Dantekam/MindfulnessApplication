import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uncw_app/classes/week.dart';
import 'package:uncw_app/services/progress_service.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

bool isYouTubeLink(String content) {
  return content.contains("youtube.com") || content.contains("youtu.be");
}

class WeekScreen extends StatelessWidget {
  const WeekScreen({this.week, super.key});
  final Week? week;

  @override
  Widget build(BuildContext context) {
    if (week == null) {
      return Scaffold(
        appBar: AppBar(title: Text("E R R O R"), centerTitle: true),
        body: Center(child: Text("No Week data")),
      );
    }

    final weeklyContentRef = FirebaseFirestore.instance
        .collection('Weeks')
        .doc(week!.label)
        .collection('WeeklyContent')
        .orderBy('order');

    final userWeeklyContentRef = FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('Weeks')
        .doc(week!.label)
        .collection('WeeklyContent');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "W E E K",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF607D8B),
        centerTitle: true,
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
          stream: weeklyContentRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<QuerySnapshot>(
              stream:
                  userWeeklyContentRef.snapshots(), // user-specific completions
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final contentDocs = snapshot.data!.docs;
                final userDocs = userSnapshot.data!.docs;
                final userStatusMap = {
                  for (var doc in userDocs) doc.id: doc['status'] as String,
                };
                return WeeklyContentLayout(
                  week: week!,
                  weekDocs: contentDocs,
                  userStatus: userStatusMap,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class WeeklyContentLayout extends StatelessWidget {
  final List<QueryDocumentSnapshot> weekDocs;
  final Week week;
  final Map<String, String> userStatus;

  const WeeklyContentLayout({
    required this.weekDocs,
    required this.week,
    required this.userStatus,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: weekDocs.length,
      itemBuilder: (context, index) {
        final weekDoc = weekDocs[index];

        WeeklyContent weeklyContent = WeeklyContent.fromFirestore(weekDoc);

        if (userStatus.containsKey(weeklyContent.id)) {
          weeklyContent.status = userStatus[weeklyContent.id]!;
        } else {
          weeklyContent.status = "incomplete";
        }

        // content is "instruction" type
        if (weeklyContent.type == "instruction") {
          return InstructionCard(
            weekLabel: week.label,
            weeklyContent: weeklyContent,
          );
          // content is "prompt" type
        } else if (weeklyContent.type == "prompt") {
          return PromptCard(
            weekLabel: week.label,
            weeklyContent: weeklyContent,
          );
        } else {
          // type in in firebase
          return ListTile(title: Text("Unknown content type."));
        }
      },
    );
  }
}

class InstructionCard extends StatelessWidget {
  /// InstructionCard widget returns card for content with type "instruction" from firebase
  final String weekLabel;
  final WeeklyContent weeklyContent;

  const InstructionCard({
    super.key,
    required this.weekLabel,
    required this.weeklyContent,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return Card(
      margin: const EdgeInsets.all(12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('UserProgress')
                  .doc(userId)
                  .collection('Weeks')
                  .doc(weekLabel)
                  .collection('WeeklyContent')
                  .doc(weeklyContent.id)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final status = data['status'] ?? 'incomplete';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isYouTubeLink(weeklyContent.content))
                  SizedBox(
                    height: 200,
                    child: YoutubePlayer(
                      controller: YoutubePlayerController.fromVideoId(
                        videoId:
                            YoutubePlayerController.convertUrlToId(
                              weeklyContent.content,
                            ) ??
                            '',
                        params: const YoutubePlayerParams(
                          showControls: true,
                          showFullscreenButton: true,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    weeklyContent.content,
                    style: const TextStyle(fontSize: 18),
                  ),
                const SizedBox(height: 8),
                Text("Status: $status"),
                const SizedBox(height: 8),
                if (status != "completed")
                  // used to change status of a task to completed
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('UserProgress')
                          .doc(userId)
                          .collection('Weeks')
                          .doc(weekLabel)
                          .collection('WeeklyContent')
                          .doc(weeklyContent.id)
                          .set({
                            'status': 'completed',
                          }, SetOptions(merge: true));

                      await updateWeekStatus(weekLabel);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Task Completed!"),
                          duration: Duration(milliseconds: 1500),
                        ),
                      );
                    },
                    child: const Text(
                      "Done",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                if (status == "completed")
                  // replaces button when task completed
                  Row(
                    children: [
                      const Text("Done", style: TextStyle(color: Colors.green)),
                      SizedBox(width: 6),
                      Icon(Icons.check, color: Colors.green),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PromptCard extends StatefulWidget {
  /// PromptCard widget returns card with type "prompt" from firebase
  final String weekLabel;
  final WeeklyContent weeklyContent;

  const PromptCard({
    super.key,
    required this.weekLabel,
    required this.weeklyContent,
  });

  @override
  PromptCardState createState() => PromptCardState();
}

class PromptCardState extends State<PromptCard> {
  final TextEditingController _controller = TextEditingController();
  bool _loadingAnswer = true;

  @override
  void initState() {
    super.initState();
    _loadExistingAnswer();
  }

  void _loadExistingAnswer() async {
    /// determines if user has already responded to prompt
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final responseDoc =
        await FirebaseFirestore.instance
            .collection('UserProgress')
            .doc(userId)
            .collection('Responses')
            .doc(widget.weekLabel)
            .collection('Content')
            .doc(widget.weeklyContent.id)
            .get();

    if (responseDoc.exists) {
      final data = responseDoc.data()!;
      _controller.text = data['answer'] ?? '';
    }
    setState(() {
      _loadingAnswer = false;
    });
  }

  void _submitAnswer() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final time = Timestamp.now();
    // submit user entry and time into user specific response document
    await FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(userId)
        .collection('Responses')
        .doc(widget.weekLabel)
        .collection('Content')
        .doc(widget.weeklyContent.id)
        .set({'answer': _controller.text, 'timestamp': time});
    // adjust status due to completion of prompt
    await FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(userId)
        .collection('Weeks')
        .doc(widget.weekLabel)
        .collection('WeeklyContent')
        .doc(widget.weeklyContent.id)
        .set({'status': 'completed'}, SetOptions(merge: true));

    await updateWeekStatus(widget.weekLabel);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Response submitted!"),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    if (_loadingAnswer) {
      return Center(child: CircularProgressIndicator());
    }
    return Card(
      margin: const EdgeInsets.all(12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('UserProgress')
                  .doc(userId)
                  .collection('Weeks')
                  .doc(widget.weekLabel)
                  .collection('WeeklyContent')
                  .doc(widget.weeklyContent.id)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final status = data['status'] ?? 'incomplete';

            final isCompleted = status == "completed";

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.weeklyContent.content,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text("Status: $status"),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "Type your response...",
                    border: OutlineInputBorder(),
                    fillColor: isCompleted ? Colors.grey[200] : Colors.white,
                    filled: true,
                  ),
                  readOnly: isCompleted,
                ),
                const SizedBox(height: 8),
                if (!isCompleted)
                  ElevatedButton(
                    onPressed: _submitAnswer,
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                if (isCompleted)
                  Row(
                    children: [
                      const Text(
                        "Submitted",
                        style: TextStyle(color: Colors.green),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.check, color: Colors.green),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
