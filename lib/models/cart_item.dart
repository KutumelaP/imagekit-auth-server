class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String sellerId; // Store ID for database queries
  final String sellerName; // Store name for display
  final String storeCategory; // Store category (Food, Clothing, etc.)
  final DateTime addedAt;
  final int? availableStock; // Available stock for this product (null = unlimited)
  
  // Customization fields
  final List<Map<String, dynamic>>? customizations;
  final double? customPrice; // Calculated price with customizations
  // Optional per-product prep time in minutes
  final int? prepTimeMinutes;
  final bool? madeToOrder;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.sellerId,
    required this.sellerName,
    required this.storeCategory,
    DateTime? addedAt,
    this.availableStock,
    this.customizations,
    this.customPrice,
    this.prepTimeMinutes,
    this.madeToOrder,
  }) : addedAt = addedAt ?? DateTime.now();

  // Get final price (custom price if available, otherwise base price)
  double get finalPrice => customPrice ?? price;

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? sellerId,
    String? sellerName,
    String? storeCategory,
    DateTime? addedAt,
    int? availableStock,
    List<Map<String, dynamic>>? customizations,
    double? customPrice,
    int? prepTimeMinutes,
    bool? madeToOrder,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      storeCategory: storeCategory ?? this.storeCategory,
      addedAt: addedAt ?? this.addedAt,
      availableStock: availableStock ?? this.availableStock,
      customizations: customizations ?? this.customizations,
      customPrice: customPrice ?? this.customPrice,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      madeToOrder: madeToOrder ?? this.madeToOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'storeCategory': storeCategory,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'availableStock': availableStock,
      'customizations': customizations,
      'customPrice': customPrice,
      'prepTimeMinutes': prepTimeMinutes,
      'madeToOrder': madeToOrder,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      storeCategory: map['storeCategory'] ?? '',
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] ?? 0),
      availableStock: map['availableStock'],
      customizations: map['customizations'] != null 
          ? List<Map<String, dynamic>>.from(map['customizations'])
          : null,
      customPrice: map['customPrice']?.toDouble(),
      prepTimeMinutes: (map['prepTimeMinutes'] is num) ? (map['prepTimeMinutes'] as num).toInt() : int.tryParse('${map['prepTimeMinutes'] ?? ''}'),
      madeToOrder: map['madeToOrder'] as bool?,
    );
  }

  @override
  String toString() {
    return 'CartItem(id: $id, name: $name, price: $price, quantity: $quantity, imageUrl: $imageUrl, sellerId: $sellerId, sellerName: $sellerName, storeCategory: $storeCategory, addedAt: $addedAt, availableStock: $availableStock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.id == id &&
        other.name == name &&
        other.price == price &&
        other.quantity == quantity &&
        other.imageUrl == imageUrl &&
        other.sellerId == sellerId &&
        other.sellerName == sellerName &&
        other.storeCategory == storeCategory &&
        other.addedAt == addedAt &&
        other.availableStock == availableStock;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        price.hashCode ^
        quantity.hashCode ^
        imageUrl.hashCode ^
        sellerId.hashCode ^
        sellerName.hashCode ^
        storeCategory.hashCode ^
        addedAt.hashCode ^
        (availableStock?.hashCode ?? 0);
  }
} 