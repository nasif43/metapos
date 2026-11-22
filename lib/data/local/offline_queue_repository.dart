import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../models/order_model.dart';
import 'database_helper.dart';

/// Repository managing local persistence and FIFO synchronization of offline orders.
class OfflineQueueRepository {
  final DatabaseHelper dbHelper;

  OfflineQueueRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper();

  /// Enqueues an order for background synchronization with status `pending`.
  Future<void> enqueueOrder(OrderModel order) async {
    final db = await dbHelper.database;
    final row = {
      'uuid': order.uuid,
      'pos_reference': order.posReference,
      'session_id': order.sessionId,
      'partner_id': order.partnerId,
      'amount_total': order.amountTotal,
      'payload_json': jsonEncode(order.toJson()),
      'sync_status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': order.createdAt.toIso8601String(),
      'synced_at': null,
      'is_refund': order.isRefund ? 1 : 0,
      'refunded_order_id': order.refundedOrderId,
    };

    await db.insert(
      'local_orders',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves pending and failed orders ordered by `created_at ASC` (FIFO replay).
  Future<List<OrderModel>> getPendingOrders() async {
    final db = await dbHelper.database;
    final results = await db.query(
      'local_orders',
      where: 'sync_status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );

    final List<OrderModel> orders = [];
    for (final row in results) {
      try {
        final payloadJsonStr = row['payload_json'] as String;
        final decoded = jsonDecode(payloadJsonStr) as Map<String, dynamic>;
        orders.add(OrderModel.fromJson(decoded));
      } catch (_) {
        // Fallback reconstruction if payload_json is directly Odoo sync format
        try {
          orders.add(OrderModel.fromMap(row));
        } catch (_) {}
      }
    }
    return orders;
  }

  /// Marks an order as actively syncing to prevent duplicate concurrent dispatches.
  Future<void> markSyncing(String uuid) async {
    final db = await dbHelper.database;
    await db.update(
      'local_orders',
      {'sync_status': 'syncing'},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Marks an order as successfully synced to Odoo.
  Future<void> markSynced(String uuid) async {
    final db = await dbHelper.database;
    await db.update(
      'local_orders',
      {
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
        'last_error': null,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Marks an order as failed with error details for retry on reconnection.
  Future<void> markFailed(String uuid, String error) async {
    final db = await dbHelper.database;
    await db.update(
      'local_orders',
      {
        'sync_status': 'failed',
        'last_error': error,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Increments the retry counter for an order.
  Future<void> incrementRetry(String uuid) async {
    final db = await dbHelper.database;
    await db.rawUpdate('''
      UPDATE local_orders 
      SET retry_count = retry_count + 1 
      WHERE uuid = ?
    ''', [uuid]);
  }

  /// Re-binds an order to a newly opened session when the original session was closed server-side.
  Future<void> updateOrderSession(
    String uuid,
    int newSessionId,
    String updatedPayloadJson,
  ) async {
    final db = await dbHelper.database;
    await db.update(
      'local_orders',
      {
        'session_id': newSessionId,
        'payload_json': updatedPayloadJson,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Retrieves raw order record row by UUID.
  Future<Map<String, dynamic>?> getOrder(String uuid) async {
    final db = await dbHelper.database;
    final results = await db.query(
      'local_orders',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Retrieves all orders stored in local queue.
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await dbHelper.database;
    return await db.query('local_orders', orderBy: 'created_at DESC');
  }

  /// Returns count of pending/failed orders awaiting sync.
  Future<int> getPendingCount() async {
    final db = await dbHelper.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM local_orders WHERE sync_status IN ('pending', 'failed', 'syncing')
    '''));
    return count ?? 0;
  }

  /// Returns count of successfully synced orders.
  Future<int> getSyncedCount() async {
    final db = await dbHelper.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM local_orders WHERE sync_status = 'synced'
    '''));
    return count ?? 0;
  }

  /// Clears all orders from local database.
  Future<void> clearQueue() async {
    final db = await dbHelper.database;
    await db.delete('local_orders');
  }
}
