import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../lib/core/network/infinity_free_challenge.dart';

const baseUrl = 'https://qq-jaya-api.unaux.com';
const apiKey = 'qq-jaya-cell-local-key';

const uuid = Uuid();

Future<void> main() async {
  final api = ChallengeApi();
  final report = <String, Object?>{};
  final ids = <String>[];

  try {
    await api.get('/api/health');

    final unpaidId = uuid.v4();
    ids.add(unpaidId);
    final unpaid = await api.post('/api/services', {
      'id': unpaidId,
      'device_name': 'Infinix X680 Test',
      'service_name': 'Ganti LCD Test',
      'service_price': 350000,
      'parts_cost': 0,
      'delivery_cost': 20000,
      'customer_name': 'Test Customer',
      'service_status': 'in',
    });
    report['belum_bayar'] = snapshot(unpaid);

    final activeBefore = await api.get('/api/services');
    report['dashboard_active_before_complete'] = containsActive(
      activeBefore,
      unpaidId,
    );

    for (final status in ['waiting', 'working', 'completed']) {
      await api.patch('/api/services/$unpaidId/status', {'status': status});
    }
    final unpaidCompleted = await api.get('/api/services/$unpaidId');
    report['status_flow_completed_unpaid'] = snapshot(unpaidCompleted);

    final activeAfter = await api.get('/api/services');
    report['dashboard_active_after_complete'] = containsActive(
      activeAfter,
      unpaidId,
    );

    final paymentId = uuid.v4();
    ids.add(paymentId);
    final paymentService = await api.post('/api/services', {
      'id': paymentId,
      'device_name': 'Redmi Note 13 Test',
      'service_name': 'Ganti LCD Test',
      'service_price': 350000,
      'parts_cost': 0,
      'delivery_cost': 20000,
      'service_status': 'in',
    });
    report['payment_base'] = snapshot(paymentService);

    final dpPaymentId = uuid.v4();
    final dp = await api.post('/api/services/$paymentId/payments', {
      'id': dpPaymentId,
      'amount': 100000,
      'payment_method': 'cash',
      'payment_type': 'down_payment',
    });
    report['dp'] = snapshot(dp);
    report['dp_payment_count'] = paymentCount(dp);

    final duplicateDp = await api.post('/api/services/$paymentId/payments', {
      'id': dpPaymentId,
      'initial_payment': 100000,
      'amount': 100000,
      'payment_method': 'cash',
      'payment_type': 'down_payment',
    });
    report['duplicate_payment_id_count'] = paymentCount(duplicateDp);

    final second = await api.post('/api/services/$paymentId/payments', {
      'id': uuid.v4(),
      'amount': 100000,
      'payment_method': 'cash',
      'payment_type': 'down_payment',
    });
    report['pembayaran_kedua'] = snapshot(second);
    report['pembayaran_kedua_count'] = paymentCount(second);

    final overpay = await api.postAllowingError(
      '/api/services/$paymentId/payments',
      {
        'id': uuid.v4(),
        'amount': 200000,
        'payment_method': 'cash',
        'payment_type': 'settlement',
      },
    );
    report['overpayment_rejected'] =
        overpay['success'] == false &&
        overpay['message'].toString().contains('melebihi');

    final invalidPayments = <String, Object?>{};
    for (final entry in {
      'kosong': null,
      'nol': 0,
      'negatif': -10000,
      'huruf': 'abc',
      'sangat_besar': 999999999999,
    }.entries) {
      final invalid = await api.postAllowingError(
        '/api/services/$paymentId/payments',
        {
          'id': uuid.v4(),
          if (entry.value != null) 'amount': entry.value,
          'payment_method': 'cash',
          'payment_type': 'down_payment',
        },
      );
      invalidPayments[entry.key] = {
        'success': invalid['success'],
        'message': invalid['message'],
      };
    }
    report['invalid_inputs'] = invalidPayments;

    final settlement = await api.post('/api/services/$paymentId/payments', {
      'id': uuid.v4(),
      'amount': 170000,
      'payment_method': 'cash',
      'payment_type': 'settlement',
    });
    report['pelunasan'] = snapshot(settlement);
    report['pelunasan_payment_count'] = paymentCount(settlement);

    final restartCheck = await api.get('/api/services/$paymentId');
    report['restart_like_refetch'] = snapshot(restartCheck);

    final paidOverpay = await api.postAllowingError(
      '/api/services/$paymentId/payments',
      {
        'id': uuid.v4(),
        'amount': 400000,
        'payment_method': 'cash',
        'payment_type': 'settlement',
      },
    );
    report['paid_overpayment_rejected'] =
        paidOverpay['success'] == false &&
        paidOverpay['message'].toString().contains('melebihi');

    final warrantyId = uuid.v4();
    ids.add(warrantyId);
    final warranty = await api.post('/api/services', {
      'id': warrantyId,
      'device_name': 'Samsung A15 Test',
      'service_name': 'Software Test',
      'service_price': 100000,
      'parts_cost': 0,
      'delivery_cost': 0,
      'service_status': 'in',
      'warranty_value': 24,
      'warranty_unit': 'hour',
    });
    report['garansi_create'] = snapshot(warranty);
    for (final status in ['waiting', 'working', 'completed']) {
      await api.patch('/api/services/$warrantyId/status', {'status': status});
    }
    final warrantyCompleted = await api.get('/api/services/$warrantyId');
    report['garansi_completed'] = snapshot(warrantyCompleted);

    final services = await api.get('/api/services');
    final serviceList = (((services['data'] as Map)['services'] as List)
        .whereType<Map>()
        .toList());
    report['history_service_filter_source'] = serviceList.any(
      (service) => ids.contains(service['id']),
    );
    report['history_all_source'] = report['history_service_filter_source'];
  } finally {
    for (final id in ids) {
      await api.deleteAllowingError('/api/services/$id');
    }
    report['cleanup_deleted_ids'] = ids;
  }

  print(const JsonEncoder.withIndent('  ').convert(report));
}

Map<String, Object?> snapshot(Map<String, dynamic> response) {
  final data = response['data'] as Map<String, dynamic>;
  final service = data['service'] as Map<String, dynamic>;
  return {
    'id': service['id'],
    'total': money(service['service_price']) + money(service['delivery_cost']),
    'paid': money(service['total_paid']),
    'remaining': money(service['remaining_payment']),
    'service_status': service['service_status'],
    'payment_status': service['payment_status'],
    'warranty_value': service['warranty_value'],
    'warranty_unit': service['warranty_unit'],
    'warranty_started_at': service['warranty_started_at'],
    'warranty_ends_at': service['warranty_ends_at'],
  };
}

int paymentCount(Map<String, dynamic> response) {
  final data = response['data'] as Map<String, dynamic>;
  return (data['payments'] as List).length;
}

bool containsActive(Map<String, dynamic> response, String id) {
  final data = response['data'] as Map<String, dynamic>;
  return (data['services'] as List).whereType<Map>().any(
    (service) =>
        service['id'] == id && service['service_status'] != 'completed',
  );
}

int money(Object? value) {
  if (value is num) {
    return value.round();
  }
  return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
}

class ChallengeApi {
  ChallengeApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          headers: {
            'Accept': 'application/json,text/html,*/*',
            'Content-Type': 'application/json',
            'X-API-Key': apiKey,
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/154.0.0.0 Safari/537.36',
          },
        ),
      );

  final Dio _dio;
  String? _cookie;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, Object data) =>
      _request('POST', path, data: data);
  Future<Map<String, dynamic>> patch(String path, Object data) =>
      _request('PATCH', path, data: data);
  Future<Map<String, dynamic>> postAllowingError(String path, Object data) =>
      _request('POST', path, data: data, allowError: true);
  Future<Map<String, dynamic>> deleteAllowingError(String path) =>
      _request('DELETE', path, allowError: true);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
    bool allowError = false,
    int attempt = 0,
  }) async {
    final response = await _dio.request<String>(
      path,
      data: data,
      queryParameters: attempt == 0 ? null : {'i': attempt},
      options: Options(
        method: method,
        headers: _cookie == null ? null : {'Cookie': '__test=$_cookie'},
      ),
    );
    final body = response.data ?? '';
    if (InfinityFreeChallenge.isChallenge(body)) {
      if (attempt >= 3) {
        throw StateError('Challenge failed for $method $path');
      }
      _cookie = InfinityFreeChallenge.solveCookie(body);
      return _request(
        method,
        path,
        data: data,
        allowError: allowError,
        attempt: attempt + 1,
      );
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (decoded['success'] != true && !allowError) {
      throw StateError('$method $path failed: ${decoded['message']}');
    }
    return decoded;
  }
}
