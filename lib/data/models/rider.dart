import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

enum RiderStatus { pending, approved, rejected, suspended }

RiderStatus _status(dynamic v) => switch (v) {
      'approved' => RiderStatus.approved,
      'rejected' => RiderStatus.rejected,
      'suspended' => RiderStatus.suspended,
      _ => RiderStatus.pending,
    };

/// riders/{uid} — a dispatch rider's public profile (approved by admins).
class Rider {
  static const vehicles = ['Motorbike', 'Keke', 'Car', 'Bicycle', 'On foot'];
  static const idTypes = ['National ID', 'Voter ID', "Driver's licence", 'Passport'];

  final String id;
  final String name;
  final String? photoUrl;
  final String vehicleType;
  final String plate;
  final String city;
  final bool available;
  final RiderStatus status;
  final int deliveries;
  final String reviewNote;
  final DateTime createdAt;

  const Rider({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.vehicleType,
    this.plate = '',
    required this.city,
    this.available = true,
    this.status = RiderStatus.pending,
    this.deliveries = 0,
    this.reviewNote = '',
    required this.createdAt,
  });

  bool get isApproved => status == RiderStatus.approved;
  String get vehicleLabel => plate.isEmpty ? vehicleType : '$vehicleType • $plate';

  factory Rider.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Rider(
      id: doc.id,
      name: (j['name'] ?? '') as String,
      photoUrl: j['photoUrl'] as String?,
      vehicleType: (j['vehicleType'] ?? 'Motorbike') as String,
      plate: (j['plate'] ?? '') as String,
      city: (j['city'] ?? 'Freetown') as String,
      available: j['available'] != false,
      status: _status(j['status']),
      deliveries: toInt(j['deliveries']),
      reviewNote: (j['reviewNote'] ?? '') as String,
      createdAt: tsToDate(j['createdAt']),
    );
  }
}

/// riders/{uid}/private/kyc — identity details only the rider and admins see.
class RiderKyc {
  final String idType;
  final String idNumber;
  final String? idPhotoUrl;
  final String phone;
  const RiderKyc({required this.idType, required this.idNumber, this.idPhotoUrl, this.phone = ''});

  factory RiderKyc.fromMap(Map<String, dynamic> j) => RiderKyc(
        idType: (j['idType'] ?? '') as String,
        idNumber: (j['idNumber'] ?? '') as String,
        idPhotoUrl: j['idPhotoUrl'] as String?,
        phone: (j['phone'] ?? '') as String,
      );
}
