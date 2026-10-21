import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/delivery.dart';

/// deliveries/{orderId}: tracking code, rider and live locations.
class DeliveryRepository {
  DeliveryRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _doc(String orderId) => _db.collection('deliveries').doc(orderId);

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final r = await _functions.httpsCallable(name).call<dynamic>(data);
      return Map<String, dynamic>.from(r.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Something went wrong (${e.code}).');
    }
  }

  /// Buyer or seller: returns the tracking code (creates it the first time).
  Future<String> open(String orderId) async => (await _call('openDelivery', {'orderId': orderId}))['code'] as String;

  /// Anyone with a code. Returns the order id; a new person becomes the rider.
  Future<String> join(String code) async => (await _call('joinDelivery', {'code': code}))['orderId'] as String;

  Future<void> pickup(String orderId) => _call('deliveryAction', {'orderId': orderId, 'action': 'pickup'});

  Future<void> deliver(String orderId, String pin) =>
      _call('deliveryAction', {'orderId': orderId, 'action': 'deliver', 'pin': pin});

  Future<void> release(String orderId) => _call('deliveryAction', {'orderId': orderId, 'action': 'release'});

  Stream<Delivery?> watch(String orderId) =>
      _doc(orderId).snapshots().map((d) => d.exists ? Delivery.fromDoc(d) : null);

  /// Deliveries I'm part of (as buyer, seller or rider), newest first.
  Stream<List<Delivery>> mine(String uid) => _db
      .collection('deliveries')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(Delivery.fromDoc).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  /// The buyer's 4-digit handover PIN (only the buyer can read it).
  Future<String?> pin(String orderId) async =>
      (await _doc(orderId).collection('secrets').doc('pin').get()).data()?['pin'] as String?;

  Future<void> share(String orderId, String uid, LivePoint p) => _doc(orderId).update({'locations.$uid': p.toMap()});

  Future<void> stopSharing(String orderId, String uid) =>
      _doc(orderId).update({'locations.$uid': FieldValue.delete()});
}
