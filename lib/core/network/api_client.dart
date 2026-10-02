import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'infinity_free_challenge.dart';

class ApiClient {
  ApiClient._();

  static const _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      'Chrome/154.0.0.0 Safari/537.36';

  static String? _testCookie;

  static final Dio instance = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: {
        'Accept': 'application/json,text/html,application/xhtml+xml,*/*',
        'Content-Type': 'application/json',
        'User-Agent': _browserUserAgent,
      },
    ),
  );

  static Future<Map<String, dynamic>> getJson(
    String path, {
    bool requiresApiKey = true,
  }) async {
    return _requestJson(
      path,
      method: 'GET',
      requiresApiKey: requiresApiKey,
      challengeRetries: 0,
      forceChallengeParameter: false,
    );
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    bool requiresApiKey = true,
  }) async {
    await _ensureChallengeCookie();
    return _requestJson(
      path,
      method: 'POST',
      data: data,
      requiresApiKey: requiresApiKey,
      challengeRetries: 0,
      forceChallengeParameter: false,
    );
  }

  static Future<Map<String, dynamic>> putJson(
    String path, {
    Object? data,
    bool requiresApiKey = true,
  }) async {
    await _ensureChallengeCookie();
    return _requestJson(
      path,
      method: 'PUT',
      data: data,
      requiresApiKey: requiresApiKey,
      challengeRetries: 0,
      forceChallengeParameter: false,
    );
  }

  static Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? data,
    bool requiresApiKey = true,
  }) async {
    await _ensureChallengeCookie();
    return _requestJson(
      path,
      method: 'PATCH',
      data: data,
      requiresApiKey: requiresApiKey,
      challengeRetries: 0,
      forceChallengeParameter: false,
    );
  }

  static Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool requiresApiKey = true,
  }) async {
    await _ensureChallengeCookie();
    return _requestJson(
      path,
      method: 'DELETE',
      requiresApiKey: requiresApiKey,
      challengeRetries: 0,
      forceChallengeParameter: false,
    );
  }

  static Future<void> _ensureChallengeCookie() async {
    if (_testCookie != null && _testCookie!.isNotEmpty) {
      return;
    }

    _log('Preparing InfinityFree challenge cookie before mutation');
    await _requestJson(
      '/',
      method: 'GET',
      requiresApiKey: false,
      challengeRetries: 0,
      forceChallengeParameter: false,
    );
  }

  static Future<Map<String, dynamic>> _requestJson(
    String path, {
    required String method,
    Object? data,
    required bool requiresApiKey,
    required int challengeRetries,
    required bool forceChallengeParameter,
  }) async {
    final response = await instance.request<String>(
      path,
      data: data,
      queryParameters: forceChallengeParameter ? {'i': '1'} : null,
      options: Options(
        method: method,
        headers: _headers(
          requiresApiKey: requiresApiKey,
          hasBody: data != null,
        ),
      ),
    );

    final statusCode = response.statusCode ?? 0;
    final body = response.data ?? '';
    _log('$method $path -> HTTP $statusCode');

    if (InfinityFreeChallenge.isChallenge(body)) {
      _log('InfinityFree challenge detected');
      if (challengeRetries >= 2) {
        throw const ApiException('Cookie challenge ditolak.');
      }

      final cookie = InfinityFreeChallenge.solveCookie(body);
      if (cookie == null || cookie.isEmpty) {
        throw const ApiException('HTML challenge gagal diparse.');
      }

      _testCookie = cookie;
      _log('Cookie challenge generated; retrying request');
      return _requestJson(
        path,
        method: method,
        data: data,
        requiresApiKey: requiresApiKey,
        challengeRetries: challengeRetries + 1,
        forceChallengeParameter: challengeRetries == 0,
      );
    }

    final decoded = _decodeJson(
      body,
      method: method,
      path: path,
      statusCode: statusCode,
      contentType: response.headers.value('content-type') ?? '',
    );
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ?? 'HTTP error $statusCode.',
      );
    }

    final success = decoded['success'];
    if (success != true) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Server mengembalikan success=false.',
      );
    }

    _log('JSON received');
    return decoded;
  }

  static Map<String, String> _headers({
    required bool requiresApiKey,
    required bool hasBody,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json,text/html,application/xhtml+xml,*/*',
      'User-Agent': _browserUserAgent,
    };

    if (hasBody) {
      headers['Content-Type'] = 'application/json';
    }

    if (requiresApiKey) {
      headers['X-API-Key'] = AppConfig.apiKey;
    }

    final cookie = _testCookie;
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = '__test=$cookie';
    }

    return headers;
  }

  static Map<String, dynamic> _decodeJson(
    String body, {
    required String method,
    required String path,
    required int statusCode,
    required String contentType,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ApiException(
        'Response API kosong dari $method $path (HTTP $statusCode).',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const ApiException('Response JSON bukan object.');
    } on FormatException catch (error) {
      final preview = trimmed.length <= 160
          ? trimmed
          : '${trimmed.substring(0, 160)}...';
      final typeText = contentType.isEmpty ? 'tanpa Content-Type' : contentType;
      throw ApiException(
        'Response API bukan JSON valid dari $method $path '
        '(HTTP $statusCode, $typeText): ${error.message}. '
        'Body: $preview',
      );
    }
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ApiClient] $message');
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
