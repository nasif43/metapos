import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/core/localization/locale_provider.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/models/partner_model.dart';
import 'package:metapos/data/models/pos_config_model.dart';
import 'package:metapos/data/models/product_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_catalog_service.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/data/repositories/order_repository.dart';
import 'package:metapos/presentation/screens/cart/cart_order_screen.dart';
import 'package:metapos/presentation/screens/checkout/checkout_payment_screen.dart';
import 'package:metapos/presentation/screens/customer/customer_selector_screen.dart';
import 'package:metapos/presentation/screens/login/session_login_screen.dart';
import 'package:metapos/presentation/screens/receipt/order_success_receipt_screen.dart';
import 'package:metapos/presentation/widgets/language_toggle_button.dart';
import 'package:metapos/providers/catalog_provider.dart';
import 'package:metapos/providers/connectivity_provider.dart';
import 'package:metapos/providers/customer_provider.dart';
import 'package:metapos/providers/order_provider.dart';
import 'package:metapos/providers/session_provider.dart';
import 'package:metapos/providers/sync_queue_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Test Fakes
// ---------------------------------------------------------------------------
class FakeConnectivityService implements NetworkConnectivityService {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _connected = true;

  void emit(bool isOnline) {
    _connected = isOnline;
    _controller.add(isOnline);
  }

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void dispose() => _controller.close();
}

class TestSyncQueueNotifier extends SyncQueueNotifier {
  int syncCalls = 0;

  TestSyncQueueNotifier({
    required super.queueRepo,
    required super.orderService,
    required super.sessionService,
  });

  @override
  Future<void> refreshCounts() async {}

  @override
  Future<void> syncPendingOrders({bool reverseNetTax = false}) async {
    syncCalls++;
  }
}

class TestCustomerNotifier extends CustomerNotifier {
  TestCustomerNotifier({
    required super.partnerService,
    required super.dbHelper,
    required List<PartnerModel> initial,
  }) {
    state = state.copyWith(customers: initial);
  }

  @override
  Future<void> searchCustomers(String query, {bool isOffline = false}) async {
    // Retain initial test customer list without network call
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late OfflineQueueRepository queueRepo;

  setUp(() async {
    dbHelper = DatabaseHelper(customDbPath: inMemoryDatabasePath);
    queueRepo = OfflineQueueRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  // ---------------------------------------------------------------------------
  // 1. ProductModel Book Fields Tests
  // ---------------------------------------------------------------------------
  group('ProductModel Book Fields Specification', () {
    test('fromJson correctly parses bookEdition, bookFormat, bookPublicationYear, and publisherId', () {
      final json = {
        'id': 10,
        'name': 'হিমুর হাতে কয়েকটি নীলপদ্ম',
        'display_name': 'হিমুর হাতে কয়েকটি নীলপদ্ম',
        'list_price': 350.0,
        'is_book': true,
        'book_edition': '2nd Edition',
        'book_format': 'hardcover',
        'book_publication_year': 2023,
        'publisher_id': [45, 'সময় প্রকাশন'],
        'book_qty_on_hand': 25,
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, 10);
      expect(product.bookEdition, '2nd Edition');
      expect(product.bookFormat, 'hardcover');
      expect(product.bookPublicationYear, 2023);
      expect(product.publisherId, 45);
    });

    test('SQLite toMap and fromMap round-trip preserves all 4 book fields', () async {
      const product = ProductModel(
        id: 77,
        name: 'সঞ্চিতা',
        displayName: 'সঞ্চিতা',
        listPrice: 500.0,
        isBook: true,
        bookEdition: 'Centenary Edition',
        bookFormat: 'paperback',
        bookPublicationYear: 1972,
        publisherId: 99,
        bookQtyOnHand: 15,
      );

      await dbHelper.cacheProducts([product]);
      final cached = await dbHelper.getCachedProducts();

      expect(cached.isNotEmpty, isTrue);
      final retrieved = cached.firstWhere((p) => p.id == 77);
      expect(retrieved.bookEdition, 'Centenary Edition');
      expect(retrieved.bookFormat, 'paperback');
      expect(retrieved.bookPublicationYear, 1972);
      expect(retrieved.publisherId, 99);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Connectivity & Auto-Sync Tests
  // ---------------------------------------------------------------------------
  group('Connectivity & Reconnection Auto-Sync', () {
    test('Reconnecting from offline to online triggers syncPendingOrders', () async {
      final fakeConn = FakeConnectivityService();
      addTearDown(fakeConn.dispose);

      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(fakeConn),
          syncQueueProvider.overrideWith((ref) => TestSyncQueueNotifier(
                queueRepo: queueRepo,
                orderService: ref.watch(orderServiceProvider),
                sessionService: ref.watch(sessionServiceProvider),
              )),
        ],
      );
      addTearDown(container.dispose);

      // Start online
      expect(container.read(isOnlineProvider), isTrue);

      // Go offline
      fakeConn.emit(false);
      await pumpEventQueue();
      expect(container.read(isOnlineProvider), isFalse);

      final notifier = container.read(syncQueueProvider.notifier) as TestSyncQueueNotifier;
      expect(notifier.syncCalls, 0);

      // Reconnect to online -> triggers syncPendingOrders automatically
      fakeConn.emit(true);
      await pumpEventQueue();
      expect(container.read(isOnlineProvider), isTrue);
      expect(notifier.syncCalls, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. CustomerSelectorScreen Zero-Mock & Rewire
  // ---------------------------------------------------------------------------
  group('CustomerSelectorScreen Zero-Mock & Riverpod Wiring', () {
    testWidgets('Renders real customer list from customerProvider and mounts LanguageToggleButton',
        (tester) async {
      const realPartner = PartnerModel(
        id: 999,
        name: 'শরীফুল ইসলাম',
        phone: '01700112233',
        city: 'ঢাকা',
      );

      final container = ProviderContainer(
        overrides: [
          customerProvider.overrideWith(
            (ref) => TestCustomerNotifier(
              partnerService: ref.watch(partnerServiceProvider),
              dbHelper: dbHelper,
              initial: [realPartner],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerSelectorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero mock: real customer appears, mock default partners do NOT
      expect(find.text('শরীফুল ইসলাম'), findsOneWidget);
      expect(find.textContaining('01700112233'), findsOneWidget);
      expect(find.text('Kazi Nazrul Islam'), findsNothing);

      // Verify LanguageToggleButton is present in AppBar
      expect(find.byType(LanguageToggleButton), findsOneWidget);

      // Verify clean walk-in customer tile (no bilingual brackets)
      expect(find.text('সাধারণ ক্রেতা'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Localization Across All Screens
  // ---------------------------------------------------------------------------
  group('Localization & LanguageToggleButton Presence Across Screens', () {

    testWidgets('CartOrderScreen mounts LanguageToggleButton and reacts to toggle',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CartOrderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageToggleButton), findsOneWidget);
      expect(find.text('সাধারণ ক্রেতা'), findsOneWidget);

      // Toggle language to English
      container.read(localeProvider.notifier).state = const Locale('en');
      await tester.pumpAndSettle();

      expect(find.text('Walk-in / Guest Customer'), findsOneWidget);
    });

    testWidgets('CheckoutPaymentScreen mounts LanguageToggleButton and switches clean strings',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseHelperProvider.overrideWithValue(dbHelper),
          syncQueueProvider.overrideWith((ref) => TestSyncQueueNotifier(
                queueRepo: queueRepo,
                orderService: ref.watch(orderServiceProvider),
                sessionService: ref.watch(sessionServiceProvider),
              )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CheckoutPaymentScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageToggleButton), findsOneWidget);
    });

    testWidgets('OrderSuccessReceiptScreen renders with null order', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OrderSuccessReceiptScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LanguageToggleButton), findsOneWidget);
    });

    testWidgets('OrderSuccessReceiptScreen dynamically displays sync status and mounts toggle',
        (tester) async {
      final testOrder = OrderModel.create(
        uuid: 'test-uuid-sync-1',
        sessionId: 1,
        lines: [],
        payments: [],
      );

      final statusState = StateProvider<String>((ref) => 'pending');

      final container = ProviderContainer(
        overrides: [
          lastCompletedOrderProvider.overrideWith((ref) => testOrder),
          orderSyncStatusProvider(testOrder.uuid).overrideWith((ref) {
            return ref.watch(statusState);
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OrderSuccessReceiptScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify toggle button present
      expect(find.byType(LanguageToggleButton), findsOneWidget);

      // Verify offline pending status displayed
      expect(find.text('অফলাইনে জমা হয়েছে'), findsOneWidget);

      // Transition to synced
      container.read(statusState.notifier).state = 'synced';
      await tester.pumpAndSettle();

      // Verify status dynamically updates to synced
      expect(find.text('সার্ভারে সংরক্ষিত'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Dynamic Register Selection on SessionLoginScreen
  // ---------------------------------------------------------------------------
  group('Dynamic Register Selection', () {
    testWidgets('SessionLoginScreen displays registers dynamically from sessionState.configs',
        (tester) async {
      final customConfigs = [
        const PosConfigModel(
          id: 10,
          name: 'বইমেলা প্যাভিলিয়ন ১',
          currentSessionState: 'opened',
        ),
        const PosConfigModel(
          id: 20,
          name: 'বইমেলা প্যাভিলিয়ন ২',
          currentSessionState: 'closed',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) {
            final notifier = PosSessionNotifier(
              sessionService: ref.watch(sessionServiceProvider),
            );
            notifier.state = notifier.state.copyWith(configs: customConfigs);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SessionLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify dynamically rendered config names
      expect(find.text('বইমেলা প্যাভিলিয়ন ১'), findsOneWidget);
      expect(find.text('বইমেলা প্যাভিলিয়ন ২'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. ProductModel image128 Specification
  // ---------------------------------------------------------------------------
  group('ProductModel image128 Specification', () {
    test('fromJson parses valid base64 image_128 string', () {
      final json = {
        'id': 62,
        'name': 'Blackbrid Classic',
        'display_name': 'Blackbrid Classic',
        'list_price': 100.0,
        'image_128': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      };
      final product = ProductModel.fromJson(json);
      expect(product.image128, isNotNull);
      expect(product.image128, startsWith('iVBORw'));
    });

    test('fromJson handles Odoo boolean false as null image128', () {
      final json = {
        'id': 63,
        'name': 'Book Without Cover',
        'display_name': 'Book Without Cover',
        'list_price': 150.0,
        'image_128': false,
      };
      final product = ProductModel.fromJson(json);
      expect(product.image128, isNull);
    });

    test('fromJson handles empty string image_128 as null', () {
      final json = {
        'id': 64,
        'name': 'Book With Empty Cover',
        'display_name': 'Book With Empty Cover',
        'list_price': 200.0,
        'image_128': '',
      };
      final product = ProductModel.fromJson(json);
      expect(product.image128, isNull);
    });

    test('toJson and toMap preserve image_128', () {
      const product = ProductModel(
        id: 65,
        name: 'Cover Test Book',
        displayName: 'Cover Test Book',
        listPrice: 250.0,
        image128: 'base64EncodedImageData==',
      );
      final json = product.toJson();
      expect(json['image_128'], 'base64EncodedImageData==');

      final map = product.toMap();
      expect(map['image_128'], 'base64EncodedImageData==');

      final reconstructed = ProductModel.fromMap(map);
      expect(reconstructed.image128, 'base64EncodedImageData==');
      expect(reconstructed == product, isTrue);
    });

    test('copyWith updates or preserves image128', () {
      const product = ProductModel(
        id: 66,
        name: 'Copy Test Book',
        displayName: 'Copy Test Book',
        listPrice: 300.0,
        image128: 'originalImage',
      );
      final updated = product.copyWith(image128: 'newImage');
      expect(updated.image128, 'newImage');

      final preserved = product.copyWith(name: 'Renamed Book');
      expect(preserved.image128, 'originalImage');
    });
  });

  // ---------------------------------------------------------------------------
  // 7. OrderModel isSynced Specification
  // ---------------------------------------------------------------------------
  group('OrderModel isSynced & Serialization Specification', () {
    test('OrderModel constructor and create default isSynced to false', () {
      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
      );
      expect(order.isSynced, isFalse);
    });

    test('OrderModel accepts isSynced true in constructor and create', () {
      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
        isSynced: true,
      );
      expect(order.isSynced, isTrue);

      final copy = order.copyWith(isSynced: false);
      expect(copy.isSynced, isFalse);
    });

    test('toJson and fromJson serialize is_synced', () {
      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
        isSynced: true,
      );
      final json = order.toJson();
      expect(json['is_synced'], isTrue);

      final parsed = OrderModel.fromJson(json);
      expect(parsed.isSynced, isTrue);
    });

    test('toMap and fromMap preserve sync status and is_synced', () {
      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
        isSynced: true,
      );
      final map = order.toMap();
      expect(map['sync_status'], 'synced');
      expect(map['is_synced'], 1);

      final reconstructed = OrderModel.fromMap(map);
      expect(reconstructed.isSynced, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. DatabaseHelper Schema Version 3 Migration
  // ---------------------------------------------------------------------------
  group('DatabaseHelper Schema Version 3 Migration Specification', () {
    test('cached_products table has image_128 column in schema version 3', () async {
      final db = await dbHelper.database;
      final columns = await db.rawQuery("PRAGMA table_info('cached_products')");
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('image_128'), isTrue);
    });

    test('DatabaseHelper caches and retrieves products with image_128', () async {
      const product = ProductModel(
        id: 999,
        name: 'Database Image Test',
        displayName: 'Database Image Test',
        listPrice: 400.0,
        image128: 'img_test_data_base64',
      );
      await dbHelper.cacheProducts([product]);
      final cached = await dbHelper.getCachedProducts();
      final retrieved = cached.firstWhere((p) => p.id == 999);
      expect(retrieved.image128, 'img_test_data_base64');
    });
  });

  // ---------------------------------------------------------------------------
  // 9. CatalogRepository Specification
  // ---------------------------------------------------------------------------
  group('CatalogRepository Specification', () {
    test('getCatalog returns cached products when offline', () async {
      const product = ProductModel(
        id: 888,
        name: 'Offline Catalog Book',
        displayName: 'Offline Catalog Book',
        listPrice: 200.0,
      );
      await dbHelper.cacheProducts([product]);

      final mockClient = MockClient((_) async => throw Exception('Network unreachable'));
      final jsonClient = OdooJsonRpcClient(baseUrl: 'https://test.odoo', httpClient: mockClient);
      final catalogService = OdooCatalogService(client: jsonClient);
      final repo = CatalogRepositoryImpl(dbHelper: dbHelper, catalogService: catalogService);

      final catalog = await repo.getCatalog(isOffline: true);
      expect(catalog.any((p) => p.id == 888), isTrue);
    });

    test('searchProducts filters cached products by query', () async {
      const product1 = ProductModel(
        id: 881,
        name: 'গীতাঞ্জলি',
        displayName: 'গীতাঞ্জলি',
        listPrice: 300.0,
        bookAuthorsDisplay: 'রবীন্দ্রনাথ ঠাকুর',
      );
      const product2 = ProductModel(
        id: 882,
        name: 'অগ্নিবীণা',
        displayName: 'অগ্নিবীণা',
        listPrice: 250.0,
        bookAuthorsDisplay: 'কাজী নজরুল ইসলাম',
      );
      await dbHelper.cacheProducts([product1, product2]);

      final mockClient = MockClient((_) async => http.Response('{}', 200));
      final jsonClient = OdooJsonRpcClient(baseUrl: 'https://test.odoo', httpClient: mockClient);
      final catalogService = OdooCatalogService(client: jsonClient);
      final repo = CatalogRepositoryImpl(dbHelper: dbHelper, catalogService: catalogService);

      final searchResults = await repo.searchProducts('নজরুল');
      expect(searchResults.length, 1);
      expect(searchResults.first.id, 882);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. OrderRepository Specification
  // ---------------------------------------------------------------------------
  group('OrderRepository Specification', () {
    test('submitOrder enqueues locally and marks synced when online submission succeeds', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'result': {
              'pos.order': [
                {'id': 101, 'pos_reference': '264-1-000001'}
              ]
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final jsonClient = OdooJsonRpcClient(baseUrl: 'https://test.odoo', httpClient: mockClient);
      final orderService = OdooOrderService(client: jsonClient);
      final sessionService = OdooSessionService(client: jsonClient);
      final repo = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
      );

      final submitted = await repo.submitOrder(
        order,
        isOnline: true,
        isOfflineMode: false,
      );

      expect(submitted.isSynced, isTrue);
      final status = await repo.getOrderSyncStatus(order.uuid);
      expect(status, 'synced');
      expect(await repo.getSyncedCount(), 1);
      expect(await repo.getPendingCount(), 0);
    });

    test('submitOrder keeps order pending in queue when offline or offlineMode is active', () async {
      final mockClient = MockClient((_) async => throw Exception('Should not be called'));
      final jsonClient = OdooJsonRpcClient(baseUrl: 'https://test.odoo', httpClient: mockClient);
      final orderService = OdooOrderService(client: jsonClient);
      final sessionService = OdooSessionService(client: jsonClient);
      final repo = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
      );

      // Offline mode active
      final submitted = await repo.submitOrder(
        order,
        isOnline: true,
        isOfflineMode: true,
      );

      expect(submitted.isSynced, isFalse);
      final status = await repo.getOrderSyncStatus(order.uuid);
      expect(status, 'pending');
      expect(await repo.getPendingCount(), 1);
    });

    test('submitOrder safely queues order and marks failed on network error without data loss', () async {
      final mockClient = MockClient((_) async {
        throw Exception('Connection reset by peer');
      });
      final jsonClient = OdooJsonRpcClient(baseUrl: 'https://test.odoo', httpClient: mockClient);
      final orderService = OdooOrderService(client: jsonClient);
      final sessionService = OdooSessionService(client: jsonClient);
      final repo = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      final order = OrderModel.create(
        sessionId: 1,
        lines: [],
        payments: [],
      );

      final submitted = await repo.submitOrder(
        order,
        isOnline: true,
        isOfflineMode: false,
      );

      expect(submitted.isSynced, isFalse);
      final status = await repo.getOrderSyncStatus(order.uuid);
      expect(status, 'failed');
      expect(await repo.getPendingCount(), 1);

      // Verify order is retrievable from local queue
      final retrieved = await repo.getOrder(order.uuid);
      expect(retrieved, isNotNull);
      expect(retrieved!.uuid, order.uuid);
    });
  });
}
