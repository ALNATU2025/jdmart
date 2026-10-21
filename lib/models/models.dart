// Core data models for JDMart. Each model serialises to JSON so it can be
// persisted locally (shared_preferences) or sent to a backend (Firebase, REST).

class AppUser {
  final String id;
  String name;
  String phone;
  String email;
  String password; // Demo only — a real backend must never store raw passwords.
  String city;
  String bio;
  String? avatarPath;
  final DateTime joinedAt;
  bool verified;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    required this.city,
    this.bio = '',
    this.avatarPath,
    DateTime? joinedAt,
    this.verified = false,
  }) : joinedAt = joinedAt ?? DateTime.now();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'city': city,
        'bio': bio,
        'avatarPath': avatarPath,
        'joinedAt': joinedAt.toIso8601String(),
        'verified': verified,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        phone: j['phone'],
        email: j['email'] ?? '',
        password: j['password'] ?? '',
        city: j['city'] ?? 'Freetown',
        bio: j['bio'] ?? '',
        avatarPath: j['avatarPath'],
        joinedAt: DateTime.tryParse(j['joinedAt'] ?? ''),
        verified: j['verified'] ?? false,
      );
}

class Review {
  final String userName;
  final int rating;
  final String comment;
  final DateTime at;

  Review({required this.userName, required this.rating, required this.comment, DateTime? at})
      : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'userName': userName, 'rating': rating, 'comment': comment, 'at': at.toIso8601String()};

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        userName: j['userName'],
        rating: j['rating'],
        comment: j['comment'],
        at: DateTime.tryParse(j['at'] ?? ''),
      );
}

class Product {
  final String id;
  String title;
  String description;
  double price;
  double? oldPrice;
  String categoryId;
  String condition; // 'New' | 'Used' | 'Refurbished'
  List<String> images; // local file paths or network URLs; empty -> category artwork
  final String sellerId;
  String sellerName;
  String sellerPhone;
  String city;
  int stock;
  bool negotiable;
  bool isSold;
  bool featured;
  int views;
  List<Review> reviews;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.categoryId,
    this.condition = 'New',
    List<String>? images,
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhone,
    required this.city,
    this.stock = 1,
    this.negotiable = false,
    this.isSold = false,
    this.featured = false,
    this.views = 0,
    List<Review>? reviews,
    DateTime? createdAt,
  })  : images = images ?? [],
        reviews = reviews ?? [],
        createdAt = createdAt ?? DateTime.now();

  double get rating =>
      reviews.isEmpty ? 0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

  int get discountPercent =>
      (oldPrice == null || oldPrice! <= price) ? 0 : (((oldPrice! - price) / oldPrice!) * 100).round();

  bool get available => !isSold && stock > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'price': price,
        'oldPrice': oldPrice,
        'categoryId': categoryId,
        'condition': condition,
        'images': images,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerPhone': sellerPhone,
        'city': city,
        'stock': stock,
        'negotiable': negotiable,
        'isSold': isSold,
        'featured': featured,
        'views': views,
        'reviews': reviews.map((r) => r.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        price: (j['price'] as num).toDouble(),
        oldPrice: (j['oldPrice'] as num?)?.toDouble(),
        categoryId: j['categoryId'],
        condition: j['condition'] ?? 'New',
        images: List<String>.from(j['images'] ?? const []),
        sellerId: j['sellerId'],
        sellerName: j['sellerName'] ?? '',
        sellerPhone: j['sellerPhone'] ?? '',
        city: j['city'] ?? 'Freetown',
        stock: j['stock'] ?? 1,
        negotiable: j['negotiable'] ?? false,
        isSold: j['isSold'] ?? false,
        featured: j['featured'] ?? false,
        views: j['views'] ?? 0,
        reviews: ((j['reviews'] as List?) ?? const [])
            .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );
}

class CartItem {
  final String productId;
  int quantity;
  CartItem({required this.productId, this.quantity = 1});

  Map<String, dynamic> toJson() => {'productId': productId, 'quantity': quantity};
  factory CartItem.fromJson(Map<String, dynamic> j) =>
      CartItem(productId: j['productId'], quantity: j['quantity'] ?? 1);
}

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.shipped => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };
}

class OrderItem {
  final String productId;
  final String title;
  final double price;
  final int quantity;
  final String sellerId;
  final String sellerName;
  final String categoryId;
  final String? image;

  OrderItem({
    required this.productId,
    required this.title,
    required this.price,
    required this.quantity,
    required this.sellerId,
    required this.sellerName,
    required this.categoryId,
    this.image,
  });

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'title': title,
        'price': price,
        'quantity': quantity,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'categoryId': categoryId,
        'image': image,
      };

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productId: j['productId'],
        title: j['title'],
        price: (j['price'] as num).toDouble(),
        quantity: j['quantity'],
        sellerId: j['sellerId'],
        sellerName: j['sellerName'] ?? '',
        categoryId: j['categoryId'] ?? 'other',
        image: j['image'],
      );
}

class Order {
  final String id;
  final String buyerId;
  final String buyerName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final String paymentMethod;
  final String address;
  final String city;
  final String phone;
  final String note;
  OrderStatus status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.paymentMethod,
    required this.address,
    required this.city,
    required this.phone,
    this.note = '',
    this.status = OrderStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get total => subtotal + deliveryFee;
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'paymentMethod': paymentMethod,
        'address': address,
        'city': city,
        'phone': phone,
        'note': note,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        buyerId: j['buyerId'],
        buyerName: j['buyerName'] ?? '',
        items: (j['items'] as List).map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        subtotal: (j['subtotal'] as num).toDouble(),
        deliveryFee: (j['deliveryFee'] as num).toDouble(),
        paymentMethod: j['paymentMethod'],
        address: j['address'],
        city: j['city'],
        phone: j['phone'],
        note: j['note'] ?? '',
        status: OrderStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => OrderStatus.pending),
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );
}

class ChatMessage {
  final String senderId;
  final String text;
  final DateTime at;
  ChatMessage({required this.senderId, required this.text, DateTime? at}) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {'senderId': senderId, 'text': text, 'at': at.toIso8601String()};
  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(senderId: j['senderId'], text: j['text'], at: DateTime.tryParse(j['at'] ?? ''));
}

class Conversation {
  final String id;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String productId;
  final String productTitle;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productTitle,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  DateTime get lastAt => messages.isEmpty ? DateTime(2000) : messages.last.at;
  String otherName(String myId) => myId == buyerId ? sellerName : buyerName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'productId': productId,
        'productTitle': productTitle,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        buyerId: j['buyerId'],
        buyerName: j['buyerName'] ?? '',
        sellerId: j['sellerId'],
        sellerName: j['sellerName'] ?? '',
        productId: j['productId'],
        productTitle: j['productTitle'] ?? '',
        messages: ((j['messages'] as List?) ?? const [])
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
