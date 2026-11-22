import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_auth_service.dart';
import 'package:metapos/data/remote/odoo_catalog_service.dart';
import 'package:metapos/data/remote/odoo_partner_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';

void main() {
  const baseUrl = 'https://demostore.metaposbd.com';
  const db = 'demostore';
  const login = 'admin';
  const password = 'CaEYjbVrDuk8JtD9qykXifeKsmqQZ';

  bool isOnline = false;

  setUpAll(() async {
    try {
      final lookup = await InternetAddress.lookup('demostore.metaposbd.com');
      isOnline = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      isOnline = false;
    }
  });

  group('Odoo 19 Live Integration Tests (https://demostore.metaposbd.com)', () {
    late OdooJsonRpcClient client;
    late OdooAuthService authService;
    late OdooSessionService sessionService;
    late OdooCatalogService catalogService;
    late OdooPartnerService partnerService;

    setUp(() {
      client = OdooJsonRpcClient(baseUrl: baseUrl);
      authService = OdooAuthService(client: client);
      sessionService = OdooSessionService(client: client);
      catalogService = OdooCatalogService(client: client);
      partnerService = OdooPartnerService(client: client);
    });

    tearDown(() {
      client.close();
    });

    test('1. Live Authentication & Session Cookie Capture', () async {
      if (!isOnline) {
        // Skip if offline
        return;
      }

      final authResult = await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      expect(authResult['uid'], equals(2));
      expect(authResult['name'], contains('Admin'));
      expect(authResult['server_version'], startsWith('19'));
      expect(client.sessionId, isNotNull);
      expect(client.sessionId!.isNotEmpty, isTrue);

      // Verify session info call with active cookie
      final sessionInfo = await authService.getSessionInfo();
      expect(sessionInfo['uid'], equals(2));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('2. Live POS Register Discovery (pos.config)', () async {
      if (!isOnline) return;

      // Ensure authenticated
      await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      final configs = await sessionService.searchConfigs();
      expect(configs.isNotEmpty, isTrue);

      // Verify Book Fair register (ID 1)
      final bookFairConfig = configs.firstWhere((c) => c.id == 1 || c.name.contains('Book Fair'));
      expect(bookFairConfig.bookFairMode, isTrue);
      expect(bookFairConfig.name, contains('Book Fair'));
      expect(bookFairConfig.paymentMethodIds.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('3. Live Catalog & Book Fields Fetch (product.product)', () async {
      if (!isOnline) return;

      await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      final products = await catalogService.fetchProducts(limit: 50);
      expect(products.isNotEmpty, isTrue);

      // Find at least one book product
      final bookProduct = products.firstWhere((p) => p.isBook || p.id == 62);
      expect(bookProduct.id, isPositive);
      expect(bookProduct.name.isNotEmpty, isTrue);
      expect(bookProduct.listPrice, isPositive);
      expect(bookProduct.bookQtyOnHand, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('4. Live POS Categories Fetch (pos.category)', () async {
      if (!isOnline) return;

      await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      final categories = await catalogService.fetchCategories();
      expect(categories.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('5. Live Customer Lookup (res.partner - strictly using phone, NO mobile)', () async {
      if (!isOnline) return;

      await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      // Search all customers
      final customers = await partnerService.searchPartners('');
      expect(customers, isNotNull);

      // Verify that querying with phone does not trigger Odoo 19 ValueError
      final searchByPhone = await partnerService.searchPartners('01');
      expect(searchByPhone, isA<List>());
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('6. Fast Stock On Hand Lookup (product.template.book_read_qty_on_hand)', () async {
      if (!isOnline) return;

      await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      final stock = await catalogService.fetchStockOnHand([44, 45]);
      expect(stock, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
