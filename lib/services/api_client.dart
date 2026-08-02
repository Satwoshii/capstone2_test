import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_config_service.dart';

class ApiUnavailableException implements Exception {
  final String message;

  const ApiUnavailableException(this.message);

  @override
  String toString() => message;
}

class ApiRequestException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? response;

  const ApiRequestException({
    required this.statusCode,
    required this.message,
    this.code,
    this.response,
  });

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> getJson(
    String endpoint, {
    Map<String, String>? query,
    bool includeWorkstationToken = true,
    bool includeStudentToken = false,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'GET',
      endpoint: endpoint,
      query: query,
      includeWorkstationToken: includeWorkstationToken,
      includeStudentToken: includeStudentToken,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool includeWorkstationToken = true,
    bool includeStudentToken = false,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'POST',
      endpoint: endpoint,
      body: body ?? const <String, dynamic>{},
      query: query,
      includeWorkstationToken: includeWorkstationToken,
      includeStudentToken: includeStudentToken,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required bool includeWorkstationToken,
    required bool includeStudentToken,
    Map<String, String>? headers,
  }) async {
    final serverUrl = await AppConfigService.instance.getServerUrl();
    final uri = _buildUri(serverUrl, endpoint, query);
    final client = HttpClient()..connectionTimeout = _connectTimeout;

    try {
      final request = await client.openUrl(method, uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-Syswatch-Client', 'student-pc');

      if (includeWorkstationToken) {
        final token = await AppConfigService.instance.getWorkstationToken();
        if (token.isNotEmpty) {
          request.headers.set('X-Workstation-Token', token);
        }
      }

      if (includeStudentToken) {
        final token = await AppConfigService.instance.getStudentApiToken();
        if (token.isEmpty) {
          throw const ApiRequestException(
            statusCode: 401,
            code: 'missing_student_session',
            message: 'Log in online before using ITSO Support Chat.',
          );
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.set('X-Syswatch-User-Token', token);
      }

      if (headers != null) {
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(_requestTimeout);
      final rawBody = await utf8.decoder.bind(response).join();
      final decoded = _decodeResponse(rawBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiRequestException(
          statusCode: response.statusCode,
          message: _messageFromResponse(
            decoded,
            fallback: 'The Syswatch server returned HTTP '
                '${response.statusCode}.',
          ),
          code: decoded['code']?.toString(),
          response: decoded,
        );
      }

      if (decoded['success'] == false) {
        throw ApiRequestException(
          statusCode: response.statusCode,
          message: _messageFromResponse(
            decoded,
            fallback: 'The Syswatch server rejected the request.',
          ),
          code: decoded['code']?.toString(),
          response: decoded,
        );
      }

      return decoded;
    } on ApiRequestException {
      rethrow;
    } on TimeoutException {
      throw const ApiUnavailableException(
        'The Syswatch intranet server did not respond in time.',
      );
    } on SocketException {
      throw const ApiUnavailableException(
        'The Syswatch intranet server is unreachable.',
      );
    } on HandshakeException {
      throw const ApiUnavailableException(
        'A secure connection to the Syswatch server could not be established.',
      );
    } on FormatException catch (error) {
      throw ApiRequestException(
        statusCode: 500,
        message: 'The Syswatch server returned invalid JSON: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildUri(
    String serverUrl,
    String endpoint,
    Map<String, String>? query,
  ) {
    final normalizedBase = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    final uri = Uri.parse('$normalizedBase/$normalizedEndpoint');

    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeResponse(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{'success': true};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{
      'success': true,
      'data': decoded,
    };
  }

  String _messageFromResponse(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    for (final key in const ['message', 'error', 'detail']) {
      final value = response[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }
}
