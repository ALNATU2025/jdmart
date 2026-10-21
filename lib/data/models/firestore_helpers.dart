import 'package:cloud_firestore/cloud_firestore.dart';

DateTime tsToDate(dynamic v, {DateTime? fallback}) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? (fallback ?? DateTime.now());
  return fallback ?? DateTime.now();
}

double toDouble(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
int toInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
List<String> toStringList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
