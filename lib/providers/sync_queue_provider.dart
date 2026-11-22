import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/offline_queue_repository.dart';
import '../data/models/order_model.dart';
import '../data/remote/odoo_order_service.dart';
import '../data/remote/odoo_session_service.dart';
import 'auth_provider.dart';
import 'catalog_provider.dart';
import 'session_provider.dart';

/// State representation for offline order queue and background synchronization.
class SyncQueueState {
  final int pendingCount;
  final int syncedCount;
  final bool isSyncing;
  final String? lastError;

  const SyncQueueState({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.isSyncing = false,
    this.lastError,
  });

  SyncQueueState copyWith({
    int? pendingCount,
    int? syncedCount,
    bool? isSyncing,
    String? lastError,
  }) {
    return SyncQueueState(
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: lastError,
    );
  }
}

/// Provider for offline queue repository.
final offlineQueueRepositoryProvider = Provider<OfflineQueueRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return OfflineQueueRepository(dbHelper: dbHelper);
});

/// Provider for Odoo order sync remote service.
final orderServiceProvider = Provider<OdooOrderService>((ref) {
  final client = ref.watch(jsonRpcClientProvider);
  return OdooOrderService(client: client);
});

/// State notifier managing order submission, offline queuing, FIFO replay, and session re-binding.
class SyncQueueNotifier extends StateNotifier<SyncQueueState> {
  final OfflineQueueRepository queueRepo;
  final OdooOrderService orderService;
  final OdooSessionService sessionService;

  SyncQueueNotifier({
    required this.queueRepo,
    required this.orderService,
    required this.sessionService,
  }) : super(const SyncQueueState()) {
    refreshCounts();
  }

  /// Refreshes pending and synced order counters from SQLite.
  Future<void> refreshCounts() async {
    try {
      final pending = await queueRepo.getPendingCount();
      final synced = await queueRepo.getSyncedCount();
      if (!mounted) return;
      state = state.copyWith(
        pendingCount: pending,
        syncedCount: synced,
      );
    } catch (_) {
      // Guard against SQLite database closed during test teardowns or unmounts
    }
  }

  /// Submits an order. Persists to local queue first, then syncs if online.
  Future<bool> submitOrder(
    OrderModel order, {
    bool isOnline = true,
    bool reverseNetTax = false,
  }) async {
    // 1. Immediately persist to SQLite offline queue (status: pending)
    await queueRepo.enqueueOrder(order);
    await refreshCounts();

    if (!isOnline) {
      return true; // Queued safely offline
    }

    // 2. Trigger FIFO sync loop
    await syncPendingOrders(reverseNetTax: reverseNetTax);
    return true;
  }

  /// Replays pending orders sequentially in FIFO order (`created_at ASC`).
  ///
  /// Implements automated session re-binding if the original session closed.
  Future<void> syncPendingOrders({bool reverseNetTax = false}) async {
    if (!mounted || state.isSyncing) return;
    state = state.copyWith(isSyncing: true, lastError: null);

    final pendingOrders = await queueRepo.getPendingOrders();
    for (final order in pendingOrders) {
      await queueRepo.markSyncing(order.uuid);

      try {
        await orderService.syncSingleOrder(order, reverseNetTax: reverseNetTax);
        await queueRepo.markSynced(order.uuid);
      } catch (e) {
        final errorString = e.toString();

        // Check if error is due to closed or missing session
        final isSessionClosedError = errorString.toLowerCase().contains('closed') ||
            errorString.toLowerCase().contains('খোল') ||
            errorString.contains('MissingError');

        if (isSessionClosedError && order.configId != null) {
          // Automated Session Re-binding Protocol
          final rebindSuccess = await _attemptSessionRebind(
            order,
            order.configId!,
            reverseNetTax: reverseNetTax,
          );
          if (rebindSuccess) {
            continue;
          }
        }

        // Standard failure handling
        await queueRepo.markFailed(order.uuid, errorString);
        await queueRepo.incrementRetry(order.uuid);
        if (mounted) {
          state = state.copyWith(lastError: errorString);
        }
      }
    }

    if (mounted) {
      state = state.copyWith(isSyncing: false);
      await refreshCounts();
    }
  }

  /// Attempts to re-bind an order to the current active session of the register.
  Future<bool> _attemptSessionRebind(
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
          return true;
        }
      }

      await queueRepo.markFailed(
        order.uuid,
        'Session closed; waiting for register opening',
      );
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Global provider for SyncQueue state and actions.
final syncQueueProvider =
    StateNotifierProvider<SyncQueueNotifier, SyncQueueState>((ref) {
  final queueRepo = ref.watch(offlineQueueRepositoryProvider);
  final orderService = ref.watch(orderServiceProvider);
  final sessionService = ref.watch(sessionServiceProvider);
  return SyncQueueNotifier(
    queueRepo: queueRepo,
    orderService: orderService,
    sessionService: sessionService,
  );
});

/// Watches the sync status ('synced', 'pending', 'syncing', 'failed') of a specific order.
final orderSyncStatusProvider =
    FutureProvider.family<String?, String>((ref, uuid) async {
  ref.watch(syncQueueProvider);
  final queueRepo = ref.watch(offlineQueueRepositoryProvider);
  final orderMap = await queueRepo.getOrder(uuid);
  return orderMap?['sync_status'] as String?;
});
