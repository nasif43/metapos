import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for unit tests on Linux
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late OfflineQueueRepository repository;

  setUp(() async {
    // Use an in-memory database path for isolated, fast unit testing
    dbHelper = DatabaseHelper(customDbPath: inMemoryDatabasePath);
    repository = OfflineQueueRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('OfflineQueueRepository Unit Tests', () {
    test('Enqueuing order inserts into SQLite with pending status', () async {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );

      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 110.0,
      );

      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
      );

      await repository.enqueueOrder(order);

      final pendingOrders = await repository.getPendingOrders();
      expect(pendingOrders.length, 1);
      expect(pendingOrders.first.uuid, order.uuid);
      expect(pendingOrders.first.amountTotal, order.amountTotal);

      final pendingCount = await repository.getPendingCount();
      expect(pendingCount, 1);

      final syncedCount = await repository.getSyncedCount();
      expect(syncedCount, 0);
    });

    test('Status transitions: pending -> syncing -> synced', () async {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 110.0,
      );
      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
      );

      await repository.enqueueOrder(order);

      // 1. Mark syncing
      await repository.markSyncing(order.uuid);
      var record = await repository.getOrder(order.uuid);
      expect(record?['sync_status'], 'syncing');

      // 2. Mark synced
      await repository.markSynced(order.uuid);
      record = await repository.getOrder(order.uuid);
      expect(record?['sync_status'], 'synced');
      expect(record?['synced_at'], isNotNull);

      // Once synced, it should not be returned by getPendingOrders()
      final pendingOrders = await repository.getPendingOrders();
      expect(pendingOrders.isEmpty, isTrue);

      final syncedCount = await repository.getSyncedCount();
      expect(syncedCount, 1);
    });

    test('Failure handling: marks failed with error and increments retry count', () async {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 110.0,
      );
      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
      );

      await repository.enqueueOrder(order);

      await repository.markFailed(order.uuid, 'Network timeout connecting to Odoo');
      await repository.incrementRetry(order.uuid);
      await repository.incrementRetry(order.uuid);

      final record = await repository.getOrder(order.uuid);
      expect(record?['sync_status'], 'failed');
      expect(record?['last_error'], contains('Network timeout'));
      expect(record?['retry_count'], 2);

      // Failed orders must still be returned in getPendingOrders() for retry
      final pending = await repository.getPendingOrders();
      expect(pending.length, 1);
      expect(pending.first.uuid, order.uuid);
    });

    test('FIFO ordering: orders are retrieved in chronological created_at ASC order', () async {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 110.0,
      );

      final order1 = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
        createdAt: DateTime(2026, 11, 19, 10, 0, 0),
      );

      final order2 = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
        createdAt: DateTime(2026, 11, 19, 10, 5, 0),
      );

      final order3 = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
        createdAt: DateTime(2026, 11, 19, 10, 10, 0),
      );

      // Insert in reverse order
      await repository.enqueueOrder(order3);
      await repository.enqueueOrder(order1);
      await repository.enqueueOrder(order2);

      // Retrieve
      final pending = await repository.getPendingOrders();
      expect(pending.length, 3);
      expect(pending[0].uuid, order1.uuid);
      expect(pending[1].uuid, order2.uuid);
      expect(pending[2].uuid, order3.uuid);
    });

    test('Session re-binding updates local_orders row session_id and payload_json', () async {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 110.0,
        sessionId: 14,
      );
      final order = OrderModel.create(
        sessionId: 14, // Closed session
        lines: [line],
        payments: [payment],
      );

      await repository.enqueueOrder(order);

      const int newSessionId = 15;
      final remapped = order.copyWithSession(newSessionId);
      final updatedPayload = jsonEncode(remapped.toJson());

      await repository.updateOrderSession(order.uuid, newSessionId, updatedPayload);

      final record = await repository.getOrder(order.uuid);
      expect(record?['session_id'], newSessionId);

      final pending = await repository.getPendingOrders();
      expect(pending.first.sessionId, newSessionId);
    });
  });
}
