import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uncw_app/classes/week.dart';

Future<void> checkAndUnlockWeeks({
  required String userId,
  bool triggeredByCompletion = false,
}) async {
  final weeksSnapshot =
      await FirebaseFirestore.instance
          .collection('Weeks')
          .orderBy('order')
          .get();

  final userWeekSnapshot =
      await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Weeks')
          .get();

  final Map<String, String> weekStatus = {
    for (var doc in userWeekSnapshot.docs)
      doc.id: (doc.data()['status'] as String?) ?? "unavailable",
  };

  Week? previousWeek;

  for (final weekDoc in weeksSnapshot.docs) {
    final Week week = Week.fromFirestore(weekDoc);

    final currentStatus = weekStatus[week.label] ?? "unavailable";

    bool shouldConsiderThisWeek = false;

    if (triggeredByCompletion) {
      shouldConsiderThisWeek = (currentStatus != "completed");
    } else {
      shouldConsiderThisWeek = (currentStatus == "unavailable");
    }

    if (shouldConsiderThisWeek) {
      if (week.availableDate != null &&
          DateTime.now().isAfter(week.availableDate!)) {
        if (previousWeek == null) {
          debugPrint(
            "[checkAndUnlockWeeks] Unlocking first week: ${week.label}",
          );
          await setWeekStatus(userId, week.label, "available but not started");
        } else {
          final previousStatus =
              weekStatus[previousWeek.label] ?? "unavailable";

          if (previousStatus == "completed") {
            debugPrint(
              "[checkAndUnlockWeeks] Previous week ${previousWeek.label} completed. Unlocking ${week.label}",
            );
            await setWeekStatus(
              userId,
              week.label,
              "available but not started",
            );
          } else {
            debugPrint(
              "[checkAndUnlockWeeks] Previous week ${previousWeek.label} not completed. Locking ${week.label}",
            );
            await setWeekStatus(
              userId,
              week.label,
              "available but locked because previous weeks are incomplete",
            );
          }
        }
      }
      break;
    }

    previousWeek = week;
  }
}

Future<void> setWeekStatus(
  String userId,
  String weekLabel,
  String status,
) async {
  await FirebaseFirestore.instance
      .collection('UserProgress')
      .doc(userId)
      .collection('Weeks')
      .doc(weekLabel)
      .set({'status': status}, SetOptions(merge: true));
}

Future<void> updateWeekStatus(String weekLabel) async {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  final allTasksSnapshot =
      await FirebaseFirestore.instance
          .collection('Weeks')
          .doc(weekLabel)
          .collection('WeeklyContent')
          .get();

  final userTasksSnapshot =
      await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Weeks')
          .doc(weekLabel)
          .collection('WeeklyContent')
          .get();

  final Map<String, String> userStatus = {
    for (var doc in userTasksSnapshot.docs) doc.id: doc['status'] as String,
  };

  int completedTasks = 0;
  for (var taskDoc in allTasksSnapshot.docs) {
    final taskId = taskDoc.id;
    if (userStatus.containsKey(taskId) && userStatus[taskId] == 'completed') {
      completedTasks++;
    }
  }
  debugPrint(
    "[updateWeekStatus] Week $weekLabel: Completed $completedTasks / ${allTasksSnapshot.docs.length} tasks",
  );

  String newStatus;
  if (completedTasks == allTasksSnapshot.docs.length && completedTasks > 0) {
    newStatus = "completed";
  } else if (completedTasks > 0) {
    newStatus = "partially completed (in progress)";
  } else {
    newStatus = "available but not started";
  }

  debugPrint(
    "[updateWeekStatus] Week $weekLabel: Setting new status: $newStatus",
  );

  await FirebaseFirestore.instance
      .collection('UserProgress')
      .doc(userId)
      .collection('Weeks')
      .doc(weekLabel)
      .set({'status': newStatus}, SetOptions(merge: true));

  if (newStatus == "completed") {
    debugPrint(
      "[updateWeekStatus] Week $weekLabel completed. Checking for next week unlock...",
    );
    await checkAndUnlockWeeks(userId: userId, triggeredByCompletion: true);
  }
}

Future<String?> checkPendingSurvey({required String userId}) async {
  final weekSnapshot =
      await FirebaseFirestore.instance
          .collection('Weeks')
          .orderBy('order')
          .get();

  final userSurveySnapshot =
      await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Surveys')
          .get();

  final userWeekSnapshot =
      await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Weeks')
          .get();

  final Map<String, bool> surveyCompletion = {
    for (var doc in userSurveySnapshot.docs)
      doc.id: (doc.data()['completed'] == true),
  };

  final Map<String, String> weekStatus = {
    for (var doc in userWeekSnapshot.docs)
      doc.id: (doc.data()['status'] as String? ?? "unavailable"),
  };

  for (final weekDoc in weekSnapshot.docs) {
    final week = Week.fromFirestore(weekDoc);

    final status = weekStatus[week.label] ?? "unavailable";

    if (status == "completed") {
      debugPrint(
        "[checkPendingSurvey] Week ${week.label} is completed. Moving to next week.",
      );
      continue;
    }

    if (status == "available but not started") {
      final bool surveyRequired = week.survey == true;
      final bool surveyCompleted = surveyCompletion[week.label] ?? false;

      if (surveyRequired && !surveyCompleted) {
        debugPrint(
          "[checkPendingSurvey] Survey required for week: ${week.label}",
        );
        return week.label;
      } else {
        debugPrint(
          "[checkPendingSurvey] No survey needed for week: ${week.label}. No pending surveys.",
        );
        return null;
      }
    }

    debugPrint(
      "[checkPendingSurvey] Reached in-progress or locked week: ${week.label}. Stopping survey check.",
    );
    break;
  }

  debugPrint("[checkPendingSurvey] No pending surveys found.");
  return null;
}

Future<void> resetUserProgress(String userId) async {
  final weeksSnapshot =
      await FirebaseFirestore.instance
          .collection('Weeks')
          .orderBy('order')
          .get();

  Week? previousWeek;

  for (final weekDoc in weeksSnapshot.docs) {
    final Week week = Week.fromFirestore(weekDoc);

    String newStatus = "unavailable";
    if (week.availableDate != null &&
        DateTime.now().isAfter(week.availableDate!)) {
      if (previousWeek == null) {
        newStatus = "available but not started";
      } else {
        final prevWeekProgressDoc =
            await FirebaseFirestore.instance
                .collection('UserProgress')
                .doc(userId)
                .collection('Weeks')
                .doc(previousWeek.label)
                .get();

        final prevStatus =
            prevWeekProgressDoc.data()?['status'] ?? 'unavailable';

        if (prevStatus == "completed") {
          newStatus = "available but not started";
        } else {
          newStatus =
              "available but locked because previous weeks are incomplete";
        }
      }
    }

    await FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(userId)
        .collection('Weeks')
        .doc(week.label)
        .set({'status': newStatus}, SetOptions(merge: true));

    final weeklyContentSnapshot =
        await FirebaseFirestore.instance
            .collection('UserProgress')
            .doc(userId)
            .collection('Weeks')
            .doc(week.label)
            .collection('WeeklyContent')
            .get();

    for (final doc in weeklyContentSnapshot.docs) {
      await doc.reference.delete();
    }

    final responsesSnapshot =
        await FirebaseFirestore.instance
            .collection('UserProgress')
            .doc(userId)
            .collection('Responses')
            .doc(week.label)
            .collection('Content')
            .get();

    for (final doc in responsesSnapshot.docs) {
      await doc.reference.delete();
    }

    if (week.survey == true) {
      await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Surveys')
          .doc(week.label)
          .set({'completed': false});
    } else {
      final surveyDocRef = FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Surveys')
          .doc(week.label);

      final surveyDoc = await surveyDocRef.get();
      if (surveyDoc.exists) {
        await surveyDocRef.delete();
      }
    }

    previousWeek = week;
  }

  // Delete all journal entries for the user
  final journalSnapshot =
      await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(userId)
          .collection('Journals')
          .get();

  for (final doc in journalSnapshot.docs) {
    await doc.reference.delete();
  }
}
