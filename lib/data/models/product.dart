import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/catalog.dart';
import '../../core/utils/keywords.dart';
import 'firestore_helpers.dart';

enum ProductStatus { active, sold, hidden }

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? oldPrice;
  final String categoryId;
  final String condition;
  final List<String> images; // download URLs from Firebase Storage
  final String sellerId;
  final String sellerName;
  final bool sellerVerified;
  final String city;
  final int stock;
  final bool negotiable;
  final ProductStatus status;
  final bool featured; // set by admins only
  final int views;
  final double ratingAvg;
  final int ratingCount;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.categoryId,
    required this.condition,
    required this.images,
    required this.sellerId,
    required this.sellerName,
    this.sellerVerified = false,
    required this.city,
    required this.stock,
    this.negotiable = false,
    this.status = ProductStatus.active,
    this.featured = false,
    this.views = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    required this.createdAt,
  });

  bool get isSold => status == ProductStatus.sold || stock <= 0;
  bool get available => status == ProductStatus.active && stock > 0;
  String? get cover => images.isEmpty ? null : images.first;

  int get discountPercent => discountOf(price, oldPrice);

  static int discountOf(double price, double? oldPrice) =>
      (oldPrice == null || oldPrice <= price) ? 0 : (((oldPrice - price) / oldPrice) * 100).round();

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Product(
      id: doc.id,
      title: (j['title'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      price: toDouble(j['price']),
      oldPrice: j['oldPrice'] == null ? null : toDouble(j['oldPrice']),
      categoryId: (j['categoryId'] ?? 'other') as String,
      condition: (j['condition'] ?? 'New') as String,
      images: toStringList(j['images']),
      sellerId: (j['sellerId'] ?? '') as String,
      sellerName: (j['sellerName'] ?? '') as String,
      sellerVerified: j['sellerVerified'] == true,
      city: (j['city'] ?? 'Freetown') as String,
      stock: toInt(j['stock']),
      negotiable: j['negotiable'] == true,
      status: ProductStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => ProductStatus.hidden),
      featured: j['featured'] == true,
      views: toInt(j['views']),
      ratingAvg: toDouble(j['ratingAvg']),
      ratingCount: toInt(j['ratingCount']),
      createdAt: tsToDate(j['createdAt']),
    );
  }
}

/// What a seller fills in on the Sell form. Converted to a Firestore map by
/// [ProductRepository]; server-owned fields (views, ratings, featured) are never sent.
class ProductDraft {
  String title;
  String description;
  double price;
  double? oldPrice;
  String categoryId;
  String condition;
  String city;
  int stock;
  bool negotiable;
  List<String> images; // existing URLs (new photos are uploaded first)

  ProductDraft({
    required this.title,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.categoryId,
    required this.condition,
    required this.city,
    required this.stock,
    required this.negotiable,
    required this.images,
  });

  Map<String, dynamic> toMap() {
    final old = (oldPrice != null && oldPrice! > price) ? oldPrice : null;
    return {
      'title': title.trim(),
      'description': description.trim(),
      'price': price,
      'oldPrice': old,
      'discountPercent': Product.discountOf(price, old),
      'categoryId': categoryId,
      'condition': condition,
      'city': city,
      'stock': stock,
      'negotiable': negotiable,
      'images': images,
      'keywords': Keywords.build([title, Catalog.category(categoryId).name, condition, city]),
    };
  }
}
