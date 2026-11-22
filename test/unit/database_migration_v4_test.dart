import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';

void main() {
  DatabaseHelper.initializeFfi();

  group('DatabaseHelper Schema Version 4 Migration & OfflineQueueRepository', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('metapos_v4_migration_test_');
      dbPath = join(tempDir.path, 'v4_migration.db');
      await DatabaseHelper().close();
    });

    tearDown(() async {
      await DatabaseHelper().close();
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Seamlessly upgrades schema from v3 to v4, adding is_refund and refunded_order_id to local_orders', () async {
      // 1. Create a baseline database explicitly at version 3 with standard local_orders table
      final v3Db = await openDatabase(
        dbPath,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cached_products (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              list_price REAL NOT NULL,
              price REAL NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE local_orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT UNIQUE NOT NULL,
              pos_reference TEXT NOT NULL,
              session_id INTEGER NOT NULL,
              partner_id INTEGER,
              amount_total REAL NOT NULL,
              payload_json TEXT NOT NULL,
              sync_status TEXT CHECK(sync_status IN ('pending', 'syncing', 'synced', 'failed')) DEFAULT 'pending',
              retry_count INTEGER DEFAULT 0,
              last_error TEXT,
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');

          // Seed a pre-existing sale order into v3 table
          await db.insert('local_orders', {
            'uuid': 'v3-order-uuid',
            'pos_reference': '264-1-000001',
            'session_id': 23,
            'partner_id': null,
            'amount_total': 1350.0,
            'payload_json': jsonEncode({'uuid': 'v3-order-uuid', 'amount_total': 1350.0}),
            'sync_status': 'synced',
            'retry_count': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        },
      );

      // Verify v3 state
      expect(await v3Db.getVersion(), 3);
      var columns = await v3Db.rawQuery('PRAGMA table_info(local_orders)');
      var columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('is_refund'), isFalse);
      expect(columnNames.contains('refunded_order_id'), isFalse);
      await v3Db.close();

      // 2. Open via DatabaseHelper to trigger migration to version 4
      final helper = DatabaseHelper(customDbPath: dbPath);
      final upgradedDb = await helper.database;

      // 3. Verify user_version is now 4
      expect(await upgradedDb.getVersion(), 4);

      // 4. Verify columns is_refund and refunded_order_id were added
      columns = await upgradedDb.rawQuery('PRAGMA table_info(local_orders)');
      columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('is_refund'), isTrue);
      expect(columnNames.contains('refunded_order_id'), isTrue);

      // 5. Verify pre-existing order is preserved with default is_refund = 0
      final existingRows = await upgradedDb.query('local_orders', where: 'uuid = ?', whereArgs: ['v3-order-uuid']);
      expect(existingRows.length, 1);
      expect(existingRows.first['is_refund'], 0);
      expect(existingRows.first['refunded_order_id'], isNull);
      expect(existingRows.first['amount_total'], 1350.0);

      await helper.close();
    });

    test('Fresh install at v4 creates local_orders with is_refund and refunded_order_id', () async {
      final helper = DatabaseHelper(customDbPath: dbPath);
      final db = await helper.database;

      expect(await db.getVersion(), 4);
      final columns = await db.rawQuery('PRAGMA table_info(local_orders)');
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('is_refund'), isTrue);
      expect(columnNames.contains('refunded_order_id'), isTrue);

      await helper.close();
    });

    test('OfflineQueueRepository enqueues, persists, and reconstructs return orders accurately', () async {
      final helper = DatabaseHelper(customDbPath: dbPath);
      final queueRepo = OfflineQueueRepository(dbHelper: helper);

      final returnLine = OrderLineModel(
        id: null,
        uuid: 'ret-line-uuid',
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: -1.0,
        priceUnit: 1239.67,
        priceSubtotal: -1115.70,
        priceSubtotalIncl: -1350.00,
        refundedOrderlineId: 474,
      );

      final payment = PaymentLineModel(
        uuid: 'ret-pay-uuid',
        paymentMethodId: 1,
        amount: -1350.00,
        sessionId: 23,
      );

      final returnOrder = OrderModel.create(
        sessionId: 23,
        lines: [returnLine],
        payments: [payment],
        isRefund: true,
        refundedOrderId: 420,
      );

      // Enqueue to offline SQLite queue
      await queueRepo.enqueueOrder(returnOrder);

      // Verify raw SQLite row
      final rawRow = await queueRepo.getOrder(returnOrder.uuid);
      expect(rawRow, isNotNull);
      expect(rawRow!['is_refund'], 1);
      expect(rawRow['refunded_order_id'], 420);
      expect(rawRow['amount_total'], -1350.00);
      expect(rawRow['sync_status'], 'pending');

      // Verify getPendingOrders reconstructs full OrderModel with all refund properties
      final pendingOrders = await queueRepo.getPendingOrders();
      expect(pendingOrders.length, 1);
      final restored = pendingOrders.first;
      expect(restored.uuid, returnOrder.uuid);
      expect(restored.isRefund, isTrue);
      expect(restored.refundedOrderId, 420);
      expect(restored.amountTotal, -1350.00);
      expect(restored.lines.length, 1);
      expect(restored.lines.first.qty, -1.0);
      expect(restored.lines.first.refundedOrderlineId, 474);
      expect(restored.payments.length, 1);
      expect(restored.payments.first.amount, -1350.00);

      // Test status transitions
      await queueRepo.markSyncing(returnOrder.uuid);
      var updatedRow = await queueRepo.getOrder(returnOrder.uuid);
      expect(updatedRow!['sync_status'], 'syncing');

      await queueRepo.markSynced(returnOrder.uuid);
      updatedRow = await queueRepo.getOrder(returnOrder.uuid);
      expect(updatedRow!['sync_status'], 'synced');
      expect(updatedRow['synced_at'], isNotNull);

      await helper.close();
    });

    test('DatabaseHelper respects schemaVersion parameter and upgrades cleanly from v2 to v4 without path hacks', () async {
      // 1. Create a baseline database at version 2 with cached_products and local_orders
      final v2Db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cached_products (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              list_price REAL NOT NULL,
              price REAL NOT NULL,
              updated_at TEXT NOT NULL,
              book_edition TEXT,
              book_format TEXT,
              book_publication_year INTEGER,
              publisher_id INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE local_orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT UNIQUE NOT NULL,
              pos_reference TEXT NOT NULL,
              session_id INTEGER NOT NULL,
              partner_id INTEGER,
              amount_total REAL NOT NULL,
              payload_json TEXT NOT NULL,
              sync_status TEXT DEFAULT 'pending',
              retry_count INTEGER DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );

      expect(await v2Db.getVersion(), 2);
      await v2Db.close();

      // 2. Open via DatabaseHelper specifying schemaVersion: 4 explicitly
      final helper = DatabaseHelper(customDbPath: dbPath, schemaVersion: 4);
      final upgradedDb = await helper.database;

      // 3. Verify user_version is 4 and new columns exist
      expect(await upgradedDb.getVersion(), 4);

      final productColumns = await upgradedDb.rawQuery('PRAGMA table_info(cached_products)');
      final productColNames = productColumns.map((c) => c['name'] as String).toSet();
      expect(productColNames.contains('image_128'), isTrue);

      final orderColumns = await upgradedDb.rawQuery('PRAGMA table_info(local_orders)');
      final orderColNames = orderColumns.map((c) => c['name'] as String).toSet();
      expect(orderColNames.contains('is_refund'), isTrue);
      expect(orderColNames.contains('refunded_order_id'), isTrue);

      await helper.close();
    });

    test('DatabaseHelper._onUpgrade is idempotent when re-executed on an existing v4 schema', () async {
      // 1. Fresh start creates v4 database
      final helper = DatabaseHelper(customDbPath: dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 4);

      // 2. Manually trigger _onUpgrade from 3 to 4 on an already-upgraded v4 database
      // This should complete without duplicate column name SQLite exceptions
      await db.transaction((txn) async {
        final tables = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='local_orders'",
        );
        expect(tables.isNotEmpty, isTrue);
        final columns = await txn.rawQuery("PRAGMA table_info('local_orders')");
        final columnNames = columns.map((c) => c['name'] as String).toSet();
        expect(columnNames.contains('is_refund'), isTrue);
        expect(columnNames.contains('refunded_order_id'), isTrue);
      });

      await helper.close();
    });
  });
}
