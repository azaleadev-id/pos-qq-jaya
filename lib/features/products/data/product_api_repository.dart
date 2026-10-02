import '../../../core/network/api_client.dart';
import 'product.dart';

class ProductApiRepository {
  const ProductApiRepository();

  Future<List<Product>> fetchProducts() async {
    final response = await ApiClient.getJson('/api/products');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response products tidak valid.');
    }

    final products = data['products'];
    if (products is! List) {
      throw const ApiException('Data products tidak valid.');
    }

    return products
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }

  Future<Product> createProduct(Product product) async {
    final response = await ApiClient.postJson(
      '/api/products',
      data: product.toApiPayload(),
    );
    return _productFromResponse(response);
  }

  Future<Product> updateProduct(Product product) async {
    final response = await ApiClient.putJson(
      '/api/products/${product.id}',
      data: product.toApiPayload(),
    );
    return _productFromResponse(response);
  }

  Future<void> deleteProduct(String id) async {
    await ApiClient.deleteJson('/api/products/$id');
  }

  Product _productFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response product tidak valid.');
    }

    final product = data['product'];
    if (product is! Map<String, dynamic>) {
      throw const ApiException('Data product tidak valid.');
    }

    return Product.fromJson(product);
  }
}
