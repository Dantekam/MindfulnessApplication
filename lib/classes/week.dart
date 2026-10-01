import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week {
  Week({
    required this.label,
    required this.order,
    required this.status,
    required this.survey,
    required this.availableDate,
  });

  // class instance variables
  final String label;
  final int order;
  // required and mutable based on calendar availbility and completion
  // This value is dynamically overridden at runtime from user progress
  String status;
  final bool survey;
  // nullable DateTime value that will unlock weeks
  final DateTime? availableDate;

  // Factory constructor to create a Week object from Firestore document snapshot
  // Only loads basic structure; user-specific status should be overridden later
  factory Week.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp? availableTimestamp = data['availableDate'];

    return Week(
      label: data['label'] ?? doc.id,
      order: data['order'] ?? 0,
      status: data['status'] ?? 'unavailable',
      survey: data['survey'] ?? false,
      availableDate: availableTimestamp?.toDate(),
    );
  }
  static const Map<String, IconData> iconMap = {
    "completed": Icons.check,
    "partially completed (in progress)": Icons.lock_open,
    "available but not started": Icons.lock_open,
    "available but locked because previous weeks are incomplete":
        Icons.lock_person,
    "unavailable": Icons.lock,
  };
}

class WeeklyContent {
  WeeklyContent({
    required this.id,
    required this.order,
    required this.type,
    required this.content,
    required this.status,
  });
  final String id;
  final int order;
  final String type;
  final String content;
  String status;

  // Factory constructor to create a WeekContent object from Firestore document snapshot
  // Only loads basic structure; user-specific status should be overridden later
  factory WeeklyContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return WeeklyContent(
      id: data['id'] ?? doc.id,
      order: data['order'] ?? 0,
      type: data['type'] ?? '',
      content: data['content'] ?? '',
      status: data['status'] ?? 'incomplete',
    );
  }
}
