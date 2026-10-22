import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

enum DeliveryStatus { waiting, assigned, pickedUp, delivered }

extension DeliveryStatusX on DeliveryStatus {
  String get label => switch (this) {
        DeliveryStatus.waiting => 'Waiting for a rider',
        DeliveryStatus.assigned => 'Rider on the way to pick up',
        DeliveryStatus.pickedUp => 'On the way to the buyer',
        DeliveryStatus.delivered => 'Delivered',
      };
}

DeliveryStatus _status(dynamic v) => switch (v) {
      'assigned' => DeliveryStatus.assigned,
      'picked_up' => DeliveryStatus.pickedUp,
      'delivered' => DeliveryStatus.delivered,
      _ => DeliveryStatus.waiting,
    };

/// Someone's last shared position.
class LivePoint {
  final double lat;
  final double lng;
  final double? heading;
  final String role; // rider | seller | buyer
  final String name;
  final DateTime at;
  const LivePoint({
    required this.lat,
    required this.lng,
    this.heading,
    required this.role,
    required this.name,
    required this.at,
  });

  /// Older than 2 minutes = probably no longer moving / sharing.
  bool get isStale => DateTime.now().difference(at).inMinutes >= 2;

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'role': role,
        'name': name,
        'at': FieldValue.serverTimestamp(),
      };

  static LivePoint? fromMap(dynamic v) {
    if (v is! Map) return null;
    final lat = v['lat'];
    final lng = v['lng'];
    if (lat is! num || lng is! num) return null;
    return LivePoint(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      heading: v['heading'] is num ? (v['heading'] as num).toDouble() : null,
      role: (v['role'] ?? '') as String,
      name: (v['name'] ?? '') as String,
      at: tsToDate(v['at']),
    );
  }
}

/// deliveries/{orderId}
class Delivery {
  final String orderId;
  final String code;
  final String buyerId;
  final String sellerId;
  final String buyerName;
  final String sellerName;
  final String buyerPhone;
  final String sellerPhone;
  final String dropoff;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? riderPhotoUrl;
  final String riderVehicle;
  final String riderPlate;
  final DeliveryStatus status;
  final Map<String, LivePoint> locations;
  final DateTime updatedAt;

  const Delivery({
    required this.orderId,
    required this.code,
    required this.buyerId,
    required this.sellerId,
    required this.buyerName,
    required this.sellerName,
    required this.buyerPhone,
    required this.sellerPhone,
    required this.dropoff,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.riderPhotoUrl,
    this.riderVehicle = '',
    this.riderPlate = '',
    required this.status,
    required this.locations,
    required this.updatedAt,
  });

  /// e.g. "Motorbike • AKN 123" (empty for older deliveries).
  String get riderVehicleLabel =>
      riderPlate.isEmpty ? riderVehicle : (riderVehicle.isEmpty ? riderPlate : '$riderVehicle • $riderPlate');

  String get shortOrderId => orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();

  /// rider / seller / buyer / '' for this user.
  String roleOf(String? uid) {
    if (uid == null) return '';
    if (uid == riderId) return 'rider';
    if (uid == sellerId) return 'seller';
    if (uid == buyerId) return 'buyer';
    return '';
  }

  String? uidFor(String role) => switch (role) {
        'rider' => riderId,
        'seller' => sellerId,
        'buyer' => buyerId,
        _ => null,
      };

  LivePoint? locationOf(String role) {
    final id = uidFor(role);
    return id == null ? null : locations[id];
  }

  factory Delivery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    final locs = <String, LivePoint>{};
    final raw = j['locations'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final p = LivePoint.fromMap(v);
        if (p != null) locs[k.toString()] = p;
      });
    }
    return Delivery(
      orderId: doc.id,
      code: (j['code'] ?? '') as String,
      buyerId: (j['buyerId'] ?? '') as String,
      sellerId: (j['sellerId'] ?? '') as String,
      buyerName: (j['buyerName'] ?? '') as String,
      sellerName: (j['sellerName'] ?? '') as String,
      buyerPhone: (j['buyerPhone'] ?? '') as String,
      sellerPhone: (j['sellerPhone'] ?? '') as String,
      dropoff: (j['dropoff'] ?? '') as String,
      riderId: j['riderId'] as String?,
      riderName: j['riderName'] as String?,
      riderPhone: j['riderPhone'] as String?,
      riderPhotoUrl: j['riderPhotoUrl'] as String?,
      riderVehicle: (j['riderVehicle'] ?? '') as String,
      riderPlate: (j['riderPlate'] ?? '') as String,
      status: _status(j['status']),
      locations: locs,
      updatedAt: tsToDate(j['updatedAt']),
    );
  }
}
