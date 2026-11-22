import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order_model.dart';
import '../data/repositories/order_repository.dart';

/// Filter categories for past orders lookup in MetaPOS.
enum PastOrdersFilter {
  all,
  refundable,
  refunds,
  pending,
}

/// Immutable state representation for the past orders list and lookup.
@immutable
class PastOrdersState {
  final List<OrderModel> orders;
  final List<OrderModel> filteredOrders;
  final PastOrdersFilter filter;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const PastOrdersState({
    this.orders = const [],
    this.filteredOrders = const [],
    this.filter = PastOrdersFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  PastOrdersState copyWith({
    List<OrderModel>? orders,
    List<OrderModel>? filteredOrders,
    PastOrdersFilter? filter,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PastOrdersState(
      orders: orders ?? this.orders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PastOrdersState &&
        listEquals(other.orders, orders) &&
        listEquals(other.filteredOrders, filteredOrders) &&
        other.filter == filter &&
        other.searchQuery == searchQuery &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(orders),
        Object.hashAll(filteredOrders),
        filter,
        searchQuery,
        isLoading,
        error,
      );
}

/// State notifier managing past orders querying, status filtering, and barcode lookups.
class PastOrdersNotifier extends StateNotifier<PastOrdersState> {
  final OrderRepository orderRepository;

  PastOrdersNotifier({
    required this.orderRepository,
  }) : super(const PastOrdersState());

  /// Evaluates and applies [filter] to [orders] using Dart 3 pattern matching and switch expressions.
  static List<OrderModel> applyFilter(
    List<OrderModel> orders,
    PastOrdersFilter filter,
  ) {
    return switch (filter) {
      PastOrdersFilter.all => orders,
      PastOrdersFilter.refundable => orders.where((order) {
          // Cannot refund an order that is already a return
          if (order.isRefund) return false;
          // Must have refundable lines flag or any order line with remaining refundable quantity
          return order.hasRefundableLines ||
              order.lines.any((l) => l.refundableQty > 0);
        }).toList(),
      PastOrdersFilter.refunds => orders.where((order) => order.isRefund).toList(),
      PastOrdersFilter.pending => orders.where((order) {
          return !order.isSynced ||
              order.state == 'pending' ||
              order.state == 'draft';
        }).toList(),
    };
  }

  /// Initial load of recent orders.
  Future<void> loadOrders() async {
    await search(state.searchQuery);
  }

  /// Searches past orders using [query]. Queries remote Odoo or local SQLite queue.
  Future<void> search(String query) async {
    // Dart 3 record destructuring
    final (trimmedQuery, activeFilter) = (query.trim(), state.filter);
    state = state.copyWith(
      isLoading: true,
      searchQuery: trimmedQuery,
      clearError: true,
    );

    try {
      final results = await orderRepository.searchPastOrders(trimmedQuery);
      final filtered = applyFilter(results, activeFilter);

      state = state.copyWith(
        orders: results,
        filteredOrders: filtered,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Updates active [PastOrdersFilter] and re-filters cached orders.
  void setFilter(PastOrdersFilter filter) {
    if (state.filter == filter) return;
    final filtered = applyFilter(state.orders, filter);
    state = state.copyWith(
      filter: filter,
      filteredOrders: filtered,
    );
  }

  /// Scans or searches by receipt barcode or ticket code.
  Future<void> scanBarcode(String code) async {
    await search(code);
  }

  /// Pull-to-refresh: re-executes search using the active query.
  Future<void> refresh() async {
    await search(state.searchQuery);
  }
}

/// Global Riverpod provider for past orders state and search/filter operations.
final pastOrdersProvider =
    StateNotifierProvider<PastOrdersNotifier, PastOrdersState>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);
  return PastOrdersNotifier(orderRepository: orderRepository);
});
