import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order_model.dart';

/// State representation for checkout multi-tender payments and change calculation.
class PaymentState {
  final double amountTotal;
  final double amountTendered;
  final double changeDue;
  final List<PaymentLineModel> paymentLines;
  final int selectedPaymentMethodId;
  final bool isCompleted;

  const PaymentState({
    this.amountTotal = 0.0,
    this.amountTendered = 0.0,
    this.changeDue = 0.0,
    this.paymentLines = const [],
    this.selectedPaymentMethodId = 1, // Default 1 = Cash
    this.isCompleted = false,
  });

  double get remainingDue {
    final diff = amountTotal - amountTendered;
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  PaymentState copyWith({
    double? amountTotal,
    double? amountTendered,
    double? changeDue,
    List<PaymentLineModel>? paymentLines,
    int? selectedPaymentMethodId,
    bool? isCompleted,
  }) {
    return PaymentState(
      amountTotal: amountTotal ?? this.amountTotal,
      amountTendered: amountTendered ?? this.amountTendered,
      changeDue: changeDue ?? this.changeDue,
      paymentLines: paymentLines ?? this.paymentLines,
      selectedPaymentMethodId:
          selectedPaymentMethodId ?? this.selectedPaymentMethodId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// State notifier managing checkout tender payments and change calculation.
class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier() : super(const PaymentState());

  /// Sets total amount due from cart grand total.
  void setTotal(double total) {
    state = state.copyWith(amountTotal: total);
    _recalculate(state.paymentLines, total);
  }

  /// Sets selected payment method (1=Cash, 2=Card, etc.).
  void selectMethod(int methodId) {
    state = state.copyWith(selectedPaymentMethodId: methodId);
  }

  /// Adds a tender payment line.
  ///
  /// CRITICAL SPEC RULE:
  /// Over-tender is strictly allowed on Cash (ID 1). For digital payments (Card/bKash),
  /// tender is capped at remaining balance due.
  void addPayment(
    int methodId,
    double amount, {
    String? name,
    String? refNo,
    int? sessionId,
    String? methodName,
  }) {
    if (amount <= 0) return;

    double effectiveAmount = amount;
    final remaining = state.remainingDue;

    // Tender restrictions: digital methods cannot over-tender
    if (methodId != 1 && effectiveAmount > remaining) {
      effectiveAmount = remaining;
    }

    if (effectiveAmount <= 0) return;

    final line = PaymentLineModel.create(
      paymentMethodId: methodId,
      paymentMethodName: methodName ?? (methodId == 1 ? 'Cash' : 'Card'),
      amount: effectiveAmount,
      name: name,
      sessionId: sessionId,
      paymentRefNo: refNo,
    );

    final updatedLines = [...state.paymentLines, line];
    _recalculate(updatedLines, state.amountTotal);
  }

  /// Removes a payment line by UUID.
  void removePaymentLine(String uuid) {
    final updatedLines =
        state.paymentLines.where((l) => l.uuid != uuid).toList();
    _recalculate(updatedLines, state.amountTotal);
  }

  /// Clears all entered payments.
  void clearPayments() {
    state = PaymentState(
      amountTotal: state.amountTotal,
      selectedPaymentMethodId: state.selectedPaymentMethodId,
    );
  }

  /// Recalculates total tendered and change due.
  void _recalculate(List<PaymentLineModel> lines, double totalDue) {
    double tendered = 0.0;
    for (final l in lines) {
      if (!l.isChange) {
        tendered += l.amount;
      }
    }
    tendered = double.parse(tendered.toStringAsFixed(2));

    final change = tendered > totalDue
        ? double.parse((tendered - totalDue).toStringAsFixed(2))
        : 0.0;

    final bool completed = tendered >= totalDue && totalDue > 0;

    state = state.copyWith(
      amountTotal: totalDue,
      amountTendered: tendered,
      changeDue: change,
      paymentLines: lines,
      isCompleted: completed,
    );
  }
}

/// Global provider for Payment state and actions.
final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier();
});
