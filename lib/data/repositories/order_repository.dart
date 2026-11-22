import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/offline_queue_repository.dart';
import '../models/order_model.dart';
import '../remote/odoo_order_service.dart';
import '../remote/odoo_session_service.dart';
import '../../providers/session_provider.dart';
import '../../providers/sync_queue_provider.dart';

/// Single source of truth for POS order creation, online submission to Odoo 19,
/// crash-resilient SQLite offline queuing, and automated session re-binding.
abstract class OrderRepository {
  /// Submits an order. Persists immediately to local SQLite queue, then syncs if online.
  ///
  /// Returns the order with [OrderModel.isSynced] reflecting actual online sync status.
  Future<OrderModel> submitOrder(
    OrderModel order, {
    required bool isOnline,
    required bool isOfflineMode,
    bool reverseNetTax = false,
  });

  /// Replays pending/failed orders sequentially in FIFO order.
  Future<void> syncPendingOrders({bool reverseNetTax = false});

  /// Returns count of orders currently pending/syncing/failed in the local queue.
  Future<int> getPendingCount();

  /// Returns count of successfully synced orders.
  Future<int> getSyncedCount();

  /// Retrieves the sync status string ('pending', 'syncing', 'synced', 'failed') for an order.
  Future<String?> getOrderSyncStatus(String uuid);

  /// Retrieves an order from the local queue by UUID.
  Future<OrderModel?> getOrder(String uuid);

  /// Searches past orders. Queries Odoo 19 remote service when online, merges with local SQLite orders,
  /// and falls back gracefully to local SQLite orders if network connectivity fails.
  Future<List<OrderModel>> searchPastOrders(String query, {int limit = 50});

  /// Fetches order line items by IDs from Odoo 19 remote service.
  Future<List<OrderLineModel>> fetchOrderLines(List<int> lineIds);

  /// Builds and submits a return/refund order linked to [originalOrder] with specified [returnLines].
  Future<OrderModel> submitReturnOrder({
    required OrderModel originalOrder,
    required Map<OrderLineModel, double> returnLines,
    required int paymentMethodId,
    required int sessionId,
    bool isOnline = true,
    bool isOfflineMode = false,
    bool reverseNetTax = false,
  });
}

/// Concrete implementation of [OrderRepository].
class OrderRepositoryImpl implements OrderRepository {
  final OfflineQueueRepository queueRepo;
  final OdooOrderService orderService;
  final OdooSessionService sessionService;

  OrderRepositoryImpl({
    required this.queueRepo,
    required this.orderService,
    required this.sessionService,
  });

  @override
  Future<OrderModel> submitOrder(
    OrderModel order, {
    required bool isOnline,
    required bool isOfflineMode,
    bool reverseNetTax = false,
  }) async {
    // 1. Immediately enqueue order to OfflineQueueRepository as pending to guarantee zero data loss
    await queueRepo.enqueueOrder(order);

    // 2. If online and not in offline mode, attempt live synchronization
    if (isOnline && !isOfflineMode) {
      await queueRepo.markSyncing(order.uuid);

      try {
        await orderService.syncSingleOrder(order, reverseNetTax: reverseNetTax);
        await queueRepo.markSynced(order.uuid);
        return order.copyWith(isSynced: true);
      } catch (e) {
        final errorString = e.toString();

        // Check if error is due to closed or missing session
        final isSessionClosedError = errorString.toLowerCase().contains('closed') ||
            errorString.toLowerCase().contains('খোল') ||
            errorString.contains('MissingError');

        if (isSessionClosedError && order.configId != null) {
          // Automated Session Re-binding Protocol
          final reboundOrder = await _attemptSessionRebind(
            order,
            order.configId!,
            reverseNetTax: reverseNetTax,
          );
          if (reboundOrder != null) {
            // Rebind succeeded and order synced
            return reboundOrder.copyWith(isSynced: true);
          }
          await queueRepo.incrementRetry(order.uuid);
          return order.copyWith(isSynced: false);
        }

        // Standard failure handling
        await queueRepo.markFailed(order.uuid, errorString);
        await queueRepo.incrementRetry(order.uuid);
        return order.copyWith(isSynced: false);
      }
    }

    // Offline or offline-mode: stays pending in queue
    return order.copyWith(isSynced: false);
  }

  @override
  Future<void> syncPendingOrders({bool reverseNetTax = false}) async {
    final pendingOrders = await queueRepo.getPendingOrders();
    for (final order in pendingOrders) {
      await queueRepo.markSyncing(order.uuid);

      try {
        await orderService.syncSingleOrder(order, reverseNetTax: reverseNetTax);
        await queueRepo.markSynced(order.uuid);
      } catch (e) {
        final errorString = e.toString();

        final isSessionClosedError = errorString.toLowerCase().contains('closed') ||
            errorString.toLowerCase().contains('খোল') ||
            errorString.contains('MissingError');

        if (isSessionClosedError && order.configId != null) {
          final reboundOrder = await _attemptSessionRebind(
            order,
            order.configId!,
            reverseNetTax: reverseNetTax,
          );
          if (reboundOrder != null) {
            continue;
          }
          await queueRepo.incrementRetry(order.uuid);
          continue;
        }

        await queueRepo.markFailed(order.uuid, errorString);
        await queueRepo.incrementRetry(order.uuid);
      }
    }
  }

  @override
  Future<int> getPendingCount() async {
    return await queueRepo.getPendingCount();
  }

  @override
  Future<int> getSyncedCount() async {
    return await queueRepo.getSyncedCount();
  }

  @override
  Future<String?> getOrderSyncStatus(String uuid) async {
    final orderMap = await queueRepo.getOrder(uuid);
    return orderMap?['sync_status'] as String?;
  }

  @override
  Future<OrderModel?> getOrder(String uuid) async {
    final orderMap = await queueRepo.getOrder(uuid);
    if (orderMap == null) return null;
    return OrderModel.fromMap(orderMap);
  }

  @override
  Future<List<OrderModel>> searchPastOrders(String query, {int limit = 50}) async {
    final trimmed = query.trim().toLowerCase();
    List<OrderModel> remoteOrders = [];

    // Attempt remote lookup
    try {
      remoteOrders = await orderService.searchPastOrders(query, limit: limit);
    } catch (_) {
      // Graceful offline fallback on network/server exception
      remoteOrders = [];
    }

    // Also fetch local orders from SQLite to ensure offline / pending returns are visible
    final List<OrderModel> localOrders = [];
    try {
      final allLocalMaps = await queueRepo.getAllOrders();
      for (final map in allLocalMaps) {
        OrderModel? order;
        if (map['payload_json'] is String) {
          try {
            order = OrderModel.fromJson(
                jsonDecode(map['payload_json'] as String) as Map<String, dynamic>);
          } catch (_) {
            order = OrderModel.fromMap(map);
          }
        } else {
          order = OrderModel.fromMap(map);
        }

        if (trimmed.isEmpty) {
          localOrders.add(order);
        } else {
          final matchesRef = order.posReference.toLowerCase().contains(trimmed);
          final matchesName = (order.name ?? '').toLowerCase().contains(trimmed);
          final matchesTicket = order.ticketCode.toLowerCase().contains(trimmed);
          final matchesTracking = order.trackingNumber.toLowerCase().contains(trimmed);
          final matchesUuid = order.uuid.toLowerCase().contains(trimmed);
          if (matchesRef || matchesName || matchesTicket || matchesTracking || matchesUuid) {
            localOrders.add(order);
          }
        }
      }
    } catch (_) {}

    // Merge: Avoid duplicates by uuid, posReference, or id
    final Map<String, OrderModel> merged = {};

    // 1. Add local orders first (includes pending/syncing/failed offline orders)
    for (final order in localOrders) {
      final key = order.posReference.isNotEmpty
          ? order.posReference.toLowerCase()
          : order.uuid;
      merged[key] = order;
    }

    // 2. Add remote orders (overrides with authoritative backend state while preserving local rich lines)
    for (final remoteOrder in remoteOrders) {
      final key = remoteOrder.posReference.isNotEmpty
          ? remoteOrder.posReference.toLowerCase()
          : remoteOrder.uuid;
      final localOrder = merged[key];

      if (localOrder != null) {
        // Check if remoteOrder has stub lines (empty productName, zero qty) while localOrder has rich lines
        final remoteHasRichLines = remoteOrder.lines.isNotEmpty &&
            remoteOrder.lines.any((l) => l.productName.isNotEmpty || l.qty != 0);
        final localHasRichLines = localOrder.lines.isNotEmpty &&
            localOrder.lines.any((l) => l.productName.isNotEmpty || l.qty != 0);

        List<OrderLineModel> effectiveLines = remoteOrder.lines;

        if (!remoteHasRichLines && localHasRichLines) {
          // Preserve local rich lines. If remote lines provided backend line IDs, map them.
          if (remoteOrder.lines.length == localOrder.lines.length) {
            effectiveLines = [
              for (int i = 0; i < localOrder.lines.length; i++)
                if (localOrder.lines[i].id == null && remoteOrder.lines[i].id != null)
                  localOrder.lines[i].copyWith(id: remoteOrder.lines[i].id)
                else
                  localOrder.lines[i]
            ];
          } else {
            effectiveLines = localOrder.lines;
          }
        }

        merged[key] = remoteOrder.copyWith(
          uuid: localOrder.uuid, // preserve local UUID for consistent queue lookup
          lines: effectiveLines,
          payments: remoteOrder.payments.isNotEmpty ? remoteOrder.payments : localOrder.payments,
        );
      } else {
        merged[key] = remoteOrder;
      }
    }

    final result = merged.values.toList();
    // Sort by dateOrder / createdAt descending
    result.sort((a, b) {
      final dateA = a.dateOrder ?? a.createdAt;
      final dateB = b.dateOrder ?? b.createdAt;
      return dateB.compareTo(dateA);
    });

    if (limit > 0 && result.length > limit) {
      return result.sublist(0, limit);
    }
    return result;
  }

  @override
  Future<List<OrderLineModel>> fetchOrderLines(List<int> lineIds) async {
    if (lineIds.isEmpty) return [];
    try {
      return await orderService.fetchOrderLines(lineIds);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<OrderModel> submitReturnOrder({
    required OrderModel originalOrder,
    required Map<OrderLineModel, double> returnLines,
    required int paymentMethodId,
    required int sessionId,
    bool isOnline = true,
    bool isOfflineMode = false,
    bool reverseNetTax = false,
  }) async {
    // 1. Domain Validation: Non-negative quantities
    for (final entry in returnLines.entries) {
      if (entry.value < 0) {
        throw ArgumentError(
          'Return quantity cannot be negative: ${entry.value} for "${entry.key.productName}".',
        );
      }
    }

    // 2. Domain Validation: At least one positive return item
    final validEntries = returnLines.entries.where((e) => e.value > 0).toList();
    if (validEntries.isEmpty) {
      throw ArgumentError(
        'Cannot submit return order with no valid return items (all quantities <= 0 or empty).',
      );
    }

    // 3. Domain Validation: Preconditions on each return line
    for (final entry in validEntries) {
      final origLine = entry.key;
      final qtyToReturn = entry.value;

      if (origLine.qty <= 0) {
        throw ArgumentError(
          'Cannot return line "${origLine.productName}" with non-positive original quantity (${origLine.qty}).',
        );
      }

      if (qtyToReturn > origLine.refundableQty + 0.0001) {
        throw ArgumentError(
          'Requested return quantity ($qtyToReturn) exceeds refundable quantity '
          '(${origLine.refundableQty}) for "${origLine.productName}".',
        );
      }
    }

    final now = DateTime.now();
    final List<OrderLineModel> returnLinesList = [];
    double totalRefundGross = 0.0;
    double totalRefundTax = 0.0;

    for (final entry in validEntries) {
      final origLine = entry.key;
      final qtyToReturn = entry.value;

      // Calculate unit prices and subtotals based on original line proportions
      final double unitGross = origLine.qty != 0
          ? (origLine.priceSubtotalIncl / origLine.qty)
          : origLine.priceUnit;
      final double unitNet = origLine.qty != 0
          ? (origLine.priceSubtotal / origLine.qty)
          : origLine.priceUnit;

      final double lineRefundGross = double.parse((unitGross * qtyToReturn).toStringAsFixed(2));
      final double lineRefundNet = double.parse((unitNet * qtyToReturn).toStringAsFixed(2));

      totalRefundGross += lineRefundGross;
      totalRefundTax += (lineRefundGross - lineRefundNet);

      returnLinesList.add(OrderLineModel(
        id: null,
        uuid: const Uuid().v4(),
        productId: origLine.productId,
        productName: origLine.productName,
        qty: -qtyToReturn, // Negative quantity
        priceUnit: origLine.priceUnit,
        discount: origLine.discount,
        priceSubtotal: -lineRefundNet, // Negative subtotal
        priceSubtotalIncl: -lineRefundGross, // Negative subtotal incl
        taxIds: origLine.taxIds,
        customerNote: origLine.customerNote,
        refundedOrderlineId: origLine.id, // Links to original line ID
        refundedQty: 0.0,
      ));
    }

    totalRefundGross = double.parse(totalRefundGross.toStringAsFixed(2));
    totalRefundTax = double.parse(totalRefundTax.toStringAsFixed(2));

    final double negativeTotal = -totalRefundGross;
    final double negativeTax = -totalRefundTax;

    final paymentLine = PaymentLineModel(
      uuid: const Uuid().v4(),
      paymentMethodId: paymentMethodId,
      amount: negativeTotal, // Negative payment tender
      isChange: false,
      sessionId: sessionId,
      paymentDate: now,
    );

    final returnOrder = OrderModel(
      uuid: const Uuid().v4(),
      posReference: 'RETURN-${originalOrder.posReference}-${const Uuid().v4().substring(0, 5)}',
      ticketCode: const Uuid().v4().substring(0, 5).toLowerCase(),
      trackingNumber: (5000 + (now.millisecondsSinceEpoch % 1000)).toString(),
      sessionId: sessionId,
      configId: originalOrder.configId,
      companyId: originalOrder.companyId,
      userId: originalOrder.userId,
      partnerId: originalOrder.partnerId,
      amountTotal: negativeTotal,
      amountPaid: negativeTotal,
      amountReturn: 0.0,
      amountTax: negativeTax,
      lines: returnLinesList,
      payments: [paymentLine],
      createdAt: now,
      dateOrder: now,
      state: 'paid',
      toInvoice: false,
      name: '${originalOrder.name ?? originalOrder.posReference} ফেরত',
      sequenceNumber: originalOrder.sequenceNumber,
      accessToken: const Uuid().v4(),
      isSynced: false,
      isRefund: true,
      refundedOrderId: originalOrder.id,
      hasRefundableLines: false,
    );

    return await submitOrder(
      returnOrder,
      isOnline: isOnline,
      isOfflineMode: isOfflineMode,
      reverseNetTax: reverseNetTax,
    );
  }

  /// Attempts to re-bind an order to the current active session of the register.
  Future<OrderModel?> _attemptSessionRebind(
    OrderModel order,
    int configId, {
    bool reverseNetTax = false,
  }) async {
    try {
      final configs = await sessionService.searchConfigs(
        domain: [
          ['id', '=', configId]
        ],
      );

      if (configs.isNotEmpty) {
        final config = configs.first;
        if (config.hasActiveSession && config.currentSessionId != null) {
          final newSessionId = config.currentSessionId!;
          final remappedOrder = order.copyWithSession(newSessionId);

          // Update local DB
          await queueRepo.updateOrderSession(
            order.uuid,
            newSessionId,
            jsonEncode(remappedOrder.toJson()),
          );

          // Resubmit with new session
          await orderService.syncSingleOrder(
            remappedOrder,
            reverseNetTax: reverseNetTax,
          );
          await queueRepo.markSynced(order.uuid);
          return remappedOrder;
        }
      }

      await queueRepo.markFailed(
        order.uuid,
        'Session closed; waiting for register opening',
      );
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Global provider for [OrderRepository].
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final queueRepo = ref.watch(offlineQueueRepositoryProvider);
  final orderService = ref.watch(orderServiceProvider);
  final sessionService = ref.watch(sessionServiceProvider);
  return OrderRepositoryImpl(
    queueRepo: queueRepo,
    orderService: orderService,
    sessionService: sessionService,
  );
});
