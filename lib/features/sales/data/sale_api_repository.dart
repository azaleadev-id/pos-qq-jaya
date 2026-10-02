import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../products/data/product.dart';

class SaleApiRepository {
  const SaleApiRepository();

  static const _uuid = Uuid();

  Future<SaleSaveResult> createProductSale({
    required Product product,
    required int quantity,
    required int sellingPrice,
  }) {
    final total = sellingPrice * quantity;
    return _createSale(
      item: {
        'product_id': product.id,
        'quantity': quantity,
        'unit_price': sellingPrice,
      },
      paidAmount: total,
    );
  }

  Future<SaleSaveResult> createManualSale({
    required String productName,
    required int quantity,
    required int costPrice,
    required int sellingPrice,
    String? notes,
  }) {
    final total = sellingPrice * quantity;
    return _createSale(
      item: {
        'product_id': null,
        'product_name': productName,
        'quantity': quantity,
        'unit_cost': costPrice,
        'unit_price': sellingPrice,
      },
      paidAmount: total,
      notes: notes,
    );
  }

  Future<SaleSaveResult> _createSale({
    required Map<String, Object?> item,
    required int paidAmount,
    String? notes,
  }) async {
    final cleanNotes = notes?.trim();
    final response = await ApiClient.postJson(
      '/api/sales',
      data: {
        'id': _uuid.v4(),
        'payment_method': 'cash',
        'paid_amount': paidAmount,
        'items': [item],
        if (cleanNotes != null && cleanNotes.isNotEmpty) 'notes': cleanNotes,
      },
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response penjualan tidak valid.');
    }

    final sale = data['sale'];
    if (sale is! Map<String, dynamic>) {
      throw const ApiException('Data penjualan tidak valid.');
    }

    final items = data['items'];
    return SaleSaveResult(
      saleId: sale['id']?.toString() ?? '',
      transactionNumber: sale['transaction_number']?.toString() ?? '',
      total: parseMoney(sale['total_amount']),
      profit: parseMoney(sale['total_profit']),
      itemCount: items is List ? items.length : 0,
    );
  }
}

class SaleSaveResult {
  const SaleSaveResult({
    required this.saleId,
    required this.transactionNumber,
    required this.total,
    required this.profit,
    required this.itemCount,
  });

  final String saleId;
  final String transactionNumber;
  final int total;
  final int profit;
  final int itemCount;
}
