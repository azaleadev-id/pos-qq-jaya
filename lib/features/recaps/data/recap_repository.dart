import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class RecapRepository {
  const RecapRepository();

  Future<RecapSnapshot> fetchRecap({DateTime? from, DateTime? to}) async {
    final query = <String>[];
    if (from != null) {
      query.add('from=${Uri.encodeQueryComponent(_date(from, end: false))}');
    }
    if (to != null) {
      query.add('to=${Uri.encodeQueryComponent(_date(to, end: true))}');
    }
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';
    final response = await ApiClient.getJson('/api/recaps$suffix');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response rekap tidak valid.');
    }
    return RecapSnapshot.fromJson(data);
  }

  String _date(DateTime value, {required bool end}) {
    final local = value.toLocal();
    final date = DateTime(
      local.year,
      local.month,
      local.day,
      end ? 23 : 0,
      end ? 59 : 0,
      end ? 59 : 0,
    );
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}

class RecapSnapshot {
  const RecapSnapshot({
    required this.period,
    required this.summary,
    required this.breakdown,
    required this.products,
    required this.expenseCategories,
  });

  final RecapPeriod period;
  final RecapSummary summary;
  final RecapBreakdown breakdown;
  final List<RecapProductDetail> products;
  final List<RecapExpenseCategory> expenseCategories;

  factory RecapSnapshot.fromJson(Map<String, dynamic> json) {
    return RecapSnapshot(
      period: RecapPeriod.fromJson(
        json['period'] is Map<String, dynamic>
            ? json['period'] as Map<String, dynamic>
            : const {},
      ),
      summary: RecapSummary.fromJson(
        json['summary'] is Map<String, dynamic>
            ? json['summary'] as Map<String, dynamic>
            : const {},
      ),
      breakdown: RecapBreakdown.fromJson(
        json['breakdown'] is Map<String, dynamic>
            ? json['breakdown'] as Map<String, dynamic>
            : const {},
      ),
      products: json['products'] is List
          ? (json['products'] as List)
                .whereType<Map<String, dynamic>>()
                .map(RecapProductDetail.fromJson)
                .toList()
          : const [],
      expenseCategories: json['expenses_by_category'] is List
          ? (json['expenses_by_category'] as List)
                .whereType<Map<String, dynamic>>()
                .map(RecapExpenseCategory.fromJson)
                .toList()
          : const [],
    );
  }
}

class RecapPeriod {
  const RecapPeriod({required this.from, required this.to});

  final String from;
  final String to;

  factory RecapPeriod.fromJson(Map<String, dynamic> json) {
    return RecapPeriod(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
    );
  }
}

class RecapSummary {
  const RecapSummary({
    required this.omzet,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.transactions,
  });

  final int omzet;
  final int grossProfit;
  final int expenses;
  final int netProfit;
  final int transactions;

  factory RecapSummary.fromJson(Map<String, dynamic> json) {
    return RecapSummary(
      omzet: parseMoney(json['omzet']),
      grossProfit: parseMoney(json['gross_profit']),
      expenses: parseMoney(json['expenses']),
      netProfit: parseMoney(json['net_profit']),
      transactions: parseIntValue(json['transactions']),
    );
  }
}

class RecapBreakdown {
  const RecapBreakdown({
    required this.products,
    required this.services,
    required this.phones,
    required this.vouchers,
    required this.pulsa,
    required this.dataPackages,
    required this.expenses,
  });

  final RecapSalesCategory products;
  final RecapSalesCategory services;
  final RecapSalesCategory phones;
  final RecapSalesCategory vouchers;
  final RecapSalesCategory pulsa;
  final RecapSalesCategory dataPackages;
  final RecapExpenseSummary expenses;

  factory RecapBreakdown.fromJson(Map<String, dynamic> json) {
    return RecapBreakdown(
      products: RecapSalesCategory.fromJson(_map(json['products'])),
      services: RecapSalesCategory.fromJson(_map(json['services'])),
      phones: RecapSalesCategory.fromJson(_map(json['phones'])),
      vouchers: RecapSalesCategory.fromJson(_map(json['vouchers'])),
      pulsa: RecapSalesCategory.fromJson(_map(json['pulsa'])),
      dataPackages: RecapSalesCategory.fromJson(_map(json['data_packages'])),
      expenses: RecapExpenseSummary.fromJson(_map(json['expenses'])),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }
}

class RecapSalesCategory {
  const RecapSalesCategory({
    required this.transactions,
    required this.quantity,
    required this.omzet,
    required this.modal,
    required this.profit,
  });

  final int transactions;
  final int quantity;
  final int omzet;
  final int modal;
  final int profit;

  factory RecapSalesCategory.fromJson(Map<String, dynamic> json) {
    return RecapSalesCategory(
      transactions: parseIntValue(json['transactions']),
      quantity: parseIntValue(json['quantity']),
      omzet: parseMoney(json['omzet']),
      modal: parseMoney(json['modal']),
      profit: parseMoney(json['profit']),
    );
  }
}

class RecapExpenseSummary {
  const RecapExpenseSummary({required this.transactions, required this.amount});

  final int transactions;
  final int amount;

  factory RecapExpenseSummary.fromJson(Map<String, dynamic> json) {
    return RecapExpenseSummary(
      transactions: parseIntValue(json['transactions']),
      amount: parseMoney(json['amount']),
    );
  }
}

class RecapProductDetail {
  const RecapProductDetail({
    required this.name,
    required this.quantity,
    required this.omzet,
    required this.modal,
    required this.profit,
  });

  final String name;
  final int quantity;
  final int omzet;
  final int modal;
  final int profit;

  factory RecapProductDetail.fromJson(Map<String, dynamic> json) {
    return RecapProductDetail(
      name: json['product_name']?.toString() ?? '',
      quantity: parseIntValue(json['quantity_sold']),
      omzet: parseMoney(json['omzet']),
      modal: parseMoney(json['modal']),
      profit: parseMoney(json['profit']),
    );
  }
}

class RecapExpenseCategory {
  const RecapExpenseCategory({
    required this.category,
    required this.transactions,
    required this.amount,
  });

  final String category;
  final int transactions;
  final int amount;

  factory RecapExpenseCategory.fromJson(Map<String, dynamic> json) {
    return RecapExpenseCategory(
      category: json['category']?.toString() ?? 'Lainnya',
      transactions: parseIntValue(json['transactions']),
      amount: parseMoney(json['amount']),
    );
  }
}
