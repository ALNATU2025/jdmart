import 'package:flutter/material.dart';

/// Reference data that ships with the app (not mock data): product categories,
/// delivery zones and payment options. Delivery fees are mirrored in
/// functions/src/catalog.ts — the server copy is the one that is charged.

class ProductCategory {
  final String id;
  final String name;
  final IconData icon; // fallback when the image asset is missing
  final String image; // file name inside assets/images/
  final Color color;
  const ProductCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.image,
    required this.color,
  });

  String get imagePath => 'assets/images/$image';
}

enum PaymentOption { online, cashOnDelivery }

extension PaymentOptionX on PaymentOption {
  String get id => this == PaymentOption.online ? 'online' : 'cod';
  String get label => this == PaymentOption.online ? 'Mobile Money or Card' : 'Cash on Delivery';
  String get hint => this == PaymentOption.online
      ? 'Orange Money, Afrimoney or Visa/Mastercard — secure checkout by Monime'
      : 'Pay in cash when your order arrives';
  IconData get icon =>
      this == PaymentOption.online ? Icons.account_balance_wallet_rounded : Icons.payments_rounded;
  Color get color => this == PaymentOption.online ? const Color(0xFFFF7900) : const Color(0xFF16A34A);

  static PaymentOption fromId(String id) => id == 'online' ? PaymentOption.online : PaymentOption.cashOnDelivery;
}

class Catalog {
  static const categories = <ProductCategory>[
    ProductCategory(id: 'phones', name: 'Phones & Tablets', icon: Icons.smartphone_rounded, image: 'phone.png', color: Color(0xFF0029A8)),
    ProductCategory(id: 'electronics', name: 'Electronics', icon: Icons.tv_rounded, image: 'electronics.png', color: Color(0xFF7C3AED)),
    ProductCategory(id: 'fashion', name: 'Fashion', icon: Icons.checkroom_rounded, image: 'fashion.png', color: Color(0xFFDB2777)),
    ProductCategory(id: 'home', name: 'Home & Furniture', icon: Icons.chair_rounded, image: 'home_furniture.png', color: Color(0xFF0D9488)),
    ProductCategory(id: 'groceries', name: 'Groceries', icon: Icons.shopping_basket_rounded, image: 'groceries.png', color: Color(0xFF16A34A)),
    ProductCategory(id: 'beauty', name: 'Health & Beauty', icon: Icons.spa_rounded, image: 'health_beauty.png', color: Color(0xFFE11D48)),
    ProductCategory(id: 'vehicles', name: 'Vehicles', icon: Icons.directions_car_rounded, image: 'vehicle.png', color: Color(0xFF334155)),
    ProductCategory(id: 'property', name: 'Property', icon: Icons.home_work_rounded, image: 'property.png', color: Color(0xFFB45309)),
    ProductCategory(id: 'agric', name: 'Agriculture', icon: Icons.agriculture_rounded, image: 'agriculture.png', color: Color(0xFF65A30D)),
    ProductCategory(id: 'kids', name: 'Baby & Kids', icon: Icons.child_friendly_rounded, image: 'baby_kids.png', color: Color(0xFF0EA5E9)),
    ProductCategory(id: 'sports', name: 'Sports', icon: Icons.sports_soccer_rounded, image: 'sport.png', color: Color(0xFFFB6401)),
    ProductCategory(id: 'other', name: 'Other', icon: Icons.category_rounded, image: 'others.png', color: Color(0xFF6B7385)),
  ];

  static ProductCategory category(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.last);

  /// Delivery fee per destination town, in Leones (SLE). Keep in sync with
  /// functions/src/catalog.ts.
  static const deliveryFees = <String, double>{
    'Freetown': 40,
    'Waterloo': 50,
    'Lunsar': 80,
    'Port Loko': 85,
    'Makeni': 90,
    'Magburaka': 95,
    'Bo': 100,
    'Moyamba': 100,
    'Kambia': 100,
    'Kenema': 120,
    'Pujehun': 130,
    'Koidu': 140,
    'Kabala': 140,
    'Bonthe': 150,
    'Kailahun': 150,
  };

  static List<String> get cities => deliveryFees.keys.toList();
  static double deliveryFee(String city) => deliveryFees[city] ?? 150.0;
  static String safeCity(String? c) => (c != null && deliveryFees.containsKey(c)) ? c : 'Freetown';

  static const conditions = ['New', 'Used', 'Refurbished'];

  static List<PaymentOption> get paymentOptions => const [PaymentOption.online, PaymentOption.cashOnDelivery];
}
