import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/rider.dart';

/// Verified riders: applications, approval and assigning riders to deliveries.
class RiderRepository {
  RiderRepository(this._db, this._functions, this._storage);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('riders');
  DocumentReference<Map<String, dynamic>> _kyc(String uid) => _col.doc(uid).collection('private').doc('kyc');

  Stream<Rider?> watch(String uid) => _col.doc(uid).snapshots().map((d) => d.exists ? Rider.fromDoc(d) : null);

  Future<RiderKyc?> kyc(String uid) async {
    final d = await _kyc(uid).get();
    return d.exists ? RiderKyc.fromMap(d.data()!) : null;
  }

  /// Approved riders (for sellers to choose from), available ones first.
  Stream<List<Rider>> approved() => _col.where('status', isEqualTo: 'approved').limit(200).snapshots().map((s) {
        final list = s.docs.map(Rider.fromDoc).toList();
        list.sort((a, b) {
          if (a.available != b.available) return a.available ? -1 : 1;
          return b.deliveries.compareTo(a.deliveries);
        });
        return list;
      });

  Future<String> uploadImage(String uid, String name, Uint8List bytes) async {
    final ref = _storage.ref().child('riders/$uid/${DateTime.now().millisecondsSinceEpoch}-$name.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Creates or updates the application. Any change sends it back for review.
  Future<void> apply({
    required String uid,
    required bool isNew,
    required String name,
    required String photoUrl,
    required String vehicleType,
    required String plate,
    required String city,
    required String idType,
    required String idNumber,
    String? idPhotoUrl,
    required String phone,
  }) async {
    final batch = _db.batch();
    final data = {
      'name': name.trim(),
      'photoUrl': photoUrl,
      'vehicleType': vehicleType,
      'plate': plate.trim().toUpperCase(),
      'city': city,
      'available': true,
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isNew) {
      batch.set(_col.doc(uid), {...data, 'deliveries': 0, 'reviewNote': '', 'createdAt': FieldValue.serverTimestamp()});
    } else {
      batch.update(_col.doc(uid), data);
    }
    batch.set(_kyc(uid), {
      'idType': idType,
      'idNumber': idNumber.trim(),
      'idPhotoUrl': idPhotoUrl,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> setAvailable(String uid, bool available) =>
      _col.doc(uid).update({'available': available, 'updatedAt': FieldValue.serverTimestamp()});

  /// Seller chooses a verified rider for an order.
  Future<void> assign(String orderId, String riderId) async {
    try {
      await _functions.httpsCallable('assignRider').call<dynamic>({'orderId': orderId, 'riderId': riderId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Something went wrong (${e.code}).');
    }
  }

  // ---- Admins ----------------------------------------------------------------------------
  Stream<List<Rider>> all() => _col
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Rider.fromDoc).toList());

  Future<void> setStatus(String uid, RiderStatus status, {String note = ''}) => _col.doc(uid).update({
        'status': status.name,
        'reviewNote': note.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
}
