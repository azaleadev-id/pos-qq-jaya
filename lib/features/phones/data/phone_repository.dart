import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class PhoneRepository {
  const PhoneRepository();

  static const _uuid = Uuid();

  Future<List<PhoneStockItem>> fetchPhones({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final response = await ApiClient.getJson('/api/phones$query');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response HP tidak valid.');
    }
    final phones = data['phones'];
    if (phones is! List) {
      throw const ApiException('Data HP tidak valid.');
    }
    return phones
        .whereType<Map<String, dynamic>>()
        .map(PhoneStockItem.fromJson)
        .toList();
  }

  Future<PhoneStockItem> fetchPhone(String id) async {
    final response = await ApiClient.getJson('/api/phones/$id');
    return _phoneFromResponse(response, 'Response detail HP tidak valid.');
  }

  Future<PhoneStockItem> createPurchase({
    required String imei,
    required String deviceName,
    required int purchasePrice,
    required int? targetSellingPrice,
    required String condition,
    required String sellerName,
    required String notes,
  }) async {
    final response = await ApiClient.postJson(
      '/api/phones/purchases',
      data: {
        'id': _uuid.v4(),
        if (imei.trim().isNotEmpty) 'phone_code': imei.trim(),
        'device_name': deviceName,
        'purchase_price': purchasePrice,
        'selling_price': ?targetSellingPrice,
        if (condition.trim().isNotEmpty) 'condition_notes': condition.trim(),
        if (sellerName.trim().isNotEmpty) 'seller_name': sellerName.trim(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return _phoneFromResponse(response, 'Response beli HP tidak valid.');
  }

  Future<PhoneStockItem> updatePhone({
    required String id,
    required String imei,
    required String deviceName,
    required int purchasePrice,
    required int? targetSellingPrice,
    required String condition,
    required String sellerName,
    required String notes,
  }) async {
    final response = await ApiClient.patchJson(
      '/api/phones/$id',
      data: {
        'phone_code': imei.trim(),
        'device_name': deviceName,
        'purchase_price': purchasePrice,
        'selling_price': targetSellingPrice,
        'condition_notes': condition.trim(),
        'seller_name': sellerName.trim(),
        'notes': notes.trim(),
      },
    );
    return _phoneFromResponse(response, 'Response edit HP tidak valid.');
  }

  Future<PhoneStockItem> sellPhone({
    required String id,
    required int sellingPrice,
    required String buyerName,
  }) async {
    final response = await ApiClient.postJson(
      '/api/phones/$id/sell',
      data: {
        'selling_price': sellingPrice,
        'payment_method': 'cash',
        if (buyerName.trim().isNotEmpty) 'source_name': buyerName.trim(),
      },
    );
    return _phoneFromResponse(response, 'Response jual HP tidak valid.');
  }

  Future<PhoneStockItem> createDirectSale({
    required String imei,
    required String deviceName,
    required int purchasePrice,
    required int sellingPrice,
    required String condition,
    required String buyerName,
    required String notes,
  }) async {
    final response = await ApiClient.postJson(
      '/api/phones/direct-sale',
      data: {
        'id': _uuid.v4(),
        if (imei.trim().isNotEmpty) 'phone_code': imei.trim(),
        'device_name': deviceName.trim(),
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'payment_method': 'cash',
        if (condition.trim().isNotEmpty) 'condition_notes': condition.trim(),
        if (buyerName.trim().isNotEmpty) 'source_name': buyerName.trim(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return _phoneFromResponse(
      response,
      'Response jual HP langsung tidak valid.',
    );
  }

  PhoneStockItem _phoneFromResponse(
    Map<String, dynamic> response,
    String errorMessage,
  ) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(errorMessage);
    }
    final phone = data['phone'];
    if (phone is! Map<String, dynamic>) {
      throw ApiException(errorMessage);
    }
    return PhoneStockItem.fromJson(phone);
  }
}

enum PhoneStatus {
  available('available', 'Tersedia'),
  sold('sold', 'Terjual');

  const PhoneStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PhoneStatus fromApi(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'sold' ? PhoneStatus.sold : PhoneStatus.available;
  }
}

class PhoneStockItem {
  const PhoneStockItem({
    required this.id,
    required this.phoneCode,
    required this.deviceName,
    required this.status,
    required this.purchasePrice,
    required this.targetOrSellingPrice,
    required this.profit,
    required this.condition,
    required this.sellerName,
    required this.buyerName,
    required this.notes,
    required this.purchaseDate,
    required this.saleDate,
  });

  final String id;
  final String phoneCode;
  final String deviceName;
  final PhoneStatus status;
  final int purchasePrice;
  final int? targetOrSellingPrice;
  final int? profit;
  final String condition;
  final String sellerName;
  final String buyerName;
  final String notes;
  final DateTime purchaseDate;
  final DateTime? saleDate;

  bool get isSold => status == PhoneStatus.sold;
  int? get potentialProfit => targetOrSellingPrice == null
      ? null
      : targetOrSellingPrice! - purchasePrice;
  int get actualProfit => profit ?? (targetOrSellingPrice ?? 0) - purchasePrice;
  DateTime get historyDate => saleDate ?? purchaseDate;

  factory PhoneStockItem.fromJson(Map<String, dynamic> json) {
    final saleDateText = json['sale_date']?.toString().trim() ?? '';
    return PhoneStockItem(
      id: json['id']?.toString() ?? '',
      phoneCode: json['phone_code']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      status: PhoneStatus.fromApi(json['phone_status']),
      purchasePrice: parseMoney(json['purchase_price']),
      targetOrSellingPrice: json['selling_price'] == null
          ? null
          : parseMoney(json['selling_price']),
      profit: json['profit'] == null ? null : parseMoney(json['profit']),
      condition: json['condition_notes']?.toString() ?? '',
      sellerName: json['seller_name']?.toString() ?? '',
      buyerName: json['source_name']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      purchaseDate: parseBackendDateTime(json['purchase_date']),
      saleDate: saleDateText.isEmpty
          ? null
          : parseBackendDateTime(saleDateText),
    );
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return phoneCode.toLowerCase().contains(normalized) ||
        deviceName.toLowerCase().contains(normalized) ||
        sellerName.toLowerCase().contains(normalized) ||
        buyerName.toLowerCase().contains(normalized) ||
        notes.toLowerCase().contains(normalized);
  }
}
