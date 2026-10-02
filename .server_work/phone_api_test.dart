import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../lib/core/network/infinity_free_challenge.dart';

const baseUrl = 'https://qq-jaya-api.unaux.com';
const apiKey = 'qq-jaya-cell-local-key';
const uuid = Uuid();

Future<void> main() async {
  final api = ChallengeApi();
  final ids = <String>[];
  final report = <String, Object?>{};

  try {
    await api.get('/api/health');

    final iphoneId = uuid.v4();
    ids.add(iphoneId);
    final bought = await api.post('/api/phones/purchases', {
      'id': iphoneId,
      'device_name': 'iPhone 11 128GB TEST',
      'purchase_price': 3500000,
      'selling_price': 4000000,
      'condition_notes': 'Bekas',
      'seller_name': 'Budi TEST',
    });
    report['beli_hp'] = snapshot(bought);

    final restartStock = await api.get('/api/phones/$iphoneId');
    report['restart_like_stock'] = snapshot(restartStock);

    final edited = await api.patch('/api/phones/$iphoneId', {
      'device_name': 'iPhone 11 128GB TEST',
      'purchase_price': 3500000,
      'selling_price': 3900000,
      'condition_notes': 'Bekas',
      'seller_name': 'Budi TEST',
    });
    report['edit_harga'] = snapshot(edited);

    final soldProfit = await api.post('/api/phones/$iphoneId/sell', {
      'selling_price': 3850000,
      'payment_method': 'cash',
      'source_name': 'Buyer TEST',
    });
    report['jual_untung'] = snapshot(soldProfit);

    final secondSell = await api.postAllowingError(
      '/api/phones/$iphoneId/sell',
      {'selling_price': 3800000, 'payment_method': 'cash'},
    );
    report['jual_dua_kali_ditolak'] =
        secondSell['success'] == false &&
        secondSell['message'].toString().toLowerCase().contains('terjual');

    final editSold = await api.patchAllowingError('/api/phones/$iphoneId', {
      'device_name': 'iPhone 11 128GB TEST EDIT',
      'purchase_price': 3500000,
    });
    report['edit_setelah_terjual_ditolak'] = editSold['success'] == false;

    final redmiId = uuid.v4();
    ids.add(redmiId);
    await api.post('/api/phones/purchases', {
      'id': redmiId,
      'device_name': 'Redmi Note 13 TEST',
      'purchase_price': 2000000,
      'selling_price': 2200000,
      'condition_notes': 'Bekas',
    });
    final soldLoss = await api.post('/api/phones/$redmiId/sell', {
      'selling_price': 1900000,
      'payment_method': 'cash',
    });
    report['jual_rugi'] = snapshot(soldLoss);

    final soldList = await api.get('/api/phones?status=sold');
    final soldPhones = (((soldList['data'] as Map)['phones'] as List)
        .whereType<Map>()
        .toList());
    report['riwayat_phone_source'] = soldPhones.any(
      (phone) => ids.contains(phone['id']),
    );

    final allList = await api.get('/api/phones');
    final allPhones = (((allList['data'] as Map)['phones'] as List)
        .whereType<Map>()
        .toList());
    report['stok_test_not_available_after_sold'] = !allPhones.any(
      (phone) =>
          ids.contains(phone['id']) && phone['phone_status'] == 'available',
    );
  } finally {
    for (final id in ids) {
      await api.deleteAllowingError('/api/phones/$id');
    }
    report['cleanup_deleted_ids'] = ids;
  }

  print(const JsonEncoder.withIndent('  ').convert(report));
}

Map<String, Object?> snapshot(Map<String, dynamic> response) {
  final data = response['data'] as Map<String, dynamic>;
  final phone = data['phone'] as Map<String, dynamic>;
  return {
    'id': phone['id'],
    'device_name': phone['device_name'],
    'status': phone['phone_status'],
    'purchase_price': money(phone['purchase_price']),
    'selling_price': phone['selling_price'] == null
        ? null
        : money(phone['selling_price']),
    'profit': phone['profit'] == null ? null : money(phone['profit']),
    'condition': phone['condition_notes'],
    'seller_name': phone['seller_name'],
    'sale_date': phone['sale_date'],
  };
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
  Future<Map<String, dynamic>> patchAllowingError(String path, Object data) =>
      _request('PATCH', path, data: data, allowError: true);
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
