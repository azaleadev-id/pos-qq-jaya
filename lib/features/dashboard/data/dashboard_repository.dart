import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSnapshot> fetchDashboard() async {
    final response = await ApiClient.getJson('/api/dashboard');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response dashboard tidak valid.');
    }
    return DashboardSnapshot.fromJson(data);
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.summary,
    required this.recentTransactions,
    required this.salesChart,
    required this.lowStockProducts,
  });

  final DashboardSummary summary;
  final List<DashboardTransaction> recentTransactions;
  final List<DashboardChartPoint> salesChart;
  final List<DashboardLowStockProduct> lowStockProducts;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final recent = json['recent_transactions'];
    final chart = json['sales_chart'];
    final lowStock = json['low_stock'];
    return DashboardSnapshot(
      summary: summary is Map<String, dynamic>
          ? DashboardSummary.fromJson(summary)
          : const DashboardSummary.empty(),
      recentTransactions: recent is List
          ? recent
                .whereType<Map<String, dynamic>>()
                .map(DashboardTransaction.fromJson)
                .toList()
          : const [],
      salesChart: chart is List
          ? chart
                .whereType<Map<String, dynamic>>()
                .map(DashboardChartPoint.fromJson)
                .toList()
          : const [],
      lowStockProducts: lowStock is List
          ? lowStock
                .whereType<Map<String, dynamic>>()
                .map(DashboardLowStockProduct.fromJson)
                .toList()
          : const [],
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.omzet,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
  });

  const DashboardSummary.empty()
    : omzet = 0,
      grossProfit = 0,
      expenses = 0,
      netProfit = 0;

  final int omzet;
  final int grossProfit;
  final int expenses;
  final int netProfit;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      omzet: parseMoney(json['omzet']),
      grossProfit: parseMoney(json['gross_profit']),
      expenses: parseMoney(json['expenses']),
      netProfit: parseMoney(json['net_profit']),
    );
  }
}

class DashboardTransaction {
  const DashboardTransaction({
    required this.type,
    required this.referenceId,
    required this.title,
    required this.amount,
    required this.occurredAt,
  });

  final String type;
  final String referenceId;
  final String title;
  final int amount;
  final DateTime occurredAt;

  bool get isProductSale => type == 'product_sale';
  bool get isService => type == 'service';
  bool get isPhoneSale => type == 'phone_sale';

  String get label {
    return switch (type) {
      'phone_sale' => 'Jual Beli HP',
      'service' => 'Servis HP',
      'expense' => 'Pengeluaran',
      _ => 'Penjualan',
    };
  }

  factory DashboardTransaction.fromJson(Map<String, dynamic> json) {
    return DashboardTransaction(
      type: json['type']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: parseMoney(json['amount']),
      occurredAt: parseBackendDateTime(json['occurred_at']),
    );
  }
}

class DashboardChartPoint {
  const DashboardChartPoint({required this.day, required this.omzet});

  final String day;
  final int omzet;

  factory DashboardChartPoint.fromJson(Map<String, dynamic> json) {
    return DashboardChartPoint(
      day: json['day']?.toString() ?? '',
      omzet: parseMoney(json['omzet']),
    );
  }
}

class DashboardLowStockProduct {
  const DashboardLowStockProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.minimumStock,
    required this.unit,
  });

  final String id;
  final String name;
  final String category;
  final int stock;
  final int minimumStock;
  final String unit;

  factory DashboardLowStockProduct.fromJson(Map<String, dynamic> json) {
    return DashboardLowStockProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Barang',
      stock: parseIntValue(json['stock_quantity']),
      minimumStock: parseIntValue(json['minimum_stock']),
      unit: json['unit']?.toString() ?? 'pcs',
    );
  }
}
