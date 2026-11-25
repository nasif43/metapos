import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/models/session_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/data/repositories/order_repository.dart';
import 'package:metapos/providers/order_provider.dart';
import 'package:metapos/providers/return_order_provider.dart';
import 'package:metapos/providers/session_provider.dart';

/// Test fake for [OrderRepository].
class FakeOrderRepository implements OrderRepository {
  OrderModel? lastOriginalOrder;
  Map<OrderLineModel, double>? lastReturnLines;
  int? lastPaymentMethodId;
  int? lastSessionId;
  bool? lastIsOnline;
  bool? lastIsOfflineMode;
  bool? lastReverseNetTax;

  int submitCallCount = 0;
  Duration? submitDelay;
  bool shouldThrowOnSubmitReturn = false;
  String submitErrorMessage = 'Network unreachable during return sync';
  OrderModel? customReturnOrderToReturn;

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
    submitCallCount++;
    if (submitDelay != null) {
      await Future.delayed(submitDelay!);
    }
    lastOriginalOrder = originalOrder;
    lastReturnLines = returnLines;
    lastPaymentMethodId = paymentMethodId;
    lastSessionId = sessionId;
    lastIsOnline = isOnline;
    lastIsOfflineMode = isOfflineMode;
    lastReverseNetTax = reverseNetTax;

    if (shouldThrowOnSubmitReturn) {
      throw Exception(submitErrorMessage);
    }

    if (customReturnOrderToReturn != null) {
      return customReturnOrderToReturn!;
    }

    // Default genuine refund order
    return OrderModel.create(
      id: 901,
      sessionId: sessionId,
      posReference: 'RETURN-${originalOrder.posReference}-001',
      ticketCode: 'r101',
      trackingNumber: '5101',
      isRefund: true,
      refundedOrderId: originalOrder.id,
      hasRefundableLines: false,
      isSynced: isOnline,
      lines: returnLines.entries.map((e) {
        return OrderLineModel.create(
          id: 801,
          productId: e.key.productId,
          productName: e.key.productName,
          qty: -e.value,
          priceUnit: e.key.priceUnit,
          refundedOrderlineId: e.key.id,
        );
      }).toList(),
      payments: [
        PaymentLineModel(
          uuid: 'pay-refund-001',
          paymentMethodId: paymentMethodId,
          amount: -originalOrder.amountTotal,
        )
      ],
    );
  }

  @override
  Future<List<OrderModel>> searchPastOrders(String query, {int limit = 50}) async => [];

  @override
  Future<OrderModel> submitOrder(
    OrderModel order, {
    required bool isOnline,
    required bool isOfflineMode,
    bool reverseNetTax = false,
  }) async =>
      order;

  @override
  Future<void> syncPendingOrders({bool reverseNetTax = false}) async {}

  @override
  Future<int> getPendingCount() async => 0;

  @override
  Future<int> getSyncedCount() async => 0;

  @override
  Future<String?> getOrderSyncStatus(String uuid) async => 'synced';

  @override
  Future<OrderModel?> getOrder(String uuid) async => null;

  @override
  Future<List<OrderLineModel>> fetchOrderLines(List<int> lineIds) async => [];
}

void main() {
  group('ReturnOrderProvider Unit Tests', () {
    late FakeOrderRepository fakeRepo;
    late OrderModel sampleOrder;
    late OrderLineModel line1;
    late OrderLineModel line2;
    late OrderLineModel fullyRefundedLine;

    setUp(() {
      fakeRepo = FakeOrderRepository();

      // Line 1: qty = 3.0, refundedQty = 1.0 -> refundableQty = 2.0, priceUnit = 500, priceSubtotalIncl = 1500 (unit gross = 500)
      line1 = OrderLineModel.create(
        id: 473,
        productId: 101,
        productName: 'Computer Programming Vol 1',
        qty: 3.0,
        priceUnit: 500.0,
        refundedQty: 1.0,
      );

      // Line 2: qty = 2.0, refundedQty = 0.0 -> refundableQty = 2.0, priceUnit = 350, priceSubtotalIncl = 700 (unit gross = 350)
      line2 = OrderLineModel.create(
        id: 474,
        productId: 102,
        productName: 'Hablu Programmer',
        qty: 2.0,
        priceUnit: 350.0,
        refundedQty: 0.0,
      );

      // Line 3: qty = 1.0, refundedQty = 1.0 -> refundableQty = 0.0 (non-refundable)
      fullyRefundedLine = OrderLineModel.create(
        id: 475,
        productId: 103,
        productName: 'Padma Nadir Majhi',
        qty: 1.0,
        priceUnit: 200.0,
        refundedQty: 1.0,
      );

      sampleOrder = OrderModel.create(
        id: 420,
        sessionId: 23,
        posReference: '264-1-000420',
        ticketCode: '0qfc5',
        trackingNumber: '4001',
        lines: [line1, line2, fullyRefundedLine],
        payments: [],
      );
    });

    ProviderContainer createContainer({
      SessionModel? activeSession = const SessionModel(
        id: 23,
        name: 'Book Fair/00014',
        configId: 1,
        state: 'opened',
      ),
    }) {
      final mockHttpClient = MockClient((_) async => http.Response(jsonEncode({}), 200));
      final rpcClient = OdooJsonRpcClient(baseUrl: 'http://localhost', httpClient: mockHttpClient);
      final sessionService = OdooSessionService(client: rpcClient);

      return ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepo),
          sessionProvider.overrideWith((ref) {
            final notifier = PosSessionNotifier(sessionService: sessionService);
            notifier.state = PosSessionState(activeSession: activeSession);
            return notifier;
          }),
        ],
      );
    }

    test('Initial state is clean with defaults', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = container.read(returnOrderProvider);
      expect(state.originalOrder, isNull);
      expect(state.selectedQuantities, isEmpty);
      expect(state.paymentMethodId, isNull);
      expect(state.isSubmitting, isFalse);
      expect(state.error, isNull);
      expect(state.completedRefundOrder, isNull);
      expect(state.hasSelectedLines, isFalse);
      expect(state.totalRefund, 0.0);
      expect(state.refundableLineCount, 0);
      expect(state.totalItemsToReturn, 0.0);
    });

    test('initForOrder initializes return session and clears prior selections and errors', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(sampleOrder);

      final state = container.read(returnOrderProvider);
      expect(state.originalOrder, sampleOrder);
      expect(state.selectedQuantities, isEmpty);
      expect(state.paymentMethodId, isNull);
      expect(state.isSubmitting, isFalse);
      expect(state.error, isNull);
      expect(state.completedRefundOrder, isNull);
      expect(state.refundableLineCount, 2,
          reason: 'line1 and line2 have refundableQty > 0; fullyRefundedLine has 0');
    });

    test('initForOrder throws ArgumentError if order is already a refund', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final refundOrder = OrderModel.create(
        id: 421,
        sessionId: 23,
        posReference: 'RETURN-264-1-000420-abc',
        isRefund: true,
        lines: [],
        payments: [],
      );

      final notifier = container.read(returnOrderProvider.notifier);
      expect(
        () => notifier.initForOrder(refundOrder),
        throwsA(isA<ArgumentError>()),
      );
    });

    group('Quantity Bounding & Over-Refund Prevention', () {
      late ProviderContainer container;
      late ReturnOrderNotifier notifier;

      setUp(() {
        container = createContainer();
        notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
      });

      tearDown(() {
        container.dispose();
      });

      test('setQuantity within refundableQty succeeds', () {
        notifier.setQuantity(473, 1.0);
        var state = container.read(returnOrderProvider);
        expect(state.selectedQuantities[473], 1.0);
        expect(state.hasSelectedLines, isTrue);
        expect(state.totalItemsToReturn, 1.0);
        // line1 has priceUnit 500 + 10% VAT = 550 gross
        expect(state.totalRefund, 550.0);

        notifier.setQuantity(473, 2.0);
        state = container.read(returnOrderProvider);
        expect(state.selectedQuantities[473], 2.0);
        expect(state.totalRefund, 1100.0);
      });

      test('Over-refund prevention: requested quantity exceeding refundableQty is strictly clamped', () {
        // line1 has refundableQty = 2.0. Requesting 5.0 must clamp to 2.0
        notifier.setQuantity(473, 5.0);
        final state = container.read(returnOrderProvider);
        expect(state.selectedQuantities[473], 2.0);
      });

      test('Setting quantity on non-refundable line (refundableQty = 0) is clamped to 0 and removed', () {
        // fullyRefundedLine has id = 475, refundableQty = 0.0
        notifier.setQuantity(475, 1.0);
        final state = container.read(returnOrderProvider);
        expect(state.selectedQuantities.containsKey(475), isFalse);
      });

      test('Setting non-positive quantity (0 or negative) removes line from selection', () {
        notifier.setQuantity(473, 2.0);
        expect(container.read(returnOrderProvider).selectedQuantities[473], 2.0);

        notifier.setQuantity(473, 0.0);
        expect(container.read(returnOrderProvider).selectedQuantities.containsKey(473), isFalse);

        notifier.setQuantity(473, -1.0);
        expect(container.read(returnOrderProvider).selectedQuantities.containsKey(473), isFalse);
      });

      test('Setting quantity for line not in original order is ignored', () {
        notifier.setQuantity(9999, 1.0);
        final state = container.read(returnOrderProvider);
        expect(state.selectedQuantities.containsKey(9999), isFalse);
      });
    });

    group('Increment & Decrement Bounds', () {
      late ProviderContainer container;
      late ReturnOrderNotifier notifier;

      setUp(() {
        container = createContainer();
        notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
      });

      tearDown(() {
        container.dispose();
      });

      test('incrementQuantity steps by 1.0 up to refundableQty ceiling', () {
        // line2 has refundableQty = 2.0
        notifier.incrementQuantity(474); // from 0 to 1.0
        expect(container.read(returnOrderProvider).selectedQuantities[474], 1.0);

        notifier.incrementQuantity(474); // from 1.0 to 2.0 (max)
        expect(container.read(returnOrderProvider).selectedQuantities[474], 2.0);

        notifier.incrementQuantity(474); // cannot exceed 2.0
        expect(container.read(returnOrderProvider).selectedQuantities[474], 2.0);
      });

      test('decrementQuantity steps by 1.0 down to 0 and removes selection', () {
        notifier.setQuantity(474, 2.0);
        expect(container.read(returnOrderProvider).selectedQuantities[474], 2.0);

        notifier.decrementQuantity(474); // from 2.0 to 1.0
        expect(container.read(returnOrderProvider).selectedQuantities[474], 1.0);

        notifier.decrementQuantity(474); // from 1.0 to 0.0 (removed)
        expect(container.read(returnOrderProvider).selectedQuantities.containsKey(474), isFalse);

        notifier.decrementQuantity(474); // below 0 (stays removed)
        expect(container.read(returnOrderProvider).selectedQuantities.containsKey(474), isFalse);
      });
    });

    group('Bulk Operations: returnAll() & clearSelection()', () {
      late ProviderContainer container;
      late ReturnOrderNotifier notifier;

      setUp(() {
        container = createContainer();
        notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
      });

      tearDown(() {
        container.dispose();
      });

      test('returnAll sets all lines with refundableQty > 0 to their max available refundable quantity', () {
        notifier.returnAll();

        final state = container.read(returnOrderProvider);
        expect(state.selectedQuantities.length, 2);
        expect(state.selectedQuantities[473], 2.0); // line1 max
        expect(state.selectedQuantities[474], 2.0); // line2 max
        expect(state.selectedQuantities.containsKey(475), isFalse); // line3 was 0, excluded

        expect(state.totalItemsToReturn, 4.0);
        // (2 * 550) + (2 * 385) = 1100 + 770 = 1870.0 (including 10% VAT)
        expect(state.totalRefund, 1870.0);
      });

      test('clearSelection resets selectedQuantities map to empty', () {
        notifier.returnAll();
        expect(container.read(returnOrderProvider).hasSelectedLines, isTrue);

        notifier.clearSelection();
        final state = container.read(returnOrderProvider);
        expect(state.selectedQuantities, isEmpty);
        expect(state.hasSelectedLines, isFalse);
        expect(state.totalRefund, 0.0);
        expect(state.totalItemsToReturn, 0.0);
      });
    });

    test('Single parent order constraint: returns cannot mix orders', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(sampleOrder);
      notifier.setQuantity(473, 1.0);
      expect(container.read(returnOrderProvider).selectedQuantities[473], 1.0);

      // Create a second distinct order
      final secondOrder = OrderModel.create(
        id: 421,
        sessionId: 23,
        posReference: '264-1-000421',
        lines: [
          OrderLineModel.create(
            id: 476,
            productId: 104,
            productName: 'Second Order Book',
            qty: 1.0,
            priceUnit: 600.0,
          ),
        ],
        payments: [],
      );

      // Initializing for secondOrder resets all selections from first order
      notifier.initForOrder(secondOrder);
      final state = container.read(returnOrderProvider);
      expect(state.originalOrder, secondOrder);
      expect(state.selectedQuantities, isEmpty);
      expect(state.selectedQuantities.containsKey(473), isFalse);

      // Cannot add line473 from previous order
      notifier.setQuantity(473, 1.0);
      expect(container.read(returnOrderProvider).selectedQuantities.containsKey(473), isFalse);

      // Can add line476 from current order
      notifier.setQuantity(476, 1.0);
      expect(container.read(returnOrderProvider).selectedQuantities[476], 1.0);
    });

    test('Total refund calculation ensures whole BDT integer rounding without decimal slop', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final weirdOrder = OrderModel.create(
        id: 430,
        sessionId: 23,
        posReference: '264-1-000430',
        lines: [
          OrderLineModel(
            id: 991,
            uuid: 'u991',
            productId: 1,
            productName: 'Discounted Book',
            qty: 3.0,
            priceUnit: 333.3333,
            priceSubtotal: 900.0,
            priceSubtotalIncl: 999.99, // 333.33 per unit
          ),
        ],
        payments: [],
      );

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(weirdOrder);
      notifier.setQuantity(991, 1.0);

      final state = container.read(returnOrderProvider);
      // 999.99 / 3 = 333.33. Rounded whole BDT integer = 333.0
      expect(state.totalRefund, 333.0);
    });

    group('submitReturn Invariant Validations', () {
      test('Invariant 1: Empty selection fails', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setPaymentMethod(1); // Cash

        // Selection is empty
        final result = await notifier.submitReturn();
        expect(result, isNull);

        final state = container.read(returnOrderProvider);
        expect(state.isSubmitting, isFalse);
        expect(state.error, contains('পণ্যের পরিমাণ সঠিক নয়'));
      });

      test('Invariant 2: No original order fails', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        // Did not call initForOrder
        notifier.setPaymentMethod(1);

        final result = await notifier.submitReturn();
        expect(result, isNull);

        final state = container.read(returnOrderProvider);
        expect(state.isSubmitting, isFalse);
        expect(state.error, contains('এই মুহূর্তে কাজটি সম্পন্ন করা যায়নি'));
      });

      test('Invariant 3: No payment method fails', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 1.0);
        // paymentMethodId is null

        final result = await notifier.submitReturn();
        expect(result, isNull);

        final state = container.read(returnOrderProvider);
        expect(state.isSubmitting, isFalse);
        expect(state.error, contains('নির্বাচিত পেমেন্ট পদ্ধতি'));
      });

      test('Invariant 4: No active POS session fails', () async {
        // Create container with NO active session (null)
        final container = createContainer(activeSession: null);
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 1.0);
        notifier.setPaymentMethod(1);

        final result = await notifier.submitReturn();
        expect(result, isNull);

        final state = container.read(returnOrderProvider);
        expect(state.isSubmitting, isFalse);
        expect(state.error, contains('কাউন্টার সেশন চালু নেই'));
      });
    });

    group('Successful Return Submission & Receipt Provider Integration', () {
      test('submitReturn invokes repository, updates lastCompletedOrderProvider, and sets completedRefundOrder', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 2.0);
        notifier.setQuantity(474, 1.0);
        notifier.setPaymentMethod(1); // Cash

        final returnedOrder = await notifier.submitReturn();

        // 1. Returns genuine OrderModel
        expect(returnedOrder, isNotNull);
        expect(returnedOrder!.isRefund, isTrue);
        expect(returnedOrder.refundedOrderId, 420);

        // 2. Verified repository was invoked with correct parameters
        expect(fakeRepo.lastOriginalOrder, sampleOrder);
        expect(fakeRepo.lastSessionId, 23);
        expect(fakeRepo.lastPaymentMethodId, 1);
        expect(fakeRepo.lastReturnLines?.length, 2);
        expect(fakeRepo.lastReturnLines?[line1], 2.0);
        expect(fakeRepo.lastReturnLines?[line2], 1.0);

        // 3. Receipt integration: updates lastCompletedOrderProvider
        final lastCompletedOrder = container.read(lastCompletedOrderProvider);
        expect(lastCompletedOrder, equals(returnedOrder));

        // 4. ReturnOrderState is updated
        final state = container.read(returnOrderProvider);
        expect(state.completedRefundOrder, equals(returnedOrder));
        expect(state.isSubmitting, isFalse);
        expect(state.error, isNull);
      });

      test('Verified repository call count is tracked', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 1.0);
        notifier.setPaymentMethod(1);

        await notifier.submitReturn();
        expect(fakeRepo.submitCallCount, 1);
      });
    });

    group('Re-entrancy & Concurrency Protection', () {
      test('submitReturn returns null immediately if already isSubmitting', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 1.0);
        notifier.setPaymentMethod(1);

        // Manually set isSubmitting = true on state to simulate pre-existing in-flight submission
        notifier.state = notifier.state.copyWith(isSubmitting: true);

        final result = await notifier.submitReturn();

        expect(result, isNull);
        expect(fakeRepo.submitCallCount, 0);
      });

      test('Concurrent submitReturn calls (e.g. rapid double-tap) execute exactly once', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        // Introduce a slight delay in repository to simulate in-flight asynchronous execution
        fakeRepo.submitDelay = const Duration(milliseconds: 50);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 1.0);
        notifier.setPaymentMethod(1);

        // Fire two concurrent submitReturn calls before the first completes
        final future1 = notifier.submitReturn();
        final future2 = notifier.submitReturn();

        final results = await Future.wait([future1, future2]);

        // Exactly one submission occurs to repository
        expect(fakeRepo.submitCallCount, 1);

        // Exactly one of the calls yields the OrderModel, and the other yields null
        final nonNullResults = results.whereType<OrderModel>().toList();
        final nullResults = results.where((r) => r == null).toList();

        expect(nonNullResults.length, 1);
        expect(nullResults.length, 1);
        expect(nonNullResults.first.isRefund, isTrue);

        final state = container.read(returnOrderProvider);
        expect(state.isSubmitting, isFalse);
        expect(state.completedRefundOrder, equals(nonNullResults.first));
      });

      test('Subsequent submitReturn is allowed after previous submission completes', () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(returnOrderProvider.notifier);
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(473, 1.0);
        notifier.setPaymentMethod(1);

        final firstResult = await notifier.submitReturn();
        expect(firstResult, isNotNull);
        expect(fakeRepo.submitCallCount, 1);

        // Re-initialize for another line and submit again
        notifier.initForOrder(sampleOrder);
        notifier.setQuantity(474, 1.0);
        notifier.setPaymentMethod(1);

        final secondResult = await notifier.submitReturn();
        expect(secondResult, isNotNull);
        expect(fakeRepo.submitCallCount, 2);
      });
    });

    test('Error handling: repository error is caught and stored in state.error', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      fakeRepo.shouldThrowOnSubmitReturn = true;
      fakeRepo.submitErrorMessage = 'Odoo JSON-RPC 503 Service Unavailable';

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(sampleOrder);
      notifier.setQuantity(473, 1.0);
      notifier.setPaymentMethod(1);

      final result = await notifier.submitReturn();
      expect(result, isNull);

      final state = container.read(returnOrderProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, isNot(contains('Odoo')));
      expect(state.error, isNot(contains('503')));
      expect(state.completedRefundOrder, isNull);

      // Receipt provider was NOT updated
      expect(container.read(lastCompletedOrderProvider), isNull);
    });

    test('ReturnOrderState copyWith, reset, and value equality', () {
      final state1 = ReturnOrderState(
        originalOrder: sampleOrder,
        selectedQuantities: const {473: 1.0},
        paymentMethodId: 1,
        isSubmitting: false,
        error: null,
      );

      final state2 = state1.copyWith();
      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      final state3 = state1.copyWith(
        paymentMethodId: 2,
        selectedQuantities: const {473: 2.0},
      );
      expect(state1 == state3, isFalse);
      expect(state3.paymentMethodId, 2);
      expect(state3.selectedQuantities[473], 2.0);

      // reset()
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(sampleOrder);
      notifier.setQuantity(473, 1.0);
      expect(container.read(returnOrderProvider).originalOrder, isNotNull);

      notifier.reset();
      expect(container.read(returnOrderProvider).originalOrder, isNull);
      expect(container.read(returnOrderProvider).selectedQuantities, isEmpty);
    });
  });
}
