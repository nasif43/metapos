import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base exception class for Odoo JSON-RPC errors.
abstract class OdooException implements Exception {
  final String message;
  final int? code;
  final dynamic data;

  const OdooException({
    required this.message,
    this.code,
    this.data,
  });

  @override
  String toString() => '$runtimeType: $message (code: $code)';
}

/// Thrown when session has expired or is invalid (Odoo error code 100).
class OdooSessionExpiredException extends OdooException {
  const OdooSessionExpiredException({
    required super.message,
    super.code = 100,
    super.data,
  });
}

/// Thrown when authentication fails due to incorrect credentials.
class OdooAccessDeniedException extends OdooException {
  const OdooAccessDeniedException({
    required super.message,
    super.code = 0,
    super.data,
  });
}

/// Thrown when a business logic constraint is violated (e.g., unpaid order, closed session, missing record).
class OdooUserException extends OdooException {
  const OdooUserException({
    required super.message,
    super.code = 0,
    super.data,
  });
}

/// Thrown when an internal server error or network issue occurs.
class OdooServerException extends OdooException {
  final int? httpStatusCode;

  const OdooServerException({
    required super.message,
    super.code = 0,
    super.data,
    this.httpStatusCode,
  });

  @override
  String toString() =>
      'OdooServerException: $message (code: $code, http: $httpStatusCode)';
}

/// Robust JSON-RPC 2.0 client for Odoo 19 with cookie persistence and error classification.
class OdooJsonRpcClient {
  String baseUrl;
  String? sessionId;
  final http.Client _httpClient;

  OdooJsonRpcClient({
    required this.baseUrl,
    this.sessionId,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Updates or clears the session ID cookie.
  void setSessionId(String? id) {
    sessionId = id;
  }

  /// Sets the base URL (e.g. "https://demostore.metaposbd.com").
  void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Closes client resources.
  void close() {
    _httpClient.close();
  }

  /// Generic JSON-RPC 2.0 call to any Odoo endpoint.
  Future<dynamic> call(
    String endpoint,
    Map<String, dynamic> params, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final cleanBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint =
        endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$cleanBase$cleanEndpoint');

    final requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (sessionId != null && sessionId!.isNotEmpty)
        'Cookie': 'session_id=$sessionId',
      if (headers != null) ...headers,
    };

    final requestBody = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
      'id': DateTime.now().millisecondsSinceEpoch,
    });

    final http.Response response;
    try {
      response = await _httpClient
          .post(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout);
    } catch (e) {
      throw OdooServerException(
        message: 'Network connection failed: ${e.toString()}',
      );
    }

    // Capture session_id cookie if returned in Set-Cookie header
    _extractSessionCookie(response.headers);

    if (response.statusCode != 200) {
      throw OdooServerException(
        message: 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Error"}',
        httpStatusCode: response.statusCode,
      );
    }

    Map<String, dynamic> jsonResponse;
    try {
      jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw OdooServerException(
        message: 'Failed to decode JSON response: ${e.toString()}',
        data: response.body,
      );
    }

    // Inspect payload for Odoo JSON-RPC error
    if (jsonResponse.containsKey('error')) {
      final errorMap = jsonResponse['error'] as Map<String, dynamic>;
      _throwClassifiedError(errorMap);
    }

    return jsonResponse['result'];
  }

  /// Executes an ORM method via `/web/dataset/call_kw/<model>/<method>`.
  Future<dynamic> executeCall(
    String model,
    String method,
    List<dynamic> args, [
    Map<String, dynamic>? kwargs,
  ]) async {
    final endpoint = '/web/dataset/call_kw/$model/$method';
    final params = {
      'model': model,
      'method': method,
      'args': args,
      'kwargs': kwargs ?? {},
    };

    return await call(endpoint, params);
  }

  /// Extracts `session_id` from Set-Cookie header if present.
  void _extractSessionCookie(Map<String, String> headers) {
    final setCookie = headers['set-cookie'] ?? headers['Set-Cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      final match = RegExp(r'session_id=([^;,\s]+)').firstMatch(setCookie);
      if (match != null && match.groupCount >= 1) {
        sessionId = match.group(1);
      }
    }
  }

  /// Parses error payload and throws typed exception.
  void _throwClassifiedError(Map<String, dynamic> error) {
    final int code = (error['code'] as num?)?.toInt() ?? 0;
    final String generalMessage = (error['message'] ?? 'Odoo Server Error') as String;
    final dynamic data = error['data'];

    String errorName = '';
    String detailedMessage = generalMessage;

    if (data is Map<String, dynamic>) {
      errorName = (data['name'] ?? '') as String;
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        detailedMessage = data['message'] as String;
      }
    }

    // 1. Session Expired
    if (code == 100 ||
        errorName.contains('SessionExpiredException') ||
        detailedMessage.toLowerCase().contains('session expired')) {
      throw OdooSessionExpiredException(
        message: detailedMessage,
        code: code,
        data: data,
      );
    }

    // 2. Access Denied (Bad login or password)
    if (errorName.contains('AccessDenied') ||
        detailedMessage.toLowerCase().contains('access denied')) {
      throw OdooAccessDeniedException(
        message: detailedMessage,
        code: code,
        data: data,
      );
    }

    // 3. User / Business Logic Error (e.g., unpaid order, closed session, record missing)
    if (errorName.contains('UserError') ||
        errorName.contains('MissingError') ||
        errorName.contains('ValidationError') ||
        errorName.contains('ValueError')) {
      throw OdooUserException(
        message: detailedMessage,
        code: code,
        data: data,
      );
    }

    // 4. General Server Error
    throw OdooServerException(
      message: detailedMessage,
      code: code,
      data: data,
    );
  }
}
