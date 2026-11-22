import 'json_rpc_client.dart';

/// Service managing Odoo 19 user authentication and session lifecycle.
class OdooAuthService {
  final OdooJsonRpcClient client;

  OdooAuthService({required this.client});

  /// Authenticates user against Odoo 19 via `/web/session/authenticate`.
  ///
  /// Automatically stores the returned `session_id` cookie in [client]
  /// and returns user profile, company, and currency metadata.
  Future<Map<String, dynamic>> authenticate({
    required String baseUrl,
    required String db,
    required String login,
    required String password,
  }) async {
    client.setBaseUrl(baseUrl);

    final params = {
      'db': db,
      'login': login,
      'password': password,
    };

    final result = await client.call('/web/session/authenticate', params);
    if (result is Map<String, dynamic>) {
      return result;
    }
    return {'result': result};
  }

  /// Verifies if the current session cookie is valid and returns user context.
  ///
  /// Throws [OdooSessionExpiredException] if session cookie is invalid or expired.
  Future<Map<String, dynamic>> getSessionInfo() async {
    final result = await client.call('/web/session/get_session_info', {});
    if (result is Map<String, dynamic>) {
      return result;
    }
    return {'result': result};
  }

  /// Invalidates the active session on Odoo and clears local session cookie.
  Future<void> destroySession() async {
    try {
      await client.call('/web/session/destroy', {});
    } finally {
      client.setSessionId(null);
    }
  }
}
