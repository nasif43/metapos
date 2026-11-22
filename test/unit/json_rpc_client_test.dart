import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';

void main() {
  group('OdooJsonRpcClient Unit Tests', () {
    test('Request envelope is formatted correctly with JSON-RPC 2.0 standards', () async {
      late Map<String, dynamic> capturedBody;
      late Map<String, String> capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': capturedBody['id'],
            'result': {'uid': 2, 'name': 'Administrator'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      final result = await client.executeCall('res.users', 'search_read', [[]], {'fields': ['id', 'name']});

      expect(result, isNotNull);
      expect(result['uid'], 2);
      expect(capturedBody['jsonrpc'], '2.0');
      expect(capturedBody['method'], 'call');
      expect(capturedBody['params']['model'], 'res.users');
      expect(capturedBody['params']['method'], 'search_read');
      expect(capturedBody['params']['kwargs']['fields'], ['id', 'name']);
      expect(capturedHeaders['Content-Type'], 'application/json');
    });

    test('Cookie handling: captures session_id from Set-Cookie and transmits on subsequent calls', () async {
      String? sentCookieHeader;

      final mockClient = MockClient((request) async {
        sentCookieHeader = request.headers['Cookie'];

        if (request.url.path == '/web/session/authenticate') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': null,
              'result': {'uid': 2, 'name': 'Admin'},
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'set-cookie': 'session_id=test_cookie_token_12345; Path=/; HttpOnly',
            },
          );
        }

        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'result': [{'id': 1, 'name': 'Book Fair'}],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      // 1. Authenticate to capture cookie
      await client.call('/web/session/authenticate', {
        'db': 'demostore',
        'login': 'admin',
        'password': 'password',
      });

      expect(client.sessionId, 'test_cookie_token_12345');

      // 2. Next call must include Cookie header
      await client.executeCall('pos.config', 'search_read', [[]]);
      expect(sentCookieHeader, 'session_id=test_cookie_token_12345');
    });

    test('Throws OdooSessionExpiredException when session expired (code 100 or SessionExpiredException)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'error': {
              'code': 100,
              'message': 'Odoo Session Expired',
              'data': {
                'name': 'odoo.http.SessionExpiredException',
                'message': 'Session expired',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      expect(
        () => client.executeCall('pos.session', 'load_data', [[1], []]),
        throwsA(isA<OdooSessionExpiredException>()),
      );
    });

    test('Throws OdooAccessDeniedException on invalid credentials', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'error': {
              'code': 0,
              'message': 'Odoo Server Error',
              'data': {
                'name': 'odoo.exceptions.AccessDenied',
                'message': 'Access Denied',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      expect(
        () => client.call('/web/session/authenticate', {'db': 'demostore', 'login': 'admin', 'password': 'bad'}),
        throwsA(isA<OdooAccessDeniedException>()),
      );
    });

    test('Throws OdooUserException on business logic constraint errors (e.g. UserError / MissingError)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'error': {
              'code': 0,
              'message': 'Odoo Server Error',
              'data': {
                'name': 'odoo.exceptions.UserError',
                'message': 'অর্ডার /-এর মূল্য পুরোপুরি পরিশোধ হয়নি।',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      expect(
        () => client.executeCall('pos.order', 'sync_from_ui', [[]]),
        throwsA(isA<OdooUserException>().having(
          (e) => e.message,
          'message',
          contains('পরিশোধ'),
        )),
      );
    });

    test('Throws OdooServerException on HTTP status errors (e.g. 500, 502)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Bad Gateway', 502);
      });

      final client = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      expect(
        () => client.executeCall('pos.order', 'search_read', [[]]),
        throwsA(isA<OdooServerException>().having(
          (e) => e.httpStatusCode,
          'httpStatusCode',
          502,
        )),
      );
    });
  });
}
