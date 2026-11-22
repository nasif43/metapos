import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/core/localization/locale_provider.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/models/pos_config_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/data/repositories/order_repository.dart';
import 'package:metapos/presentation/screens/receipt/order_success_receipt_screen.dart';
import 'package:metapos/providers/order_provider.dart';
import 'package:metapos/providers/printer_provider.dart';
import 'package:metapos/providers/sync_queue_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Test Fakes
// ---------------------------------------------------------------------------
class FakeOdooOrderService extends OdooOrderService {
  final List<OrderModel> submittedOrders = [];
  bool shouldThrow = false;
  String errorMessage = 'Connection failed';

  FakeOdooOrderService()
      : super(
          client: OdooJsonRpcClient(
            baseUrl: 'https://demostore.metaposbd.com',
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          ),
        );

  @override
  Future<Map<String, dynamic>> syncSingleOrder(
    OrderModel order, {
    bool reverseNetTax = false,
  }) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    submittedOrders.add(order);
    return {
      'pos.order': [
        {
          'id': 1001,
          'pos_reference': order.posReference,
          'session_id': order.sessionId,
        }
      ]
    };
  }
}

/// Fake order service that simulates a closed session error for a specific session ID,
/// but succeeds for any other session ID (e.g., re-bound Session 23).
class SessionAwareFakeOrderService extends FakeOdooOrderService {
  final int closedSessionId;

  SessionAwareFakeOrderService({this.closedSessionId = 1});

  @override
  Future<Map<String, dynamic>> syncSingleOrder(
    OrderModel order, {
    bool reverseNetTax = false,
  }) async {
    if (order.sessionId == closedSessionId) {
      throw Exception('OdooServerException: The POS session $closedSessionId is closed.');
    }
    return super.syncSingleOrder(order, reverseNetTax: reverseNetTax);
  }
}

/// Fake order service that selectively fails for a designated order UUID,
/// while allowing all other orders in the queue flush to succeed.
class SelectiveFailureFakeOrderService extends FakeOdooOrderService {
  final String failUuid;

  SelectiveFailureFakeOrderService({required this.failUuid});

  @override
  Future<Map<String, dynamic>> syncSingleOrder(
    OrderModel order, {
    bool reverseNetTax = false,
  }) async {
    if (order.uuid == failUuid) {
      throw Exception('Validation Error on Order ${order.uuid}');
    }
    return super.syncSingleOrder(order, reverseNetTax: reverseNetTax);
  }
}

class FakeOdooSessionService extends OdooSessionService {
  int currentOpenSessionId = 23;

  FakeOdooSessionService()
      : super(
          client: OdooJsonRpcClient(
            baseUrl: 'https://demostore.metaposbd.com',
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          ),
        );

  @override
  Future<List<PosConfigModel>> searchConfigs({
    List<dynamic> domain = const [],
    int limit = 80,
  }) async {
    return [
      PosConfigModel(
        id: 1,
        name: 'Book Fair Stall #1',
        currentSessionId: currentOpenSessionId,
        currentSessionState: 'opened',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late OfflineQueueRepository queueRepo;
  late FakeOdooOrderService orderService;
  late FakeOdooSessionService sessionService;
  late OrderRepository orderRepository;

  setUp(() async {
    dbHelper = DatabaseHelper(customDbPath: inMemoryDatabasePath);
    queueRepo = OfflineQueueRepository(dbHelper: dbHelper);
    orderService = FakeOdooOrderService();
    sessionService = FakeOdooSessionService();

    orderRepository = OrderRepositoryImpl(
      queueRepo: queueRepo,
      orderService: orderService,
      sessionService: sessionService,
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  OrderModel createTestOrder({
    int sessionId = 23,
    int configId = 1,
    double amount = 100.0,
    bool isSynced = false,
  }) {
    final line = OrderLineModel.create(
      productId: 62,
      productName: 'ব্ল্যাকবার্ড ক্লাসিক',
      qty: 1.0,
      priceUnit: amount,
      isTaxInclusive: true,
    );
    final payment = PaymentLineModel.create(
      paymentMethodId: 1,
      paymentMethodName: 'নগদ (Cash)',
      amount: amount,
      sessionId: sessionId,
    );
    return OrderModel.create(
      sessionId: sessionId,
      configId: configId,
      lines: [line],
      payments: [payment],
      isSynced: isSynced,
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Direct Online Order Submission to Odoo 19
  // ---------------------------------------------------------------------------
  group('Direct Online Order Submission to Odoo 19 (Requirement R2)', () {
    test('Online order is submitted directly to Odoo 19 pos.order and marked isSynced == true', () async {
      final initialOrder = createTestOrder(sessionId: 23);
      expect(initialOrder.isSynced, isFalse);

      final completedOrder = await orderRepository.submitOrder(
        initialOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      // 1. Must invoke Odoo 19 sync service
      expect(orderService.submittedOrders.length, 1);
      expect(orderService.submittedOrders.first.uuid, initialOrder.uuid);

      // 2. Returned model has isSynced == true
      expect(completedOrder.isSynced, isTrue);

      // 3. SQLite record has status 'synced' and synced_at populated
      final record = await queueRepo.getOrder(initialOrder.uuid);
      expect(record, isNotNull);
      expect(record!['sync_status'], 'synced');
      expect(record['synced_at'], isNotNull);

      // 4. Counts reflect 0 pending, 1 synced
      expect(await orderRepository.getPendingCount(), 0);
      expect(await orderRepository.getSyncedCount(), 1);
    });

    test('Offline mode toggle takes precedence over physical online connection', () async {
      final order = createTestOrder(sessionId: 23);

      // User chose "offline mode" at login, even though wifi is active
      final completedOrder = await orderRepository.submitOrder(
        order,
        isOnline: true,
        isOfflineMode: true,
      );

      // 1. Must NOT submit to Odoo backend
      expect(orderService.submittedOrders, isEmpty);

      // 2. Returned model has isSynced == false
      expect(completedOrder.isSynced, isFalse);

      // 3. SQLite record has status 'pending'
      final record = await queueRepo.getOrder(order.uuid);
      expect(record!['sync_status'], 'pending');
      expect(record['synced_at'], isNull);

      // 4. Counts reflect 1 pending, 0 synced
      expect(await orderRepository.getPendingCount(), 1);
      expect(await orderRepository.getSyncedCount(), 0);
    });

    test('No internet connectivity enqueues to SQLite without throwing', () async {
      final order = createTestOrder(sessionId: 23);

      final completedOrder = await orderRepository.submitOrder(
        order,
        isOnline: false,
        isOfflineMode: false,
      );

      expect(orderService.submittedOrders, isEmpty);
      expect(completedOrder.isSynced, isFalse);

      final record = await queueRepo.getOrder(order.uuid);
      expect(record!['sync_status'], 'pending');
      expect(await orderRepository.getPendingCount(), 1);
      expect(await orderRepository.getSyncedCount(), 0);
    });

    test('Network failure during online submission marks SQLite record failed and increments retry', () async {
      orderService.shouldThrow = true;
      orderService.errorMessage = 'SocketException: Connection refused (OS Error: Connection refused, errno = 111)';

      final order = createTestOrder(sessionId: 23);
      final completedOrder = await orderRepository.submitOrder(
        order,
        isOnline: true,
        isOfflineMode: false,
      );

      expect(completedOrder.isSynced, isFalse);

      final record = await queueRepo.getOrder(order.uuid);
      expect(record!['sync_status'], 'failed');
      expect(record['retry_count'], 1);
      expect(record['last_error'], contains('Connection refused'));
    });

    test('Automated session re-binding recovers when closed session 1 error occurs', () async {
      // 1. Configure session service to advertise open Session 23 for Register 1
      sessionService.currentOpenSessionId = 23;

      // 2. Create stale order targeting closed Session 1
      final staleOrder = createTestOrder(sessionId: 1, configId: 1);

      // 3. Instantiate SessionAwareFakeOrderService which rejects Session 1 and accepts Session 23
      final customService = SessionAwareFakeOrderService(closedSessionId: 1);
      final customRepo = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: customService,
        sessionService: sessionService,
      );

      // 4. Submit stale order targeting Session 1
      final completedOrder = await customRepo.submitOrder(
        staleOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      // 5. Returned order must be marked synced and re-bound to Session 23
      expect(completedOrder.isSynced, isTrue);
      expect(completedOrder.sessionId, 23);

      // 6. SQLite record in local_orders must reflect session_id 23 and sync_status 'synced'
      final record = await queueRepo.getOrder(staleOrder.uuid);
      expect(record, isNotNull);
      expect(record!['session_id'], 23);
      expect(record['sync_status'], 'synced');
      expect(record['synced_at'], isNotNull);

      // 7. Verify remote service received exactly 1 successful submission with sessionId 23
      expect(customService.submittedOrders.length, 1);
      expect(customService.submittedOrders.first.sessionId, 23);
      expect(customService.submittedOrders.first.uuid, staleOrder.uuid);

      // 8. Queue counters reflect 0 pending, 1 synced
      expect(await customRepo.getPendingCount(), 0);
      expect(await customRepo.getSyncedCount(), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Receipt Screen Sync Status Resolution
  // ---------------------------------------------------------------------------
  group('Receipt Screen Status Resolution (Requirement R2)', () {
    testWidgets('Online synced order displays "সার্ভারে সংরক্ষিত" and cloud-done icon on initial frame',
        (tester) async {
      final order = createTestOrder(sessionId: 23, isSynced: true);

      final container = ProviderContainer(
        overrides: [
          lastCompletedOrderProvider.overrideWith((ref) => order),
          orderSyncStatusProvider.overrideWith((ref, uuid) async => 'synced'),
          printerProvider.overrideWith((ref) => PrinterNotifier(simulationDelay: Duration.zero)),
          localeProvider.overrideWith((ref) => const Locale('bn')),
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
      await tester.pump();

      // Must display "সার্ভারে সংরক্ষিত"
      expect(find.text('সার্ভারে সংরক্ষিত'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // Must NOT display "অফলাইনে জমা হয়েছে"
      expect(find.text('অফলাইনে জমা হয়েছে'), findsNothing);
      expect(find.byIcon(Icons.cloud_queue_rounded), findsNothing);
    });

    testWidgets('Online synced order displays "Synced with Cloud" in English mode',
        (tester) async {
      final order = createTestOrder(sessionId: 23, isSynced: true);

      final container = ProviderContainer(
        overrides: [
          lastCompletedOrderProvider.overrideWith((ref) => order),
          orderSyncStatusProvider.overrideWith((ref, uuid) async => 'synced'),
          printerProvider.overrideWith((ref) => PrinterNotifier(simulationDelay: Duration.zero)),
          localeProvider.overrideWith((ref) => const Locale('en')),
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
      await tester.pump();

      expect(find.textContaining('Synced with Cloud'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      expect(find.textContaining('Queued Locally'), findsNothing);
    });

    testWidgets('Offline queued order displays "অফলাইনে জমা হয়েছে" and cloud-queue icon',
        (tester) async {
      final order = createTestOrder(sessionId: 23, isSynced: false);

      final container = ProviderContainer(
        overrides: [
          lastCompletedOrderProvider.overrideWith((ref) => order),
          orderSyncStatusProvider.overrideWith((ref, uuid) async => 'pending'),
          printerProvider.overrideWith((ref) => PrinterNotifier(simulationDelay: Duration.zero)),
          localeProvider.overrideWith((ref) => const Locale('bn')),
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
      await tester.pump();

      expect(find.text('অফলাইনে জমা হয়েছে'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
      expect(find.text('সার্ভারে সংরক্ষিত'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Offline Queue Fallback & FIFO Flush on Reconnection
  // ---------------------------------------------------------------------------
  group('Offline Queue Fallback & FIFO Queue Flush (Requirement R2)', () {
    test('Multiple offline orders are enqueued and flushed sequentially on reconnection', () async {
      final order1 = createTestOrder(amount: 100.0);
      final order2 = createTestOrder(amount: 250.0);
      final order3 = createTestOrder(amount: 500.0);

      // Submit 3 orders while offline
      await orderRepository.submitOrder(order1, isOnline: false, isOfflineMode: false);
      await orderRepository.submitOrder(order2, isOnline: false, isOfflineMode: false);
      await orderRepository.submitOrder(order3, isOnline: false, isOfflineMode: false);

      expect(await orderRepository.getPendingCount(), 3);
      expect(await orderRepository.getSyncedCount(), 0);

      // Reconnect and trigger FIFO flush
      await orderRepository.syncPendingOrders();

      // All 3 orders synced in FIFO sequence
      expect(orderService.submittedOrders.length, 3);
      expect(orderService.submittedOrders[0].uuid, order1.uuid);
      expect(orderService.submittedOrders[1].uuid, order2.uuid);
      expect(orderService.submittedOrders[2].uuid, order3.uuid);

      // Counters updated in SQLite
      expect(await orderRepository.getPendingCount(), 0);
      expect(await orderRepository.getSyncedCount(), 3);

      final rec1 = await queueRepo.getOrder(order1.uuid);
      final rec2 = await queueRepo.getOrder(order2.uuid);
      final rec3 = await queueRepo.getOrder(order3.uuid);
      expect(rec1!['sync_status'], 'synced');
      expect(rec2!['sync_status'], 'synced');
      expect(rec3!['sync_status'], 'synced');
    });

    test('Queue flush continues through subsequent orders if one order fails', () async {
      final order1 = createTestOrder(amount: 100.0);
      final order2 = createTestOrder(amount: 200.0);

      // Enqueue both orders while offline
      await orderRepository.submitOrder(order1, isOnline: false, isOfflineMode: false);
      await orderRepository.submitOrder(order2, isOnline: false, isOfflineMode: false);

      expect(await orderRepository.getPendingCount(), 2);
      expect(await orderRepository.getSyncedCount(), 0);

      // Use SelectiveFailureFakeOrderService configured to fail order1 only
      final selectiveService = SelectiveFailureFakeOrderService(failUuid: order1.uuid);
      final selectiveRepo = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: selectiveService,
        sessionService: sessionService,
      );

      await selectiveRepo.syncPendingOrders();

      // 1. Order 1 must be marked failed and retry counter incremented
      final rec1 = await queueRepo.getOrder(order1.uuid);
      expect(rec1, isNotNull);
      expect(rec1!['sync_status'], 'failed');
      expect(rec1['retry_count'], 1);
      expect(rec1['last_error'], contains('Validation Error on Order'));

      // 2. Order 2 must be successfully synchronized despite preceding failure
      final rec2 = await queueRepo.getOrder(order2.uuid);
      expect(rec2, isNotNull);
      expect(rec2!['sync_status'], 'synced');
      expect(rec2['synced_at'], isNotNull);

      // 3. Remote service recorded submission of order2, but NOT order1
      expect(selectiveService.submittedOrders.length, 1);
      expect(selectiveService.submittedOrders.first.uuid, order2.uuid);

      // 4. Queue counters reflect 1 pending (failed order remains in queue for replay), 1 synced
      expect(await selectiveRepo.getPendingCount(), 1);
      expect(await selectiveRepo.getSyncedCount(), 1);
    });
  });
}
