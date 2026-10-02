import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class ExpenseRepository {
  const ExpenseRepository();

  static const _uuid = Uuid();

  Future<List<ExpenseItem>> fetchExpenses({String? search}) async {
    final query = search == null || search.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final response = await ApiClient.getJson('/api/expenses$query');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Response pengeluaran tidak valid.');
    }
    final expenses = data['expenses'];
    if (expenses is! List) {
      throw const ApiException('Data pengeluaran tidak valid.');
    }
    return expenses
        .whereType<Map<String, dynamic>>()
        .map(ExpenseItem.fromJson)
        .toList();
  }

  Future<ExpenseItem> createExpense({
    required String category,
    required String name,
    required int amount,
    required DateTime date,
    required String notes,
  }) async {
    final response = await ApiClient.postJson(
      '/api/expenses',
      data: _payload(
        id: _uuid.v4(),
        category: category,
        name: name,
        amount: amount,
        date: date,
        notes: notes,
      ),
    );
    return _expenseFromResponse(
      response,
      'Response tambah pengeluaran tidak valid.',
    );
  }

  Future<ExpenseItem> updateExpense({
    required String id,
    required String category,
    required String name,
    required int amount,
    required DateTime date,
    required String notes,
  }) async {
    final response = await ApiClient.patchJson(
      '/api/expenses/$id',
      data: _payload(
        category: category,
        name: name,
        amount: amount,
        date: date,
        notes: notes,
      ),
    );
    return _expenseFromResponse(
      response,
      'Response edit pengeluaran tidak valid.',
    );
  }

  Future<void> deleteExpense(String id) async {
    await ApiClient.deleteJson('/api/expenses/$id');
  }

  Map<String, Object?> _payload({
    String? id,
    required String category,
    required String name,
    required int amount,
    required DateTime date,
    required String notes,
  }) {
    final payload = <String, Object?>{
      'expense_category': category.trim(),
      'expense_name': name.trim(),
      'amount': amount,
      'expense_date': _backendDate(date),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    if (id != null) {
      payload['id'] = id;
    }
    return payload;
  }

  ExpenseItem _expenseFromResponse(
    Map<String, dynamic> response,
    String errorMessage,
  ) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(errorMessage);
    }
    final expense = data['expense'];
    if (expense is! Map<String, dynamic>) {
      throw ApiException(errorMessage);
    }
    return ExpenseItem.fromJson(expense);
  }

  String _backendDate(DateTime date) {
    final utc = date.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.category,
    required this.name,
    required this.amount,
    required this.date,
    required this.notes,
  });

  final String id;
  final String category;
  final String name;
  final int amount;
  final DateTime date;
  final String notes;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: json['id']?.toString() ?? '',
      category: json['expense_category']?.toString() ?? 'Lainnya',
      name: json['expense_name']?.toString() ?? '',
      amount: parseMoney(json['amount']),
      date: parseBackendDateTime(json['expense_date']),
      notes: json['notes']?.toString() ?? '',
    );
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return category.toLowerCase().contains(normalized) ||
        name.toLowerCase().contains(normalized) ||
        notes.toLowerCase().contains(normalized);
  }
}
