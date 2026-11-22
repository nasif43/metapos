import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_queue_provider.dart';

/// Abstract service interface for network connectivity monitoring.
abstract class NetworkConnectivityService {
  Future<bool> isConnected();
  Stream<bool> get onConnectivityChanged;
}

/// Default implementation using package:connectivity_plus.
class RealNetworkConnectivityService implements NetworkConnectivityService {
  final Connectivity _connectivity;

  RealNetworkConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Optimistic fallback if platform channel fails
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }
}

/// Provider for the connectivity service (can be overridden in tests).
final connectivityServiceProvider =
    Provider<NetworkConnectivityService>((ref) {
  return RealNetworkConnectivityService();
});

/// State notifier managing connectivity state and triggering auto-sync upon reconnection.
class ConnectivityNotifier extends StateNotifier<bool> {
  final NetworkConnectivityService service;
  final Ref ref;
  StreamSubscription<bool>? _subscription;

  ConnectivityNotifier({
    required this.service,
    required this.ref,
    bool initialOnline = true,
  }) : super(initialOnline) {
    _subscription = service.onConnectivityChanged.listen((isOnline) {
      final wasOffline = !state;
      if (mounted) {
        state = isOnline;
      }

      // When transitioning from offline to online, auto-sync pending orders
      if (wasOffline && isOnline) {
        ref.read(syncQueueProvider.notifier).syncPendingOrders();
      }
    });
    _init();
  }

  Future<void> _init() async {
    try {
      final initial = await service.isConnected();
      if (mounted) {
        state = initial;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Global provider for connectivity status (true = online, false = offline).
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return ConnectivityNotifier(service: service, ref: ref);
});

/// Convenience provider for reading whether the app is online.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider);
});
