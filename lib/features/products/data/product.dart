class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    required this.category,
  });

  final String id;
  final String name;
  final String barcode;
  final int costPrice;
  final int sellingPrice;
  final int stock;
  final String category;

  int get profitPerUnit => sellingPrice - costPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      costPrice: _parseMoney(json['cost_price']),
      sellingPrice: _parseMoney(json['selling_price']),
      stock: _parseInt(json['stock_quantity']),
      category: json['category']?.toString() ?? 'Barang',
    );
  }

  Map<String, dynamic> toApiPayload() {
    return {
      'name': name,
      'category': category,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'track_stock': true,
      'stock_quantity': stock,
      'minimum_stock': 3,
      'unit': 'pcs',
      'barcode': barcode.trim().isEmpty ? null : barcode.trim(),
      'qr_code': null,
      'is_active': true,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    int? costPrice,
    int? sellingPrice,
    int? stock,
    String? category,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
    );
  }
}

int _parseMoney(Object? value) {
  if (value is num) {
    return value.round();
  }
  return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
}

int _parseInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
