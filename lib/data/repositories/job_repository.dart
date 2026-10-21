import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/job.dart';

/// jobs/{id}, jobs/{id}/applications/{uid}, talent/{uid} and CV files
/// (Storage: cvs/{uid}/{timestamp}-{name}).
class JobRepository {
  JobRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');
  CollectionReference<Map<String, dynamic>> get _talent => _db.collection('talent');
  CollectionReference<Map<String, dynamic>> _apps(String jobId) => _jobs.doc(jobId).collection('applications');

  // ---- Jobs -----------------------------------------------------------------
  Stream<List<Job>> openJobs({int limit = 100}) => _jobs
      .where('status', isEqualTo: 'open')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Job.fromDoc).toList());

  Stream<List<Job>> mine(String uid) => _jobs
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Job.fromDoc).toList());

  Stream<Job?> watch(String id) => _jobs.doc(id).snapshots().map((d) => d.exists ? Job.fromDoc(d) : null);

  Future<String> create({required String ownerId, required String ownerName, required JobDraft draft}) async {
    final ref = _jobs.doc();
    await ref.set({
      ...draft.toMap(),
      'ownerId': ownerId,
      'ownerName': ownerName,
      'status': 'open',
      'applicationsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, JobDraft draft) =>
      _jobs.doc(id).update({...draft.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setOpen(String id, bool open) =>
      _jobs.doc(id).update({'status': open ? 'open' : 'closed', 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String id) => _jobs.doc(id).delete();

  // ---- Applications -----------------------------------------------------------
  /// My own application for a job (null if I haven't applied).
  Stream<JobApplication?> myApplication(String jobId, String uid) =>
      _apps(jobId).doc(uid).snapshots().map((d) => d.exists ? JobApplication.fromDoc(d) : null);

  /// Applications to one of my jobs (only the job owner may read them).
  Stream<List<JobApplication>> applicationsFor(String jobId, String ownerId) => _apps(jobId)
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((s) => s.docs.map(JobApplication.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Everything I have applied to.
  Stream<List<JobApplication>> myApplications(String uid) => _db
      .collectionGroup('applications')
      .where('applicantId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(JobApplication.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> apply({
    required Job job,
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String message,
    String? cvUrl,
    String? cvName,
  }) =>
      _apps(job.id).doc(uid).set({
        'jobId': job.id,
        'jobTitle': job.title,
        'company': job.company,
        'ownerId': job.ownerId,
        'applicantId': uid,
        'applicantName': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'message': message.trim(),
        'cvUrl': cvUrl,
        'cvName': cvName,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> withdraw(String jobId, String uid) => _apps(jobId).doc(uid).delete();

  Future<void> setApplicationStatus(String jobId, String applicantId, ApplicationStatus status) =>
      _apps(jobId).doc(applicantId).update({'status': status.value});

  // ---- Talent profiles (CVs) -----------------------------------------------------
  Stream<List<TalentProfile>> talent({int limit = 100}) => _talent
      .where('visible', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(TalentProfile.fromDoc).toList());

  Stream<TalentProfile?> watchTalent(String uid) =>
      _talent.doc(uid).snapshots().map((d) => d.exists ? TalentProfile.fromDoc(d) : null);

  Future<TalentProfile?> getTalent(String uid) async {
    final d = await _talent.doc(uid).get();
    return d.exists ? TalentProfile.fromDoc(d) : null;
  }

  Future<void> saveTalent(TalentProfile p, {required bool isNew}) {
    final data = {...p.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    return isNew
        ? _talent.doc(p.id).set({...data, 'createdAt': FieldValue.serverTimestamp()})
        : _talent.doc(p.id).update(data);
  }

  Future<void> deleteTalent(String uid) => _talent.doc(uid).delete();

  /// Uploads a CV (PDF or Word) and returns its download URL.
  Future<String> uploadCv(String uid, String fileName, Uint8List bytes) async {
    final lower = fileName.toLowerCase();
    final type = lower.endsWith('.pdf')
        ? 'application/pdf'
        : lower.endsWith('.docx')
            ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            : 'application/msword';
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = _storage.ref().child('cvs/$uid/${DateTime.now().millisecondsSinceEpoch}-$safe');
    await ref.putData(bytes, SettableMetadata(contentType: type));
    return ref.getDownloadURL();
  }
}
