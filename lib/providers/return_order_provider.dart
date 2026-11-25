import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/user_error_message.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repository.dart';
import 'order_provider.dart';
import 'dashboard_provider.dart';
import 'past_orders_provider.dart';
import 'session_provider.dart';

/// Immutable state representation for the return order process and cart.
@immutable
class ReturnOrderState {
  final OrderModel? originalOrder;
  final Map<int, double> selectedQuantities; // order line ID -> return quantity
  final int? paymentMethodId;
  final bool isSubmitting;
  final String? error;
  final OrderModel? completedRefundOrder;

  const ReturnOrderState({
    this.originalOrder,
    this.selectedQuantities = const {},
    this.paymentMethodId,
    this.isSubmitting = false,
    this.error,
    this.completedRefundOrder,
  });

  /// Whole BDT integer calculation without decimal slop matching currency formatting rules.
  double get totalRefund {
    final order = originalOrder;
    if (order == null) return 0.0;

    double total = 0.0;
    for (final MapEntry(key: lineId, value: qty) in selectedQuantities.entries) {
      if (qty <= 0) continue;
      final line = order.lines.cast<OrderLineModel?>().firstWhere(
            (l) => l?.id == lineId,
            orElse: () => null,
          );
      if (line != null) {
        final unitPrice = line.qty != 0
            ? (line.priceSubtotalIncl / line.qty).abs()
            : line.priceUnit;
        total += unitPrice * qty;
      }
    }
    return total.roundToDouble();
  }

  /// Number of lines in [originalOrder] with available [refundableQty > 0].
  int get refundableLineCount {
    final order = originalOrder;
    if (order == null) return 0;
    return order.lines.where((l) => l.refundableQty > 0).length;
  }

  /// Boolean indicating if any line in the selection has quantity > 0.
  bool get hasSelectedLines =>
      selectedQuantities.values.any((qty) => qty > 0);

  /// Total sum of selected return quantities across all line items.
  double get totalItemsToReturn {
    return selectedQuantities.values
        .where((qty) => qty > 0)
        .fold(0.0, (sum, qty) => sum + qty);
  }

  ReturnOrderState copyWith({
    OrderModel? originalOrder,
    Map<int, double>? selectedQuantities,
    int? paymentMethodId,
    bool? isSubmitting,
    String? error,
    OrderModel? completedRefundOrder,
    bool clearOriginalOrder = false,
    bool clearPaymentMethodId = false,
    bool clearError = false,
    bool clearCompletedRefundOrder = false,
  }) {
    return ReturnOrderState(
      originalOrder: clearOriginalOrder
          ? null
          : (originalOrder ?? this.originalOrder),
      selectedQuantities: selectedQuantities ?? this.selectedQuantities,
      paymentMethodId: clearPaymentMethodId
          ? null
          : (paymentMethodId ?? this.paymentMethodId),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      completedRefundOrder: clearCompletedRefundOrder
          ? null
          : (completedRefundOrder ?? this.completedRefundOrder),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReturnOrderState &&
        other.originalOrder == originalOrder &&
        mapEquals(other.selectedQuantities, selectedQuantities) &&
        other.paymentMethodId == paymentMethodId &&
        other.isSubmitting == isSubmitting &&
        other.error == error &&
        other.completedRefundOrder == completedRefundOrder;
  }

  @override
  int get hashCode => Object.hash(
        originalOrder,
        Object.hash(
          Object.hashAll(selectedQuantities.keys),
          Object.hashAll(selectedQuantities.values),
        ),
        paymentMethodId,
        isSubmitting,
        error,
        completedRefundOrder,
      );
}

/// State notifier managing return order session, item quantities, tender selection,
/// over-refund prevention, and return order submission.
class ReturnOrderNotifier extends StateNotifier<ReturnOrderState> {
  final OrderRepository orderRepository;
  final Ref ref;

  ReturnOrderNotifier({
    required this.orderRepository,
    required this.ref,
  }) : super(const ReturnOrderState());

  /// Initializes return session for a single parent order; clears prior selections and errors.
  /// Enforces single parent order constraint.
  void initForOrder(OrderModel order) {
    if (order.isRefund) {
      throw ArgumentError('Cannot initiate a return for an order that is already a refund.');
    }
    state = ReturnOrderState(
      originalOrder: order,
      selectedQuantities: const {},
      paymentMethodId: null,
      isSubmitting: false,
      error: null,
      completedRefundOrder: null,
    );
  }

  /// Strictly bounds [0.0 <= qty <= line.refundableQty].
  /// Enforces over-refund prevention: if (qty > line.refundableQty) qty = line.refundableQty;
  /// and if (qty <= 0) remove/set 0.
  void setQuantity(int lineId, double qty) {
    final original = state.originalOrder;
    if (original == null) return;

    final line = original.lines.cast<OrderLineModel?>().firstWhere(
          (l) => l?.id == lineId,
          orElse: () => null,
        );
    if (line == null) return;

    final maxRefundable = line.refundableQty;
    final clampedQty = qty > maxRefundable
        ? maxRefundable
        : (qty < 0 ? 0.0 : qty);

    final newQuantities = Map<int, double>.from(state.selectedQuantities);
    if (clampedQty <= 0) {
      newQuantities.remove(lineId);
    } else {
      newQuantities[lineId] = clampedQty;
    }

    state = state.copyWith(
      selectedQuantities: newQuantities,
      clearError: true,
    );
  }

  /// Increments selected quantity for [lineId] by [step] (defaults to 1.0),
  /// strictly bounded by [line.refundableQty].
  void incrementQuantity(int lineId, {double step = 1.0}) {
    final currentQty = state.selectedQuantities[lineId] ?? 0.0;
    setQuantity(lineId, currentQty + step);
  }

  /// Decrements selected quantity for [lineId] by [step] (defaults to 1.0),
  /// removing line if quantity reaches <= 0.
  void decrementQuantity(int lineId, {double step = 1.0}) {
    final currentQty = state.selectedQuantities[lineId] ?? 0.0;
    setQuantity(lineId, currentQty - step);
  }

  /// Sets all lines with [refundableQty > 0] to their maximum available refundable quantity.
  void returnAll() {
    final original = state.originalOrder;
    if (original == null) return;

    final newQuantities = <int, double>{};
    for (final line in original.lines) {
      if (line.id != null && line.refundableQty > 0) {
        newQuantities[line.id!] = line.refundableQty;
      }
    }

    state = state.copyWith(
      selectedQuantities: newQuantities,
      clearError: true,
    );
  }

  /// Resets selected quantities map to empty.
  void clearSelection() {
    state = state.copyWith(
      selectedQuantities: const {},
      clearError: true,
    );
  }

  /// Selects the refund tender payment method ID.
  void setPaymentMethod(int methodId) {
    state = state.copyWith(
      paymentMethodId: methodId,
      clearError: true,
    );
  }

  /// Resets state back to initial empty state.
  void reset() {
    state = const ReturnOrderState();
  }

  /// Submits return order enforcing all required invariants:
  /// 0. Re-entrancy guard: returns null immediately if already submitting.
  /// 1. Non-empty selection (hasSelectedLines == true).
  /// 2. Single parent order constraint (originalOrder != null).
  /// 3. Valid payment method selected (paymentMethodId != null).
  /// 4. Binds to currently active POS session ID (sessionProvider).
  /// 5. Submits via OrderRepository.submitReturnOrder(...).
  /// 6. On success: updates lastCompletedOrderProvider (for receipt printing) and sets completedRefundOrder.
  /// 7. On error: catches exception, sets isSubmitting: false, error: exception.toString().
  Future<OrderModel?> submitReturn({
    bool? isOnline,
    bool? isOfflineMode,
    bool? reverseNetTax,
  }) async {
    if (state.isSubmitting) {
      return null;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      // 1. Single parent order constraint
      final originalOrder = state.originalOrder;
      if (originalOrder == null) {
        throw StateError('Cannot submit return: No original order selected.');
      }

      // 2. Non-empty selection invariant
      if (!state.hasSelectedLines) {
        throw StateError('Cannot submit return: No items selected for return.');
      }

      // 3. Valid payment method selected invariant
      final paymentMethodId = state.paymentMethodId;
      if (paymentMethodId == null) {
        throw StateError(
          'Cannot submit return: No payment method selected for refund payout.',
        );
      }

      // 4. Binds to currently active POS session ID (sessionProvider)
      final sessionState = ref.read(sessionProvider);
      final activeSessionId = sessionState.activeSession?.id;
      if (activeSessionId == null) {
        throw StateError(
          'Cannot submit return: No active POS session found.',
        );
      }

      // Map selected quantities to Map<OrderLineModel, double>
      final Map<OrderLineModel, double> returnLines = {};
      for (final MapEntry(key: lineId, value: qty) in state.selectedQuantities.entries) {
        if (qty <= 0) continue;
        final line = originalOrder.lines.cast<OrderLineModel?>().firstWhere(
              (l) => l?.id == lineId,
              orElse: () => null,
            );
        if (line == null) {
          throw StateError(
            'Cannot submit return: Line ID $lineId does not belong to original order.',
          );
        }
        returnLines[line] = qty;
      }

      if (returnLines.isEmpty) {
        throw StateError('Cannot submit return: No valid items selected for return.');
      }

      // 5. Submits via OrderRepository.submitReturnOrder(...)
      final refundOrder = await orderRepository.submitReturnOrder(
        originalOrder: originalOrder,
        returnLines: returnLines,
        paymentMethodId: paymentMethodId,
        sessionId: activeSessionId,
        isOnline: isOnline ?? true,
        isOfflineMode: isOfflineMode ?? false,
        reverseNetTax: reverseNetTax ?? false,
      );

      // 6. On success: updates lastCompletedOrderProvider and sets completedRefundOrder
      ref.read(lastCompletedOrderProvider.notifier).state = refundOrder;
      ref.read(dashboardProvider.notifier).fetchDashboard(forceRefresh: true);
      ref.read(pastOrdersProvider.notifier).loadOrders();

      state = state.copyWith(
        isSubmitting: false,
        completedRefundOrder: refundOrder,
        clearError: true,
      );

      return refundOrder;
    } catch (e) {
      // 7. On error: catches exception, sets isSubmitting: false, error: exception.toString()
      state = state.copyWith(
        isSubmitting: false,
        error: UserErrorMessage.format(e),
      );
      return null;
    }
  }
}

/// Global Riverpod provider for ReturnOrder state and actions.
final returnOrderProvider =
    StateNotifierProvider<ReturnOrderNotifier, ReturnOrderState>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);
  return ReturnOrderNotifier(
    orderRepository: orderRepository,
    ref: ref,
  );
});
