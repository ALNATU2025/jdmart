import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/skills_catalog.dart';
import '../models/skill_pro.dart';
import '../services/upload_service.dart';

class SkillRepository {
  SkillRepository(this._db, this._uploads);
  final FirebaseFirestore _db;
  final UploadService _uploads;

  CollectionReference<Map<String, dynamic>> get _skills => _db.collection('skills');

  /// Visible people, optionally offering [skillKey]. Sorting by distance/city
  /// happens on the phone.
  Stream<List<SkillPro>> search({String? skillKey, int limit = 150}) {
    Query<Map<String, dynamic>> q = _skills.where('visible', isEqualTo: true);
    if (skillKey != null && skillKey.isNotEmpty) q = q.where('skillKeys', arrayContains: skillKey);
    return q.limit(limit).snapshots().map((s) => s.docs.map(SkillPro.fromDoc).toList());
  }

  Stream<SkillPro?> watch(String uid) =>
      _skills.doc(uid).snapshots().map((d) => d.exists ? SkillPro.fromDoc(d) : null);

  Future<SkillPro?> mine(String uid) async {
    final d = await _skills.doc(uid).get();
    return d.exists ? SkillPro.fromDoc(d) : null;
  }

  Future<String> uploadPhoto(String uid, Uint8List bytes) =>
      _uploads.upload(path: 'skills/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg', bytes: bytes);

  Future<void> save({
    required String uid,
    required bool isNew,
    required String name,
    required String? photoUrl,
    required String headline,
    required List<String> skills,
    required String about,
    required String city,
    required String area,
    required double? lat,
    required double? lng,
    required String phone,
    required bool whatsApp,
    required String rate,
    required int experienceYears,
    required bool available,
    required bool visible,
  }) async {
    final clean = <String>[];
    for (final s in skills) {
      final t = s.trim();
      if (t.isNotEmpty && !clean.any((c) => c.toLowerCase() == t.toLowerCase())) clean.add(t);
    }
    final keys = {for (final s in clean) SkillsCatalog.keyOf(s)}.where((k) => k.isNotEmpty).toList();
    final data = <String, dynamic>{
      'name': name.trim(),
      'photoUrl': photoUrl,
      'headline': headline.trim(),
      'skills': clean,
      'skillKeys': keys,
      'about': about.trim(),
      'city': city,
      'area': area.trim(),
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'whatsApp': whatsApp,
      'rate': rate.trim(),
      'experienceYears': experienceYears,
      'available': available,
      'visible': visible,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };
    await _skills.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> delete(String uid) => _skills.doc(uid).delete();

  // Admins
  Future<void> setVerified(String uid, bool v) => _skills.doc(uid).update({'verified': v});
  Future<void> setVisible(String uid, bool v) => _skills.doc(uid).update({'visible': v});
}
