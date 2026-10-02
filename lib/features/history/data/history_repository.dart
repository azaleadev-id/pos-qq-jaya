import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../expenses/data/expense_repository.dart';
import '../../phones/data/phone_repository.dart';
import '../../services/data/service_repository.dart';

class HistoryRepository {
  const HistoryRepository();

  static const _serviceRepository = ServiceRepository();
  static const _phoneRepository = PhoneRepository();
  static const _expenseRepository = ExpenseRepository();

  Future<List<HistoryItem>> fetchHistoryItems() async {
    final results = await Future.wait([
      fetchSales(),
      _serviceRepository.fetchServices(),
      _phoneRepository.fetchPhones(),
      _expenseRepository.fetchExpenses(),
    ]);
    final sales = results[0] as List<SaleSummary>;
    final services = results[1] as List<ServiceJob>;
    final phones = results[2] as List<PhoneStockItem>;
    final expenses = results[3] as List<ExpenseItem>;
    final items = [
      ...sales.map(HistoryItem.sale),
      ...services.map(HistoryItem.service),
      ...phones.map(HistoryItem.phonePurchase),
      ...phones.where((phone) => phone.isSold).map(HistoryItem.phoneSale),
      ...expenses.map(HistoryItem.expense),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<List<SaleSummary>> fetchSales() async {
    final response = await ApiClient.getJson('/api/sales');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response riwayat tidak valid.');
    }

    final sales = data['sales'];
    if (sales is! List) {
      throw const ApiException('Data riwayat tidak valid.');
    }

    return sales
        .whereType<Map<String, dynamic>>()
        .map(SaleSummary.fromJson)
        .toList();
  }

  Future<SaleDetail> fetchSaleDetail(String id) async {
    final response = await ApiClient.getJson('/api/sales/$id');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response detail penjualan tidak valid.');
    }

    return SaleDetail.fromJson(data);
  }
}

enum HistoryType {
  sale('Penjualan'),
  service('Servis'),
  phone('Jual Beli HP'),
  expense('Pengeluaran');

  const HistoryType(this.label);

  final String label;
}

enum HistoryCategory {
  product('Barang'),
  service('Servis'),
  phone('HP'),
  voucher('Voucher'),
  pulsa('Pulsa'),
  dataPackage('Paket Data'),
  expense('Pengeluaran');

  const HistoryCategory(this.label);

  final String label;
}

class HistoryItem {
  const HistoryItem._({
    required this.type,
    required this.category,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reference,
    required this.date,
    required this.amount,
    required this.status,
    required this.sale,
    required this.service,
    required this.phone,
    required this.expense,
  });

  final HistoryType type;
  final HistoryCategory category;
  final String id;
  final String title;
  final String subtitle;
  final String reference;
  final DateTime date;
  final int amount;
  final String status;
  final SaleSummary? sale;
  final ServiceJob? service;
  final PhoneStockItem? phone;
  final ExpenseItem? expense;

  factory HistoryItem.sale(SaleSummary sale) {
    final category = sale.category;
    return HistoryItem._(
      type: HistoryType.sale,
      category: category,
      id: sale.id,
      title: sale.itemNames.isEmpty ? 'Penjualan' : sale.itemNames,
      subtitle: '${sale.itemCount} item',
      reference: sale.transactionNumber,
      date: sale.soldAt,
      amount: sale.total,
      status: 'Untung ${formatRupiah(sale.profit)}',
      sale: sale,
      service: null,
      phone: null,
      expense: null,
    );
  }

  factory HistoryItem.service(ServiceJob service) {
    return HistoryItem._(
      type: HistoryType.service,
      category: HistoryCategory.service,
      id: service.id,
      title: service.deviceName,
      subtitle: service.serviceName,
      reference: service.serviceNumber,
      date: service.receivedAt,
      amount: service.invoiceTotal,
      status: '${service.status.label} - ${service.paymentStatus.label}',
      sale: null,
      service: service,
      phone: null,
      expense: null,
    );
  }

  factory HistoryItem.phonePurchase(PhoneStockItem phone) {
    final target = phone.targetOrSellingPrice;
    return HistoryItem._(
      type: HistoryType.phone,
      category: HistoryCategory.phone,
      id: phone.id,
      title: 'Beli ${phone.deviceName}',
      subtitle: target == null
          ? 'Modal ${formatRupiah(phone.purchasePrice)}'
          : 'Modal ${formatRupiah(phone.purchasePrice)} - Target ${formatRupiah(target)}',
      reference: phone.phoneCode,
      date: phone.purchaseDate,
      amount: phone.purchasePrice,
      status: phone.isSold ? 'Sudah terjual' : 'Masuk stok',
      sale: null,
      service: null,
      phone: phone,
      expense: null,
    );
  }

  factory HistoryItem.phoneSale(PhoneStockItem phone) {
    final profit = phone.actualProfit;
    return HistoryItem._(
      type: HistoryType.phone,
      category: HistoryCategory.phone,
      id: phone.id,
      title: 'Jual ${phone.deviceName}',
      subtitle:
          'Beli ${formatRupiah(phone.purchasePrice)} - Jual ${formatRupiah(phone.targetOrSellingPrice ?? 0)}',
      reference: phone.phoneCode,
      date: phone.historyDate,
      amount: phone.targetOrSellingPrice ?? 0,
      status: profit >= 0
          ? 'Laba ${formatRupiah(profit)}'
          : 'Rugi ${formatRupiah(profit.abs())}',
      sale: null,
      service: null,
      phone: phone,
      expense: null,
    );
  }

  factory HistoryItem.expense(ExpenseItem expense) {
    return HistoryItem._(
      type: HistoryType.expense,
      category: HistoryCategory.expense,
      id: expense.id,
      title: expense.name,
      subtitle: expense.category,
      reference: '',
      date: expense.date,
      amount: expense.amount,
      status: 'Pengeluaran',
      sale: null,
      service: null,
      phone: null,
      expense: expense,
    );
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(normalized) ||
        subtitle.toLowerCase().contains(normalized) ||
        reference.toLowerCase().contains(normalized) ||
        id.toLowerCase().contains(normalized) ||
        status.toLowerCase().contains(normalized) ||
        (service?.matchesQuery(query) ?? false) ||
        (sale?.matchesQuery(query) ?? false) ||
        (phone?.matchesQuery(query) ?? false) ||
        (expense?.matchesQuery(query) ?? false);
  }

  String get displayType => category.label;

  String get amountText {
    if (category == HistoryCategory.expense) {
      return '-${formatRupiah(amount)}';
    }
    return formatRupiah(amount);
  }
}

class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.transactionNumber,
    required this.soldAt,
    required this.total,
    required this.totalCost,
    required this.profit,
    required this.itemCount,
    required this.itemNames,
    required this.itemCategories,
  });

  final String id;
  final String transactionNumber;
  final DateTime soldAt;
  final int total;
  final int totalCost;
  final int profit;
  final int itemCount;
  final String itemNames;
  final String itemCategories;

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: json['id']?.toString() ?? '',
      transactionNumber: json['transaction_number']?.toString() ?? '',
      soldAt: parseBackendDateTime(json['sold_at']),
      total: parseMoney(json['total_amount']),
      totalCost: parseMoney(json['total_cost']),
      profit: parseMoney(json['total_profit']),
      itemCount: parseIntValue(json['item_count']),
      itemNames: json['item_names']?.toString() ?? '',
      itemCategories: json['item_categories']?.toString() ?? '',
    );
  }

  HistoryCategory get category {
    final names = itemNames
        .split(',')
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toList();
    final categories = itemCategories
        .split(',')
        .map((category) => category.trim().toLowerCase())
        .where((category) => category.isNotEmpty)
        .toList();

    if (names.any((name) => name.startsWith('pulsa '))) {
      return HistoryCategory.pulsa;
    }
    if (names.any((name) => name.startsWith('paket data '))) {
      return HistoryCategory.dataPackage;
    }
    if (categories.any((category) => category == 'voucher')) {
      return HistoryCategory.voucher;
    }
    return HistoryCategory.product;
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    return transactionNumber.toLowerCase().contains(normalized) ||
        id.toLowerCase().contains(normalized) ||
        itemNames.toLowerCase().contains(normalized) ||
        itemCategories.toLowerCase().contains(normalized);
  }
}

class SaleDetail {
  const SaleDetail({required this.summary, required this.items});

  final SaleSummary summary;
  final List<SaleItemSnapshot> items;

  factory SaleDetail.fromJson(Map<String, dynamic> json) {
    final sale = json['sale'];
    if (sale is! Map<String, dynamic>) {
      throw const ApiException('Data penjualan tidak valid.');
    }

    final items = json['items'];
    if (items is! List) {
      throw const ApiException('Data item penjualan tidak valid.');
    }

    return SaleDetail(
      summary: SaleSummary.fromJson(sale),
      items: items
          .whereType<Map<String, dynamic>>()
          .map(SaleItemSnapshot.fromJson)
          .toList(),
    );
  }
}

class SaleItemSnapshot {
  const SaleItemSnapshot({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.unitPrice,
    required this.lineCost,
    required this.lineTotal,
    required this.lineProfit,
    required this.productCategory,
  });

  final String id;
  final String saleId;
  final String? productId;
  final String productName;
  final int quantity;
  final int unitCost;
  final int unitPrice;
  final int lineCost;
  final int lineTotal;
  final int lineProfit;
  final String productCategory;

  factory SaleItemSnapshot.fromJson(Map<String, dynamic> json) {
    final productId = json['product_id']?.toString();
    return SaleItemSnapshot(
      id: json['id']?.toString() ?? '',
      saleId: json['sale_id']?.toString() ?? '',
      productId: productId == null || productId.isEmpty ? null : productId,
      productName: json['product_name']?.toString() ?? '',
      quantity: parseIntValue(json['quantity']),
      unitCost: parseMoney(json['unit_cost']),
      unitPrice: parseMoney(json['unit_price']),
      lineCost: parseMoney(json['line_cost']),
      lineTotal: parseMoney(json['line_total']),
      lineProfit: parseMoney(json['line_profit']),
      productCategory: json['product_category']?.toString() ?? '',
    );
  }
}
