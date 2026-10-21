import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// Public profile stored at users/{uid}. Anyone can read it, so it must not
/// contain private data. The phone number lives in users/{uid}/private/account
/// and is only copied to [contactPhone] if the user chooses to show it.
class AppUser {
  final String id;
  final String name;
  final String city;
  final String bio;
  final String? avatarUrl;
  final String? contactPhone;
  final bool verified; // set by admins only
  final double ratingAvg; // maintained by Cloud Functions
  final int ratingCount;
  final int salesCount;
  final DateTime joinedAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.city,
    this.bio = '',
    this.avatarUrl,
    this.contactPhone,
    this.verified = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.salesCount = 0,
    required this.joinedAt,
  });

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      name: (j['name'] ?? '') as String,
      city: (j['city'] ?? 'Freetown') as String,
      bio: (j['bio'] ?? '') as String,
      avatarUrl: j['avatarUrl'] as String?,
      contactPhone: j['contactPhone'] as String?,
      verified: j['verified'] == true,
      ratingAvg: toDouble(j['ratingAvg']),
      ratingCount: toInt(j['ratingCount']),
      salesCount: toInt(j['salesCount']),
      joinedAt: tsToDate(j['createdAt']),
    );
  }
}
