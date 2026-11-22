// test/e2e/e2e_test_harness.dart
//
// MetaPOS E2E Test Harness
// Comprehensive opaque-box testing harness simulating Odoo 19 POS backend,
// in-memory SQLite storage, Riverpod state management, and multi-viewport Flutter UI.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:metapos/core/theme/app_colors.dart';
import 'package:metapos/core/theme/app_theme.dart';
import 'package:metapos/core/theme/app_typography.dart';
import 'package:metapos/core/utils/currency_formatter.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';

import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/data/repositories/order_repository.dart';
import 'package:metapos/presentation/screens/receipt/order_success_receipt_screen.dart';
import 'package:metapos/providers/catalog_provider.dart';
import 'package:metapos/providers/connectivity_provider.dart';
import 'package:metapos/providers/order_provider.dart';
import 'package:metapos/providers/printer_provider.dart';
import 'package:metapos/providers/session_provider.dart';
import 'package:metapos/providers/sync_queue_provider.dart';

// ============================================================================
// 1. In-Memory Mock Odoo 19 Backend Server
// ============================================================================
class E2EMockOdooServer {
  final Map<int, Map<String, dynamic>> orders = {};
  final Map<int, Map<String, dynamic>> orderLines = {};
  final Map<int, Map<String, dynamic>> sessions = {};
  final Map<int, Map<String, dynamic>> configs = {};
  final List<Map<String, dynamic>> receivedPayloads = [];

  bool isOnline = true;
  bool shouldThrowNetworkError = false;
  String networkErrorMessage = 'SocketException: Connection timed out';

  int _nextOrderId = 1000;
  int _nextLineId = 5000;

  E2EMockOdooServer() {
    _initDefaults();
  }

  void _initDefaults() {
    configs[1] = {
      'id': 1,
      'name': 'Book Fair Stall #1',
      'current_session_id': [23, 'Book Fair/00023'],
      'current_session_state': 'opened',
      'payment_method_ids': [1, 2, 3], // 1=Cash, 2=Card, 3=bKash
    };
    sessions[23] = {
      'id': 23,
      'name': 'Book Fair/00023',
      'state': 'opened',
      'config_id': [1, 'Book Fair Stall #1'],
    };
  }

  /// Seeds an original POS order into mock Odoo server with lines and tender.
  OrderModel seedOriginalOrder({
    required int orderId,
    required String posReference,
    required String ticketCode,
    required String barcode,
    required int sessionId,
    required List<OrderLineModel> lines,
    required List<PaymentLineModel> payments,
    int? partnerId,
    String? partnerName,
    String? partnerPhone,
    DateTime? createdAt,
  }) {
    final orderLinesData = <Map<String, dynamic>>[];
    final seededLines = <OrderLineModel>[];
    final date = createdAt ?? DateTime.now();

    for (final l in lines) {
      final lineId = l.id ?? _nextLineId++;
      final lineDict = {
        'id': lineId,
        'order_id': [orderId, posReference],
        'product_id': [l.productId, l.productName],
        'full_product_name': l.productName,
        'qty': l.qty,
        'price_unit': l.priceUnit,
        'discount': l.discount,
        'price_subtotal': l.priceSubtotal,
        'price_subtotal_incl': l.priceSubtotalIncl,
        'tax_ids': [
          [6, 0, l.taxIds]
        ],
        'refunded_qty': l.refundedQty,
        'refunded_orderline_id': l.refundedOrderlineId ?? false,
      };
      orderLines[lineId] = lineDict;
      orderLinesData.add(lineDict);
      seededLines.add(l.copyWith(id: lineId));
    }

    final order = OrderModel.create(
      id: orderId,
      sessionId: sessionId,
      posReference: posReference,
      ticketCode: ticketCode,
      lines: seededLines,
      payments: payments,
      partnerId: partnerId,
      hasRefundableLines: seededLines.any((l) => l.refundableQty > 0),
      isSynced: true,
      createdAt: date,
    );

    orders[orderId] = {
      'id': orderId,
      'name': posReference,
      'pos_reference': posReference,
      'ticket_code': ticketCode,
      'tracking_number': barcode,
      'session_id': [sessionId, 'Session #$sessionId'],
      'partner_id': partnerId != null
          ? [partnerId, partnerName ?? 'Customer', partnerPhone ?? '']
          : false,
      'amount_total': order.amountTotal,
      'amount_paid': order.amountPaid,
      'amount_return': 0.0,
      'amount_tax': order.amountTax,
      'lines': orderLinesData.map((ld) => ld['id']).toList(),
      'is_refund': false,
      'refunded_order_id': false,
      'has_refundable_lines': order.hasRefundableLines,
      'date_order': date.toIso8601String(),
      'state': 'paid',
    };

    return order;
  }

  /// Handles JSON-RPC dispatch simulating Odoo 19 endpoints.
  Future<dynamic> handleRpc(String endpoint, Map<String, dynamic> params) async {
    if (!isOnline || shouldThrowNetworkError) {
      throw OdooServerException(message: networkErrorMessage);
    }

    if (endpoint == '/web/dataset/call_kw/pos.order/search_read') {
      final domain = params['args'][0] as List<dynamic>;
      final filtered = orders.values.where((o) => _matchesDomain(o, domain)).toList();
      return filtered;
    }

    if (endpoint == '/web/dataset/call_kw/pos.order.line/read') {
      final ids = (params['args'][0] as List<dynamic>).cast<int>();
      return ids.map((id) => orderLines[id]).whereType<Map<String, dynamic>>().toList();
    }

    if (endpoint == '/web/dataset/call_kw/pos.config/search_read') {
      return configs.values.toList();
    }

    if (endpoint == '/web/dataset/call_kw/pos.order/sync_from_ui') {
      final payloadList = params['args'][0] as List<dynamic>;
      final resultOrderSummaries = <Map<String, dynamic>>[];

      for (final rawPayload in payloadList) {
        final payload = rawPayload as Map<String, dynamic>;
        receivedPayloads.add(payload);

        final sessionId = payload['session_id'] as int;
        final targetSession = sessions[sessionId];
        if (targetSession == null || targetSession['state'] != 'opened') {
          throw OdooServerException(
            message: 'OdooServerException: The POS session $sessionId is closed.',
          );
        }

        // Validate Odoo 19 Invariants
        final amountTotal = (payload['amount_total'] as num).toDouble();
        final amountPaid = (payload['amount_paid'] as num).toDouble();
        final amountReturn = (payload['amount_return'] as num).toDouble();

        if (amountReturn != 0.0) {
          throw OdooServerException(message: 'amount_return must be 0.0 in Odoo 19');
        }
        if ((amountPaid - amountTotal).abs() > 0.01) {
          throw OdooServerException(message: 'amount_paid must equal amount_total');
        }

        final isRefund = payload['is_refund'] == true;
        if (isRefund) {
          final parentOrderId = payload['refunded_order_id'];
          if (parentOrderId == null || parentOrderId == false) {
            throw OdooServerException(message: 'Refund order must specify refunded_order_id');
          }

          if (amountTotal > 0 || amountPaid > 0) {
            throw OdooServerException(
              message: 'Refund amount_total and amount_paid must be negative',
            );
          }

          // Validate negative lines & increment refunded_qty on parents
          final rawLines = (payload['lines'] as List<dynamic>?) ?? [];
          if (rawLines.isEmpty) {
            throw OdooServerException(
              message: 'Refund line must specify valid refunded_orderline_id',
            );
          }

          for (final cmd in rawLines) {
            final lineVals = cmd[2] as Map<String, dynamic>;
            final qty = (lineVals['qty'] as num).toDouble();
            if (qty >= 0) {
              throw OdooServerException(message: 'Refund line qty must be negative');
            }
            final parentLineId = lineVals['refunded_orderline_id'];
            if (parentLineId == null ||
                parentLineId == false ||
                parentLineId is! int ||
                !orderLines.containsKey(parentLineId)) {
              throw OdooServerException(
                message: 'Refund line must specify valid refunded_orderline_id',
              );
            }
            final parent = orderLines[parentLineId]!;
            final currentRefunded = (parent['refunded_qty'] as num).toDouble();
            final origQty = (parent['qty'] as num).toDouble();
            final newRefunded = currentRefunded + qty.abs();
            if (newRefunded > origQty + 0.001) {
              throw OdooServerException(message: 'Over-refund attempt on line $parentLineId');
            }
            parent['refunded_qty'] = newRefunded;
          }

          // Validate that every payment in payload['payment_ids'] has negative amount
          final rawPayments = (payload['payment_ids'] as List<dynamic>?) ?? [];
          for (final pCmd in rawPayments) {
            final pVals = pCmd[2] as Map<String, dynamic>;
            final pAmount = (pVals['amount'] as num).toDouble();
            if (pAmount > 0) {
              throw OdooServerException(
                message: 'Refund payment amount must be negative',
              );
            }
          }

          // Recompute has_refundable_lines on parent order
          if (parentOrderId is int && orders.containsKey(parentOrderId)) {
            final parent = orders[parentOrderId]!;
            final pLineIds = (parent['lines'] as List<dynamic>).cast<int>();
            final hasRemaining = pLineIds.any((lid) {
              final pl = orderLines[lid]!;
              return ((pl['qty'] as num).toDouble() - (pl['refunded_qty'] as num).toDouble()) > 0;
            });
            parent['has_refundable_lines'] = hasRemaining;
          }
        }

        final newId = _nextOrderId++;
        resultOrderSummaries.add({
          'id': newId,
          'pos_reference': payload['pos_reference'],
          'session_id': sessionId,
          'book_stock_applied': true,
        });
      }

      return {'pos.order': resultOrderSummaries};
    }

    return {};
  }

  bool _matchesDomain(Map<String, dynamic> record, List<dynamic> domain) {
    if (domain.isEmpty) return true;
    final hasOr = domain.contains('|');
    if (hasOr) {
      final searchClauses = domain.whereType<List>().where((c) => c.length == 3 && c[1] == 'ilike').toList();
      final stateClause = domain.whereType<List>().firstWhere(
        (c) => c.length == 3 && c[0] == 'state',
        orElse: () => [],
      );

      if (stateClause.isNotEmpty) {
        final allowedStates = stateClause[2] as List;
        if (!allowedStates.contains(record['state'])) return false;
      }

      if (searchClauses.isEmpty) return true;
      return searchClauses.any((clause) {
        final field = clause[0] as String;
        final target = clause[2].toString().toLowerCase();
        final val = record[field];
        final strVal = val?.toString().toLowerCase() ?? '';
        return strVal.contains(target);
      });
    }

    for (final clause in domain) {
      if (clause is List && clause.length == 3) {
        final field = clause[0] as String;
        final operator = clause[1] as String;
        final target = clause[2];

        final val = record[field];
        if (operator == '=') {
          if (val is List && val.isNotEmpty) {
            if (val[0] != target) return false;
          } else if (val != target) {
            return false;
          }
        } else if (operator == 'ilike') {
          final strVal = val?.toString().toLowerCase() ?? '';
          if (!strVal.contains(target.toString().toLowerCase())) return false;
        } else if (operator == 'in' && target is List) {
          if (!target.contains(val)) return false;
        }
      }
    }
    return true;
  }
}

// ============================================================================
// 2. Simulated Connectivity Service
// ============================================================================
class E2EConnectivityService implements NetworkConnectivityService {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _online = true;

  E2EConnectivityService({bool initialOnline = true}) : _online = initialOnline;

  @override
  Future<bool> isConnected() async => _online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool online) {
    _online = online;
    _controller.add(online);
  }

  void dispose() => _controller.close();
}

// ============================================================================
// 3. Riverpod State Management Providers for Returns & Past Orders
// ============================================================================

/// State for Return Order creation workflow.
class ReturnOrderState {
  final OrderModel? originalOrder;
  final Map<int, double> selectedQuantities; // lineId -> quantity
  final int? selectedPaymentMethodId;
  final double totalRefund;
  final bool isSubmitting;
  final String? errorMessage;

  const ReturnOrderState({
    this.originalOrder,
    this.selectedQuantities = const {},
    this.selectedPaymentMethodId,
    this.totalRefund = 0.0,
    this.isSubmitting = false,
    this.errorMessage,
  });

  ReturnOrderState copyWith({
    OrderModel? originalOrder,
    Map<int, double>? selectedQuantities,
    int? selectedPaymentMethodId,
    double? totalRefund,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ReturnOrderState(
      originalOrder: originalOrder ?? this.originalOrder,
      selectedQuantities: selectedQuantities ?? this.selectedQuantities,
      selectedPaymentMethodId: selectedPaymentMethodId ?? this.selectedPaymentMethodId,
      totalRefund: totalRefund ?? this.totalRefund,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

/// Manages return creation, quantity validation, tender selection, and submission.
class ReturnOrderNotifier extends StateNotifier<ReturnOrderState> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  ReturnOrderNotifier(this._orderRepo, this._ref) : super(const ReturnOrderState());

  void initForOrder(OrderModel order) {
    state = ReturnOrderState(
      originalOrder: order,
      selectedQuantities: {},
      selectedPaymentMethodId: null,
      totalRefund: 0.0,
    );
  }

  void setQuantity(int lineId, double qty) {
    final order = state.originalOrder;
    if (order == null) return;

    final line = order.lines.firstWhere(
      (l) => l.id == lineId,
      orElse: () => throw ArgumentError('Line $lineId not found in order'),
    );

    if (qty < 0) {
      throw ArgumentError('Return quantity cannot be negative');
    }

    final effectiveQty = qty.clamp(0.0, line.refundableQty);
    final updatedMap = Map<int, double>.from(state.selectedQuantities);
    if (effectiveQty > 0) {
      updatedMap[lineId] = effectiveQty;
    } else {
      updatedMap.remove(lineId);
    }

    // Recalculate total refund
    double total = 0.0;
    for (final entry in updatedMap.entries) {
      final l = order.lines.firstWhere((x) => x.id == entry.key);
      final unitGross = l.qty != 0 ? (l.priceSubtotalIncl / l.qty) : l.priceUnit;
      total += unitGross * entry.value;
    }

    state = state.copyWith(
      selectedQuantities: updatedMap,
      totalRefund: double.parse(total.toStringAsFixed(2)),
    );
  }

  void incrementQuantity(int lineId) {
    final current = state.selectedQuantities[lineId] ?? 0.0;
    setQuantity(lineId, current + 1.0);
  }

  void decrementQuantity(int lineId) {
    final current = state.selectedQuantities[lineId] ?? 0.0;
    setQuantity(lineId, (current - 1.0).clamp(0.0, double.infinity));
  }

  void setPaymentMethod(int methodId) {
    if (![1, 2, 3].contains(methodId)) {
      throw ArgumentError('Invalid payment method ID: $methodId');
    }
    state = state.copyWith(selectedPaymentMethodId: methodId);
  }

  Future<OrderModel> submit() async {
    final order = state.originalOrder;
    if (order == null) {
      throw StateError('No original order initialized for return');
    }
    if (state.selectedQuantities.isEmpty || state.totalRefund <= 0) {
      throw StateError('No items selected for return');
    }
    if (state.selectedPaymentMethodId == null) {
      throw StateError('Payment method not selected');
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final returnLinesMap = <OrderLineModel, double>{};
      for (final entry in state.selectedQuantities.entries) {
        final line = order.lines.firstWhere((l) => l.id == entry.key);
        returnLinesMap[line] = entry.value;
      }

      final activeSession = _ref.read(sessionProvider).activeSession;
      final sessionId = activeSession?.id ?? order.sessionId;

      final returnOrder = await _orderRepo.submitReturnOrder(
        originalOrder: order,
        returnLines: returnLinesMap,
        paymentMethodId: state.selectedPaymentMethodId!,
        sessionId: sessionId,
      );

      _ref.read(lastCompletedOrderProvider.notifier).state = returnOrder;
      state = state.copyWith(isSubmitting: false);
      return returnOrder;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      rethrow;
    }
  }
}

final returnOrderProvider =
    StateNotifierProvider<ReturnOrderNotifier, ReturnOrderState>((ref) {
  final repo = ref.watch(orderRepositoryProvider);
  return ReturnOrderNotifier(repo, ref);
});

/// Manages searching, filtering, and fetching past orders.
class PastOrdersNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  final OrderRepository _orderRepo;

  PastOrdersNotifier(this._orderRepo) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final orders = await _orderRepo.searchPastOrders(query);
      if (mounted) {
        state = AsyncValue.data(orders);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> scanBarcode(String code) async {
    await search(code);
  }
}

final pastOrdersProvider =
    StateNotifierProvider<PastOrdersNotifier, AsyncValue<List<OrderModel>>>((ref) {
  final repo = ref.watch(orderRepositoryProvider);
  return PastOrdersNotifier(repo);
});

// ============================================================================
// 4. Responsive UI Screens for E2E Flow Testing
// ============================================================================

/// Order History Screen (`/orders`)
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(pastOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('অর্ডার ইতিহাস ও রিটার্ন'),
        actions: [
          IconButton(
            key: const Key('barcode_scanner_button'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'বারকোড স্ক্যান',
            onPressed: () {
              // Simulate scanning barcode '4001'
              _searchController.text = '4001';
              ref.read(pastOrdersProvider.notifier).scanBarcode('4001');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              key: const Key('order_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'অর্ডার নং / রসিদ / বারকোড দিয়ে খুঁজুন...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(pastOrdersProvider.notifier).search('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              onChanged: (val) => ref.read(pastOrdersProvider.notifier).search(val),
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('ত্রুটি: $err')),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Text('কোনো অর্ডার পাওয়া যায়নি',
                        style: TextStyle(color: AppColors.textMuted)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    return Card(
                      key: Key('order_item_${o.id}'),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        title: Text(
                          o.posReference,
                          style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'তারিখ: ${o.ticketCode} • মোট: ${CurrencyFormatter.formatBDT(o.amountTotal)}',
                          style: AppTypography.caption,
                        ),
                        trailing: o.hasRefundableLines
                            ? const Chip(
                                label: Text('ফেরতযোগ্য', style: TextStyle(fontSize: 12)),
                                backgroundColor: AppColors.statusInStockBg,
                              )
                            : const Chip(
                                label: Text('সম্পূর্ণ রিফান্ড', style: TextStyle(fontSize: 12)),
                                backgroundColor: AppColors.statusLowStockBg,
                              ),
                        onTap: () {
                          Navigator.pushNamed(context, '/orders/detail', arguments: o);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Order Detail Screen (`/orders/detail`)
class OrderDetailScreen extends ConsumerWidget {
  final OrderModel? order;

  const OrderDetailScreen({super.key, this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveOrder = order ?? (ModalRoute.of(context)?.settings.arguments as OrderModel?);
    if (effectiveOrder == null) {
      return const Scaffold(body: Center(child: Text('অর্ডার পাওয়া যায়নি')));
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('অর্ডার বিবরণ: ${effectiveOrder.posReference}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('POS Ref: ${effectiveOrder.posReference}',
                              style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w700)),
                          Text('টিকেট: ${effectiveOrder.ticketCode}', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatBDT(effectiveOrder.amountTotal),
                      style: AppTypography.heading2.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: effectiveOrder.lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final line = effectiveOrder.lines[i];
                return Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.productName,
                                style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'ক্রয়: ${line.qty.toInt()} টি • মূল্য: ${CurrencyFormatter.formatBDT(line.priceUnit)}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          key: Key('refundable_badge_${line.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: line.refundableQty > 0
                                ? AppColors.statusInStockBg
                                : AppColors.statusLowStockBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ফেরতযোগ্য: ${line.refundableQty.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: line.refundableQty > 0
                                  ? AppColors.statusInStock
                                  : AppColors.statusLowStock,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('process_return_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                ),
                icon: const Icon(Icons.assignment_return_rounded),
                label: Text(
                  effectiveOrder.hasRefundableLines ? 'পণ্য ফেরত ও রিফান্ড' : 'সম্পূর্ণ রিফান্ড করা হয়েছে',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: effectiveOrder.hasRefundableLines
                    ? () {
                        ref.read(returnOrderProvider.notifier).initForOrder(effectiveOrder);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) => ReturnProcessBottomSheet(originalOrder: effectiveOrder),
                        );
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Return Process Bottom Sheet (`ReturnProcessBottomSheet`)
class ReturnProcessBottomSheet extends ConsumerWidget {
  final OrderModel originalOrder;

  const ReturnProcessBottomSheet({super.key, required this.originalOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnState = ref.watch(returnOrderProvider);
    final notifier = ref.read(returnOrderProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('রিটার্ন ও রিফান্ড প্রক্রিয়া',
                          style: AppTypography.heading2.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text('ফেরতযোগ্য পণ্য তালিকা',
                        style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    ...originalOrder.lines.map((line) {
                      final selectedQty = returnState.selectedQuantities[line.id] ?? 0.0;
                      final canIncrement = selectedQty < line.refundableQty;
                      final canDecrement = selectedQty > 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        color: AppColors.canvas,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(line.productName,
                                        style: AppTypography.bodyRegular
                                            .copyWith(fontWeight: FontWeight.w600)),
                                    Text(
                                      'উপলব্ধ: ${line.refundableQty.toInt()} • একক মূল্য: ${CurrencyFormatter.formatBDT(line.priceUnit)}',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    key: Key('stepper_decrement_${line.id}'),
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: canDecrement
                                        ? () {
                                            HapticFeedback.lightImpact();
                                            notifier.decrementQuantity(line.id!);
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '${selectedQty.toInt()}',
                                    key: Key('stepper_value_${line.id}'),
                                    style: AppTypography.bodyRegular
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  IconButton(
                                    key: Key('stepper_increment_${line.id}'),
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: canIncrement
                                        ? () {
                                            HapticFeedback.lightImpact();
                                            notifier.incrementQuantity(line.id!);
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                    Text('রিফান্ড পেমেন্ট মাধ্যম নির্বাচন করুন',
                        style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: const Text('নগদ (Cash)'),
                          selected: returnState.selectedPaymentMethodId == 1,
                          onSelected: (_) => notifier.setPaymentMethod(1),
                        ),
                        ChoiceChip(
                          label: const Text('কার্ড (Card)'),
                          selected: returnState.selectedPaymentMethodId == 2,
                          onSelected: (_) => notifier.setPaymentMethod(2),
                        ),
                        ChoiceChip(
                          label: const Text('bKash'),
                          selected: returnState.selectedPaymentMethodId == 3,
                          onSelected: (_) => notifier.setPaymentMethod(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Total refund banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.statusLowStockBg,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: AppColors.statusLowStock),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('সর্বমোট রিফান্ড পরিমাণ:',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text(
                            CurrencyFormatter.formatBDT(-returnState.totalRefund),
                            style: AppTypography.heading2.copyWith(
                              color: AppColors.statusOutOfStock,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('confirm_refund_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOutOfStock,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (returnState.totalRefund > 0 &&
                            returnState.selectedPaymentMethodId != null &&
                            !returnState.isSubmitting)
                        ? () async {
                            final returnOrder = await notifier.submit();
                            if (context.mounted) {
                              Navigator.pop(context); // close sheet
                              Navigator.pushReplacementNamed(
                                context,
                                '/receipt',
                                arguments: returnOrder,
                              );
                            }
                          }
                        : null,
                    child: returnState.isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'রিফান্ড নিশ্চিত করুন',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class E2ESyncQueueNotifier extends SyncQueueNotifier {
  E2ESyncQueueNotifier({
    required super.queueRepo,
    required super.orderService,
    required super.sessionService,
  });

  @override
  Future<void> refreshCounts() async {}
}

// ============================================================================
// 5. Central E2E Test Harness
// ============================================================================
class E2ETestHarness {
  late DatabaseHelper dbHelper;
  late OfflineQueueRepository queueRepo;
  late E2EMockOdooServer mockServer;
  late E2EConnectivityService connectivity;
  late OdooOrderService orderService;
  late OdooSessionService sessionService;
  late OrderRepository orderRepository;

  final List<ProviderContainer> _containers = [];
  int _nextLineId = 501;

  static void initializeFfi() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppTypography.enableGoogleFonts = false;
  }

  Future<void> setUp() async {
    _nextLineId = 501;
    AppTypography.enableGoogleFonts = false;
    dbHelper = DatabaseHelper(customDbPath: inMemoryDatabasePath);
    queueRepo = OfflineQueueRepository(dbHelper: dbHelper);
    mockServer = E2EMockOdooServer();
    connectivity = E2EConnectivityService();

    final mockHttpClient = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final params = body['params'] as Map<String, dynamic>;
      final result = await mockServer.handleRpc(request.url.path, params);
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final rpcClient = OdooJsonRpcClient(
      baseUrl: 'https://demostore.metaposbd.com',
      httpClient: mockHttpClient,
    );

    orderService = OdooOrderService(client: rpcClient);
    sessionService = OdooSessionService(client: rpcClient);

    orderRepository = OrderRepositoryImpl(
      queueRepo: queueRepo,
      orderService: orderService,
      sessionService: sessionService,
    );
  }

  Future<void> tearDown() async {
    _nextLineId = 501;
    for (final container in _containers) {
      container.dispose();
    }
    _containers.clear();
    connectivity.dispose();
    await dbHelper.close();
  }

  ProviderContainer createContainer({List<Override> overrides = const []}) {
    final container = ProviderContainer(
      overrides: [
        databaseHelperProvider.overrideWithValue(dbHelper),
        offlineQueueRepositoryProvider.overrideWithValue(queueRepo),
        orderRepositoryProvider.overrideWithValue(orderRepository),
        orderServiceProvider.overrideWithValue(orderService),
        sessionServiceProvider.overrideWithValue(sessionService),
        connectivityServiceProvider.overrideWithValue(connectivity),
        isOnlineProvider.overrideWith((ref) => connectivity._online),
        printerProvider.overrideWith((ref) => PrinterNotifier(simulationDelay: Duration.zero)),
        syncQueueProvider.overrideWith(
          (ref) => E2ESyncQueueNotifier(
            queueRepo: queueRepo,
            orderService: orderService,
            sessionService: sessionService,
          ),
        ),
        orderSyncStatusProvider.overrideWith(
          (ref, uuid) async => await orderRepository.getOrderSyncStatus(uuid),
        ),
        ...overrides,
      ],
    );
    _containers.add(container);
    return container;
  }

  Widget buildE2EApp(
    Widget home, {
    ProviderContainer? container,
    Size viewport = const Size(390, 844),
  }) {
    final activeContainer = container ?? createContainer();
    return MediaQuery(
      data: MediaQueryData(
        size: viewport,
        devicePixelRatio: 1.0,
      ),
      child: UncontrolledProviderScope(
        container: activeContainer,
        child: MaterialApp(
          home: home,
          routes: {
            '/orders': (c) => const OrderHistoryScreen(),
            '/orders/detail': (c) => const OrderDetailScreen(),
            '/receipt': (c) => const OrderSuccessReceiptScreen(),
          },
        ),
      ),
    );
  }

  // --- Common Test Fixtures ---

  OrderModel seedSingleItemOrder({
    int orderId = 101,
    String posRef = '261-1-000101',
    String ticketCode = 't101a',
    String barcode = '4001',
    double qty = 3.0,
    double price = 100.0,
    double refundedQty = 0.0,
    int? lineId,
    int? partnerId,
    String? partnerName,
    String? partnerPhone,
    DateTime? createdAt,
  }) {
    final line = OrderLineModel.create(
      id: lineId ?? _nextLineId++,
      productId: 62,
      productName: 'ব্ল্যাকবার্ড ক্লাসিক',
      qty: qty,
      priceUnit: price,
      refundedQty: refundedQty,
      isTaxInclusive: true,
    );
    final payment = PaymentLineModel.create(
      paymentMethodId: 1,
      paymentMethodName: 'নগদ (Cash)',
      amount: qty * price,
      sessionId: 23,
    );
    return mockServer.seedOriginalOrder(
      orderId: orderId,
      posReference: posRef,
      ticketCode: ticketCode,
      barcode: barcode,
      sessionId: 23,
      lines: [line],
      payments: [payment],
      partnerId: partnerId,
      partnerName: partnerName,
      partnerPhone: partnerPhone,
      createdAt: createdAt,
    );
  }

  OrderModel seedMultiItemMixedTaxOrder({
    int orderId = 102,
    String posRef = '261-1-000102',
    String ticketCode = 't102b',
    String barcode = '4002',
    int? line1Id,
    int? line2Id,
  }) {
    final line1 = OrderLineModel.create(
      id: line1Id ?? _nextLineId++,
      productId: 62,
      productName: 'ব্ল্যাকবার্ড ক্লাসিক',
      qty: 2.0,
      priceUnit: 100.0,
      taxIds: [1], // 10% VAT
      isTaxInclusive: true,
    );
    final line2 = OrderLineModel.create(
      id: line2Id ?? _nextLineId++,
      productId: 242,
      productName: 'ক্রিসমাস অ্যাট হগওয়ার্টস',
      qty: 1.0,
      priceUnit: 750.0,
      taxIds: [], // 0% Tax
      isTaxInclusive: true,
    );
    final payment = PaymentLineModel.create(
      paymentMethodId: 2,
      paymentMethodName: 'কার্ড (Card)',
      amount: 950.0,
      sessionId: 23,
    );
    return mockServer.seedOriginalOrder(
      orderId: orderId,
      posReference: posRef,
      ticketCode: ticketCode,
      barcode: barcode,
      sessionId: 23,
      lines: [line1, line2],
      payments: [payment],
    );
  }

  OrderModel buildReturnOrder({
    required OrderModel originalOrder,
    required Map<OrderLineModel, double> returnLines,
    required int paymentMethodId,
    required int sessionId,
  }) {
    const uuidGen = Uuid();
    final now = DateTime.now();
    final List<OrderLineModel> returnLinesList = [];
    double totalRefundGross = 0.0;
    double totalRefundTax = 0.0;

    for (final entry in returnLines.entries) {
      final origLine = entry.key;
      final qtyToReturn = entry.value;
      if (qtyToReturn <= 0) continue;

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
        uuid: uuidGen.v4(),
        productId: origLine.productId,
        productName: origLine.productName,
        qty: -qtyToReturn,
        priceUnit: origLine.priceUnit,
        discount: origLine.discount,
        priceSubtotal: -lineRefundNet,
        priceSubtotalIncl: -lineRefundGross,
        taxIds: origLine.taxIds,
        customerNote: origLine.customerNote,
        refundedOrderlineId: origLine.id,
        refundedQty: 0.0,
      ));
    }

    totalRefundGross = double.parse(totalRefundGross.toStringAsFixed(2));
    totalRefundTax = double.parse(totalRefundTax.toStringAsFixed(2));

    final double negativeTotal = -totalRefundGross;
    final double negativeTax = -totalRefundTax;

    final paymentLine = PaymentLineModel(
      uuid: uuidGen.v4(),
      paymentMethodId: paymentMethodId,
      amount: negativeTotal,
      isChange: false,
      sessionId: sessionId,
      paymentDate: now,
    );

    return OrderModel(
      uuid: uuidGen.v4(),
      posReference: 'RETURN-${originalOrder.posReference}-${uuidGen.v4().substring(0, 5)}',
      ticketCode: uuidGen.v4().substring(0, 5).toLowerCase(),
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
      accessToken: uuidGen.v4(),
      isSynced: false,
      isRefund: true,
      refundedOrderId: originalOrder.id,
      hasRefundableLines: false,
    );
  }

  // --- Domain Verification Assertions ---

  void verifyReturnOrderInvariants(OrderModel returnOrder, OrderModel originalOrder) {
    expect(returnOrder.isRefund, isTrue, reason: 'Order must have is_refund == true');
    expect(returnOrder.refundedOrderId, originalOrder.id, reason: 'Must link to original order ID');
    expect(returnOrder.amountTotal, lessThan(0), reason: 'Refund total must be negative');
    expect(returnOrder.amountPaid, equals(returnOrder.amountTotal),
        reason: 'Refund amount_paid must equal amount_total');
    expect(returnOrder.amountReturn, 0.0, reason: 'amount_return must be 0.0');

    for (final line in returnOrder.lines) {
      expect(line.qty, lessThan(0), reason: 'Return line qty must be negative');
      expect(line.priceSubtotalIncl, lessThan(0), reason: 'Return line subtotal must be negative');
      expect(line.refundedOrderlineId, isNotNull, reason: 'Must link to parent order line ID');
    }

    for (final p in returnOrder.payments) {
      expect(p.amount, lessThan(0), reason: 'Refund payment amount must be negative');
      expect(p.isChange, isFalse, reason: 'Refund payments must not be change lines');
    }
  }

  void verifyZeroOverflow(WidgetTester tester) {
    expect(tester.takeException(), isNull,
        reason: 'Widget rendered with exceptions or RenderFlex overflow');
  }

  void verifyWholeBDT(String text) {
    expect(text.contains('৳'), isTrue, reason: 'Must contain Taka symbol');
    expect(text.contains('.00'), isFalse, reason: 'Must not contain decimal slop .00');
  }
}
