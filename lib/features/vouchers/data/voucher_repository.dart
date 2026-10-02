import '../../products/data/product.dart';
import '../../products/data/product_api_repository.dart';
import '../../sales/data/sale_api_repository.dart';

class VoucherRepository {
  const VoucherRepository();

  static const category = 'Voucher';
  static const _productRepository = ProductApiRepository();
  static const _saleRepository = SaleApiRepository();

  Future<List<VoucherItem>> fetchVouchers() async {
    final products = await _productRepository.fetchProducts();
    return products
        .where((product) => product.category == category)
        .map(VoucherItem.fromProduct)
        .toList();
  }

  Future<VoucherItem> createVoucher({
    required String provider,
    required String voucherName,
    required String packageName,
    required String code,
    required int costPrice,
    required int sellingPrice,
    required int quantity,
  }) async {
    final product = Product(
      id: '',
      name: _composeName(provider, voucherName, packageName),
      barcode: code,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      stock: quantity,
      category: category,
    );
    return VoucherItem.fromProduct(
      await _productRepository.createProduct(product),
    );
  }

  Future<SaleSaveResult> sellVoucher({
    required VoucherItem voucher,
    required int quantity,
    required int sellingPrice,
  }) {
    return _saleRepository.createProductSale(
      product: voucher.product,
      quantity: quantity,
      sellingPrice: sellingPrice,
    );
  }

  static String _composeName(String provider, String name, String packageName) {
    return [
      provider.trim(),
      name.trim(),
      packageName.trim(),
    ].where((part) => part.isNotEmpty).join(' - ');
  }
}

class VoucherItem {
  const VoucherItem({
    required this.product,
    required this.provider,
    required this.name,
    required this.packageName,
  });

  final Product product;
  final String provider;
  final String name;
  final String packageName;

  String get id => product.id;
  String get code => product.barcode;
  int get costPrice => product.costPrice;
  int get sellingPrice => product.sellingPrice;
  int get stock => product.stock;
  int get profitPerUnit => product.profitPerUnit;
  String get displayName => [
    provider,
    name,
    packageName,
  ].where((part) => part.trim().isNotEmpty).join(' - ');

  factory VoucherItem.fromProduct(Product product) {
    final parts = product.name.split(' - ');
    return VoucherItem(
      product: product,
      provider: parts.isNotEmpty ? parts[0] : '',
      name: parts.length > 1 ? parts[1] : product.name,
      packageName: parts.length > 2 ? parts.sublist(2).join(' - ') : '',
    );
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return displayName.toLowerCase().contains(normalized) ||
        code.toLowerCase().contains(normalized);
  }
}
