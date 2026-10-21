import 'product.dart';

/// A cart line kept on the device. It stores a snapshot of the product so the
/// cart renders offline; prices are refreshed from Firestore when the cart opens
/// and recalculated by the server at checkout.
class CartItem {
  final String productId;
  int quantity;
  String title;
  double price;
  double? oldPrice;
  String? image;
  String categoryId;
  String sellerId;
  String sellerName;
  int stock;
  bool available;

  CartItem({
    required this.productId,
    required this.quantity,
    required this.title,
    required this.price,
    this.oldPrice,
    this.image,
    required this.categoryId,
    required this.sellerId,
    required this.sellerName,
    required this.stock,
    this.available = true,
  });

  factory CartItem.fromProduct(Product p, int qty) => CartItem(
        productId: p.id,
        quantity: qty,
        title: p.title,
        price: p.price,
        oldPrice: p.oldPrice,
        image: p.cover,
        categoryId: p.categoryId,
        sellerId: p.sellerId,
        sellerName: p.sellerName,
        stock: p.stock,
        available: p.available,
      );

  void refreshFrom(Product p) {
    title = p.title;
    price = p.price;
    oldPrice = p.oldPrice;
    image = p.cover;
    stock = p.stock;
    available = p.available;
    if (quantity > stock && stock > 0) quantity = stock;
  }

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'title': title,
        'price': price,
        'oldPrice': oldPrice,
        'image': image,
        'categoryId': categoryId,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'stock': stock,
        'available': available,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: j['productId'] as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        title: (j['title'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        oldPrice: (j['oldPrice'] as num?)?.toDouble(),
        image: j['image'] as String?,
        categoryId: (j['categoryId'] ?? 'other') as String,
        sellerId: (j['sellerId'] ?? '') as String,
        sellerName: (j['sellerName'] ?? '') as String,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
        available: j['available'] != false,
      );
}
