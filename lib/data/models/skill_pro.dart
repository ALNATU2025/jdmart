import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/skills_catalog.dart';
import 'firestore_helpers.dart';

/// skills/{uid} — someone offering a skill or service (plumber, electrician…)
/// that people nearby can find and call.
class SkillPro {
  final String id; // = uid
  final String name;
  final String? photoUrl;
  final String headline;
  final List<String> skills; // as typed/picked, for display
  final List<String> skillKeys; // lowercase keys for searching
  final String about;
  final String city;
  final String area; // neighbourhood, e.g. "Wilberforce"
  final double? lat;
  final double? lng;
  final String phone; // E.164
  final bool whatsApp;
  final String rate; // free text, e.g. "From Le 150 per job"
  final int experienceYears;
  final bool available;
  final bool visible;
  final bool verified; // set by admins
  final DateTime updatedAt;

  const SkillPro({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.headline,
    required this.skills,
    required this.skillKeys,
    required this.about,
    required this.city,
    required this.area,
    this.lat,
    this.lng,
    required this.phone,
    required this.whatsApp,
    required this.rate,
    required this.experienceYears,
    required this.available,
    required this.visible,
    required this.verified,
    required this.updatedAt,
  });

  bool get hasLocation => lat != null && lng != null;

  /// First catalog skill, for the icon/colour.
  SkillType get mainType => SkillsCatalog.byKey(skillKeys.isEmpty ? '' : skillKeys.first);

  factory SkillPro.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return SkillPro(
      id: doc.id,
      name: (j['name'] ?? '') as String,
      photoUrl: j['photoUrl'] as String?,
      headline: (j['headline'] ?? '') as String,
      skills: toStringList(j['skills']),
      skillKeys: toStringList(j['skillKeys']),
      about: (j['about'] ?? '') as String,
      city: (j['city'] ?? '') as String,
      area: (j['area'] ?? '') as String,
      lat: j['lat'] is num ? (j['lat'] as num).toDouble() : null,
      lng: j['lng'] is num ? (j['lng'] as num).toDouble() : null,
      phone: (j['phone'] ?? '') as String,
      whatsApp: j['whatsApp'] != false,
      rate: (j['rate'] ?? '') as String,
      experienceYears: toInt(j['experienceYears']),
      available: j['available'] != false,
      visible: j['visible'] != false,
      verified: j['verified'] == true,
      updatedAt: tsToDate(j['updatedAt']),
    );
  }
}
