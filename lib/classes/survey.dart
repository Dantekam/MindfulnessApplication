import 'package:cloud_firestore/cloud_firestore.dart';

class Survey {
  final String label;
  final String url;
  final String code;
  final String weekLabel;

  Survey({
    required this.label,
    required this.url,
    required this.code,
    required this.weekLabel,
  });

  factory Survey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Survey(
      label: data['label'] ?? doc.id,
      url: data['url'] ?? '',
      code: data['code'] ?? '',
      weekLabel: data['weekLabel'] ?? '',
    );
  }
}
