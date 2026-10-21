import 'package:flutter/material.dart';
import '../models/models.dart';

class ProductCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  const ProductCategory({required this.id, required this.name, required this.icon, required this.color});
}

class PaymentMethod {
  final String id;
  final String name;
  final String hint;
  final IconData icon;
  final Color color;
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.hint,
    required this.icon,
    required this.color,
  });
}

class SeedData {
  static const categories = <ProductCategory>[
    ProductCategory(id: 'phones', name: 'Phones & Tablets', icon: Icons.smartphone_rounded, color: Color(0xFF0029A8)),
    ProductCategory(id: 'electronics', name: 'Electronics', icon: Icons.tv_rounded, color: Color(0xFF7C3AED)),
    ProductCategory(id: 'fashion', name: 'Fashion', icon: Icons.checkroom_rounded, color: Color(0xFFDB2777)),
    ProductCategory(id: 'home', name: 'Home & Furniture', icon: Icons.chair_rounded, color: Color(0xFF0D9488)),
    ProductCategory(id: 'groceries', name: 'Groceries', icon: Icons.shopping_basket_rounded, color: Color(0xFF16A34A)),
    ProductCategory(id: 'beauty', name: 'Health & Beauty', icon: Icons.spa_rounded, color: Color(0xFFE11D48)),
    ProductCategory(id: 'vehicles', name: 'Vehicles', icon: Icons.directions_car_rounded, color: Color(0xFF334155)),
    ProductCategory(id: 'property', name: 'Property', icon: Icons.home_work_rounded, color: Color(0xFFB45309)),
    ProductCategory(id: 'agric', name: 'Agriculture', icon: Icons.agriculture_rounded, color: Color(0xFF65A30D)),
    ProductCategory(id: 'kids', name: 'Baby & Kids', icon: Icons.child_friendly_rounded, color: Color(0xFF0EA5E9)),
    ProductCategory(id: 'sports', name: 'Sports', icon: Icons.sports_soccer_rounded, color: Color(0xFFFB6401)),
    ProductCategory(id: 'other', name: 'Other', icon: Icons.category_rounded, color: Color(0xFF6B7385)),
  ];

  static ProductCategory category(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.last);

  /// Cities and towns across the 5 regions, with delivery fees in Leones.
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
    'Koidu': 140,
    'Kabala': 140,
    'Pujehun': 130,
    'Bonthe': 150,
    'Kailahun': 150,
  };

  static List<String> get cities => deliveryFees.keys.toList();

  static const paymentMethods = <PaymentMethod>[
    PaymentMethod(
      id: 'orange',
      name: 'Orange Money',
      hint: 'Pay with your Orange Money wallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFFF7900),
    ),
    PaymentMethod(
      id: 'afrimoney',
      name: 'Afrimoney (Africell)',
      hint: 'Pay with your Africell Afrimoney wallet',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF8E24AA),
    ),
    PaymentMethod(
      id: 'card',
      name: 'Debit / Credit Card',
      hint: 'Visa or Mastercard',
      icon: Icons.credit_card_rounded,
      color: Color(0xFF0029A8),
    ),
    PaymentMethod(
      id: 'cod',
      name: 'Cash on Delivery',
      hint: 'Pay in cash when your order arrives',
      icon: Icons.payments_rounded,
      color: Color(0xFF16A34A),
    ),
  ];

  static PaymentMethod payment(String id) =>
      paymentMethods.firstWhere((p) => p.id == id, orElse: () => paymentMethods.last);

  static const banners = [
    ('Mega Sale', 'Up to 30% off phones', 'phones'),
    ('Wear Gara with pride', 'Handmade Sierra Leone fabrics', 'fashion'),
    ('Farm fresh', 'Rice, palm oil & more from local farms', 'groceries'),
  ];

  // ---- Demo sellers -----------------------------------------------------------
  static final sellers = <AppUser>[
    AppUser(
      id: 'seller_kamara',
      name: 'Kamara Electronics',
      phone: '+232 76 123456',
      email: 'kamara@jdmart.sl',
      password: 'seller123',
      city: 'Freetown',
      bio: 'Trusted phones & electronics dealer on Siaka Stevens Street since 2015.',
      verified: true,
      joinedAt: DateTime(2024, 2, 10),
    ),
    AppUser(
      id: 'seller_fatu',
      name: "Mama Fatu's Gara",
      phone: '+232 77 334455',
      email: 'fatu@jdmart.sl',
      password: 'seller123',
      city: 'Freetown',
      bio: 'Hand-dyed Gara and country cloth made in Sierra Leone.',
      verified: true,
      joinedAt: DateTime(2024, 5, 3),
    ),
    AppUser(
      id: 'seller_bofarms',
      name: 'Bo City Farms',
      phone: '+232 78 556677',
      email: 'bofarms@jdmart.sl',
      password: 'seller123',
      city: 'Bo',
      bio: 'Local rice, palm oil and fresh produce straight from the farm.',
      verified: true,
      joinedAt: DateTime(2024, 8, 21),
    ),
    AppUser(
      id: 'seller_kenema',
      name: 'Kenema Home Centre',
      phone: '+232 79 889900',
      email: 'khc@jdmart.sl',
      password: 'seller123',
      city: 'Kenema',
      bio: 'Furniture, solar and home essentials. Delivery nationwide.',
      joinedAt: DateTime(2025, 1, 14),
    ),
    AppUser(
      id: 'seller_makeni',
      name: 'Makeni Motors',
      phone: '+232 30 445566',
      email: 'motors@jdmart.sl',
      password: 'seller123',
      city: 'Makeni',
      bio: 'Quality used cars and motorbikes with papers.',
      joinedAt: DateTime(2025, 3, 2),
    ),
  ];

  static AppUser _s(String id) => sellers.firstWhere((s) => s.id == id);

  static Product _p(
    String id,
    String title,
    String desc,
    double price,
    String cat,
    String sellerId, {
    double? old,
    String condition = 'New',
    int stock = 10,
    bool negotiable = false,
    bool featured = false,
    int views = 0,
    int daysAgo = 1,
    List<Review>? reviews,
  }) {
    final s = _s(sellerId);
    return Product(
      id: id,
      title: title,
      description: desc,
      price: price,
      oldPrice: old,
      categoryId: cat,
      condition: condition,
      sellerId: s.id,
      sellerName: s.name,
      sellerPhone: s.phone,
      city: s.city,
      stock: stock,
      negotiable: negotiable,
      featured: featured,
      views: views,
      reviews: reviews,
      createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );
  }

  static List<Product> products() => [
        _p('p1', 'Tecno Spark 20 Pro 256GB',
            '6.78" FHD display, 108MP camera, 5000mAh battery with 33W fast charging. Dual SIM — works with Orange, Africell and Qcell. 1 year warranty.',
            3850, 'phones', 'seller_kamara',
            old: 4300, featured: true, views: 412, stock: 14,
            reviews: [
              Review(userName: 'Ibrahim S.', rating: 5, comment: 'Original phone, delivered to Lumley the same day.'),
              Review(userName: 'Aminata K.', rating: 4, comment: 'Battery lasts all day. Good price.'),
            ]),
        _p('p2', 'Samsung Galaxy A15 128GB',
            'Super AMOLED display, 50MP triple camera, 5000mAh. Brand new, sealed box.',
            4600, 'phones', 'seller_kamara',
            old: 4950, views: 238, daysAgo: 2,
            reviews: [Review(userName: 'Mohamed B.', rating: 5, comment: 'Seller is honest. Recommended.')]),
        _p('p3', 'iPhone 12 64GB (UK used)',
            'Clean UK-used iPhone 12, battery health 87%. Face ID working, no scratches. Comes with charger.',
            7900, 'phones', 'seller_kamara',
            condition: 'Used', negotiable: true, stock: 2, views: 520, daysAgo: 3),
        _p('p4', 'HP 15 Laptop Core i5, 8GB RAM, 512GB SSD',
            '11th Gen Intel Core i5, 15.6" display, Windows 11. Perfect for students at FBC and Njala.',
            11500, 'electronics', 'seller_kamara',
            old: 12800, featured: true, stock: 5, views: 301),
        _p('p5', '200W Solar Panel + 100Ah Battery Kit',
            'Keep the lights on through EDSA outages. Includes panel, inverter, battery and cables. Free installation in Kenema.',
            6400, 'electronics', 'seller_kenema',
            old: 7200, featured: true, stock: 6, views: 288,
            reviews: [Review(userName: 'Foday T.', rating: 5, comment: 'Powers my shop fridge at night. Excellent!')]),
        _p('p6', 'Firman 3.5kVA Generator',
            'Petrol generator with key start. Low fuel consumption. 6 months warranty.',
            8200, 'electronics', 'seller_kenema',
            stock: 3, views: 144, daysAgo: 5),
        _p('p7', 'Hand-dyed Gara Fabric (6 yards)',
            'Authentic Sierra Leone Gara (tie-dye) cotton fabric, hand-made in Freetown. Colour-fast. Many patterns available — message us.',
            450, 'fashion', 'seller_fatu',
            featured: true, stock: 40, views: 376,
            reviews: [
              Review(userName: 'Hawa J.', rating: 5, comment: 'Beautiful colours, my tailor loved it.'),
              Review(userName: 'Sarah M.', rating: 5, comment: 'Sent to my sister in Bo, arrived in 2 days.'),
            ]),
        _p('p8', 'Handwoven Country Cloth',
            'Traditional handwoven country cloth, perfect for ceremonies, gowns and decor.',
            900, 'fashion', 'seller_fatu',
            stock: 12, views: 120, daysAgo: 4),
        _p('p9', "Women's Ankara Maxi Dress",
            'Tailored Ankara maxi dress, sizes S–XXL. Custom sizing available in 3 days.',
            520, 'fashion', 'seller_fatu',
            old: 650, stock: 20, views: 210, daysAgo: 2),
        _p('p10', "Men's Embroidered Kaftan",
            'Elegant embroidered kaftan for Friday prayers, weddings and events.',
            600, 'fashion', 'seller_fatu',
            stock: 15, views: 95, daysAgo: 6),
        _p('p11', 'Local Rice — 50kg Bag',
            'Clean, stone-free local rice from farms around Bo. Delivery available nationwide.',
            1150, 'groceries', 'seller_bofarms',
            old: 1250, featured: true, stock: 100, views: 640,
            reviews: [Review(userName: 'Alhaji K.', rating: 4, comment: 'Good quality rice, cooks nicely.')]),
        _p('p12', 'Red Palm Oil — 5 Litres',
            'Pure, fresh red palm oil. No additives. Bottled in Bo.',
            210, 'groceries', 'seller_bofarms',
            stock: 80, views: 330),
        _p('p13', 'Groundnuts — 1 Bucket',
            'Freshly harvested, sun-dried groundnuts.',
            180, 'groceries', 'seller_bofarms',
            stock: 50, views: 87, daysAgo: 3),
        _p('p14', 'Fresh Cassava Leaves (Bundle)',
            'Fresh pounded cassava leaves ready to cook. Order before 10am for same-day delivery in Bo.',
            25, 'groceries', 'seller_bofarms',
            stock: 60, views: 66),
        _p('p15', 'Raw Shea Butter (500g)',
            'Unrefined shea butter for skin and hair. Natural and chemical-free.',
            120, 'beauty', 'seller_fatu',
            stock: 35, views: 74, daysAgo: 7),
        _p('p16', 'African Black Soap (Pack of 3)',
            'Traditional black soap, gentle on skin.',
            60, 'beauty', 'seller_fatu',
            stock: 50, views: 41),
        _p('p17', '7-Seater L-Shaped Sofa',
            'Comfortable fabric sofa set. Made by local carpenters in Kenema with hardwood frame.',
            9800, 'home', 'seller_kenema',
            old: 11000, stock: 2, views: 156, daysAgo: 8),
        _p('p18', 'Vitafoam Orthopaedic Mattress 6x6',
            'High density orthopaedic mattress with 5 years warranty.',
            2700, 'home', 'seller_kenema',
            stock: 7, views: 99),
        _p('p19', 'Honda Ace 125 Motorbike',
            'Strong and fuel-efficient. Perfect for okada business. Full papers.',
            22000, 'vehicles', 'seller_makeni',
            negotiable: true, stock: 3, views: 455, featured: true),
        _p('p20', 'Toyota RAV4 2010 — Automatic',
            'Clean RAV4, 2.4L, foreign used, AC working perfectly. Registered.',
            185000, 'vehicles', 'seller_makeni',
            condition: 'Used', negotiable: true, stock: 1, views: 802, daysAgo: 10),
        _p('p21', '2 Bedroom Apartment — Wilberforce (per month)',
            'Self-contained 2 bedroom apartment with running water, security and parking. 1 year advance.',
            6000, 'property', 'seller_makeni',
            negotiable: true, stock: 1, views: 610, daysAgo: 4),
        _p('p22', 'Dried Cocoa Beans — 50kg',
            'Grade A cocoa beans from Kailahun district.',
            4200, 'agric', 'seller_bofarms',
            stock: 20, views: 132, daysAgo: 5),
        _p('p23', 'Baby Diapers — Size 3 (64 pcs)',
            'Soft, leak-proof diapers for 6–11kg babies.',
            210, 'kids', 'seller_kenema',
            stock: 40, views: 58),
        _p('p24', 'Sierra Leone Supporters Jersey',
            'Green, white and blue supporters jersey for match days. All sizes.',
            350, 'sports', 'seller_fatu',
            old: 420, stock: 30, views: 270, featured: true),
      ];
}
