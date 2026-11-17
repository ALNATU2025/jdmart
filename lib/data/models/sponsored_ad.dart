import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// One advertising option, e.g. 3 days for Le 120.
class AdPackage {
  final int days;
  final int price; // new Leones
  const AdPackage(this.days, this.price);

  String get label => switch (days) {
        1 => '1 day',
        7 => '1 week',
        14 => '2 weeks',
        30 => '1 month',
        _ => '$days days',
      };

  Map<String, dynamic> toMap() => {'days': days, 'price': price};
}

/// config/ads — prices and payment details, edited by admins in the app.
class AdSettings {
  final bool enabled;
  final List<AdPackage> packages;
  final String payNumber;
  final String payName;
  final String instructions;
  final int reminderHours; // how often each phone shows an ad reminder

  const AdSettings({
    required this.enabled,
    required this.packages,
    required this.payNumber,
    required this.payName,
    required this.instructions,
    required this.reminderHours,
  });

  /// Example prices until an admin sets real ones.
  static const defaults = AdSettings(
    enabled: true,
    packages: [
      AdPackage(1, 50),
      AdPackage(2, 90),
      AdPackage(3, 130),
      AdPackage(4, 165),
      AdPackage(5, 200),
      AdPackage(7, 260),
      AdPackage(30, 900),
    ],
    payNumber: '',
    payName: 'JDMart',
    instructions: '',
    reminderHours: 2,
  );

  factory AdSettings.fromMap(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    final list = <AdPackage>[];
    if (j['packages'] is List) {
      for (final p in j['packages'] as List) {
        if (p is Map && p['days'] is num && p['price'] is num && (p['price'] as num) > 0) {
          list.add(AdPackage((p['days'] as num).toInt(), (p['price'] as num).toInt()));
        }
      }
    }
    list.sort((a, b) => a.days.compareTo(b.days));
    return AdSettings(
      enabled: j['enabled'] != false,
      packages: list.isEmpty ? defaults.packages : list,
      payNumber: (j['payNumber'] ?? '') as String,
      payName: (j['payName'] ?? defaults.payName) as String,
      instructions: (j['instructions'] ?? '') as String,
      reminderHours: (toInt(j['reminderHours'], 2)).clamp(1, 12),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'packages': [for (final p in packages) p.toMap()],
        'payNumber': payNumber.trim(),
        'payName': payName.trim(),
        'instructions': instructions.trim(),
        'reminderHours': reminderHours,
      };
}

/// ads/{id} — a paid promotion of one listing. Sellers create it as
/// "pending"; an admin approves it after checking the payment, which sets the
/// start and end time.
class SponsoredAd {
  final String id;
  final String productId;
  final String sellerId;
  final String sellerName;
  final String title;
  final String? imageUrl;
  final double price;
  final double? oldPrice;
  final String city;
  final int days;
  final int amount;
  final String payMethod;
  final String payPhone;
  final String payRef;
  final String status; // pending | active | rejected | ended | cancelled
  final String note;
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const SponsoredAd({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.title,
    this.imageUrl,
    required this.price,
    this.oldPrice,
    required this.city,
    required this.days,
    required this.amount,
    required this.payMethod,
    required this.payPhone,
    required this.payRef,
    required this.status,
    required this.note,
    required this.createdAt,
    this.startsAt,
    this.endsAt,
  });

  bool get isLive {
    final now = DateTime.now();
    return status == 'active' && endsAt != null && endsAt!.isAfter(now) && (startsAt == null || !startsAt!.isAfter(now));
  }

  bool get isExpired => status == 'active' && endsAt != null && !endsAt!.isAfter(DateTime.now());

  /// What the seller sees.
  String get statusLabel {
    if (isLive) return 'Live';
    if (isExpired) return 'Ended';
    return switch (status) {
      'pending' => 'Waiting for approval',
      'rejected' => 'Not approved',
      'cancelled' => 'Cancelled',
      'ended' => 'Ended',
      _ => status,
    };
  }

  int get discountPercent =>
      (oldPrice != null && oldPrice! > price && oldPrice! > 0) ? (((oldPrice! - price) / oldPrice!) * 100).round() : 0;

  factory SponsoredAd.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return SponsoredAd(
      id: doc.id,
      productId: (j['productId'] ?? '') as String,
      sellerId: (j['sellerId'] ?? '') as String,
      sellerName: (j['sellerName'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      imageUrl: j['imageUrl'] as String?,
      price: toDouble(j['price']),
      oldPrice: j['oldPrice'] is num ? (j['oldPrice'] as num).toDouble() : null,
      city: (j['city'] ?? '') as String,
      days: toInt(j['days'], 1),
      amount: toInt(j['amount']),
      payMethod: (j['payMethod'] ?? '') as String,
      payPhone: (j['payPhone'] ?? '') as String,
      payRef: (j['payRef'] ?? '') as String,
      status: (j['status'] ?? 'pending') as String,
      note: (j['note'] ?? '') as String,
      createdAt: tsToDate(j['createdAt']),
      startsAt: j['startsAt'] == null ? null : tsToDate(j['startsAt']),
      endsAt: j['endsAt'] == null ? null : tsToDate(j['endsAt']),
    );
  }
}
