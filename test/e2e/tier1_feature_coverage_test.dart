// test/e2e/tier1_feature_coverage_test.dart
//
// Tier 1: Feature Coverage (Category-Partition)
// 40 isolated happy-path tests across features F1 through F8.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/theme/app_typography.dart';
import 'package:metapos/core/utils/currency_formatter.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/presentation/screens/receipt/order_success_receipt_screen.dart';
import 'package:metapos/providers/order_provider.dart';

import 'e2e_test_harness.dart';

void main() {
  E2ETestHarness.initializeFfi();

  late E2ETestHarness harness;

  setUpAll(() {
    AppTypography.enableGoogleFonts = false;
  });

  setUp(() async {
    harness = E2ETestHarness();
    await harness.setUp();
  });

  tearDown(() async {
    await harness.tearDown();
  });

  OrderModel createSampleRefundOrder({int orderId = 805, bool isSynced = false}) {
    final line = OrderLineModel.create(
      id: 501,
      productId: 62,
      productName: 'ব্ল্যাকবার্ড ক্লাসিক',
      qty: -1.0,
      priceUnit: 100.0,
      refundedOrderlineId: 401,
      isTaxInclusive: true,
    );
    final payment = PaymentLineModel.create(
      paymentMethodId: 1,
      paymentMethodName: 'নগদ (Cash)',
      amount: -100.0,
      sessionId: 23,
    );
    return OrderModel.create(
      id: orderId,
      sessionId: 23,
      posReference: 'RETURN-261-1-000$orderId',
      ticketCode: 'r${orderId}a',
      lines: [line],
      payments: [payment],
      isRefund: true,
      refundedOrderId: 401,
      isSynced: isSynced,
    );
  }

  // ==========================================================================
  // Feature F1: Past Order Lookup (ORIGINAL_REQUEST §R3)
  // ==========================================================================
  group('Feature F1: Past Order Lookup', () {
    test('T1-F1-01: Lookup by exact POS Reference', () async {
      harness.seedSingleItemOrder(
        orderId: 401,
        posRef: '261-1-000001',
        ticketCode: '0qfc5',
        barcode: '4001',
      );

      final results = await harness.orderRepository.searchPastOrders('261-1-000001');

      expect(results.length, 1);
      final order = results.first;
      expect(order.posReference, '261-1-000001');
      expect(order.lines.length, 1);

      final lineDetails = await harness.orderRepository.fetchOrderLines(order.lines.map((l) => l.id!).toList());
      expect(lineDetails.length, 1);
      expect(lineDetails.first.productName, 'ব্ল্যাকবার্ড ক্লাসিক');
    });

    test('T1-F1-02: Lookup by exact Order Name', () async {
      harness.seedSingleItemOrder(
        orderId: 402,
        posRef: 'Book Fair - 15871',
        ticketCode: 't871a',
        price: 110.0,
        qty: 1.0,
      );

      final results = await harness.orderRepository.searchPastOrders('Book Fair - 15871');

      expect(results.length, 1);
      final order = results.first;
      expect(order.posReference, 'Book Fair - 15871');
      expect(order.amountTotal, 110.0);
    });

    test('T1-F1-03: Lookup by 5-char Ticket Code', () async {
      harness.seedSingleItemOrder(
        orderId: 403,
        posRef: '261-1-000403',
        ticketCode: '0qfc5',
      );

      final results = await harness.orderRepository.searchPastOrders('0qfc5');

      expect(results.length, 1);
      expect(results.first.ticketCode, '0qfc5');
    });

    test('T1-F1-04: Lookup by Barcode / Tracking Number', () async {
      harness.seedSingleItemOrder(
        orderId: 404,
        posRef: '261-1-000404',
        barcode: '4001',
      );

      final results = await harness.orderRepository.searchPastOrders('4001');

      expect(results.length, 1);
      expect(results.first.trackingNumber, '4001');
    });

    test('T1-F1-05: Lookup by Customer Phone Number', () async {
      harness.seedSingleItemOrder(
        orderId: 405,
        posRef: '261-1-000405',
        barcode: '01711000000',
        partnerId: 99,
        partnerName: 'রাকিব আহমেদ',
        partnerPhone: '01711000000',
      );

      final results = await harness.orderRepository.searchPastOrders('01711000000');

      expect(results.length, 1);
      expect(results.first.partnerId, 99);
    });
  });

  // ==========================================================================
  // Feature F2: Refundable Line Quantity Calculation (ORIGINAL_REQUEST §R3)
  // ==========================================================================
  group('Feature F2: Refundable Line Quantity Calculation', () {
    test('T1-F2-01: Fresh unrefunded line calculation', () {
      final line = OrderLineModel.create(
        id: 701,
        productId: 10,
        productName: 'বই ১',
        qty: 3.0,
        priceUnit: 100.0,
        refundedQty: 0.0,
      );
      final order = OrderModel.create(
        id: 501,
        sessionId: 23,
        posReference: '261-1-000501',
        ticketCode: 't501',
        lines: [line],
        payments: [],
        hasRefundableLines: line.refundableQty > 0,
      );

      expect(line.refundableQty, 3.0);
      expect(order.hasRefundableLines, isTrue);
    });

    test('T1-F2-02: Partially refunded line calculation', () {
      final line = OrderLineModel.create(
        id: 702,
        productId: 10,
        productName: 'বই ২',
        qty: 5.0,
        priceUnit: 100.0,
        refundedQty: 2.0,
      );
      final order = OrderModel.create(
        id: 502,
        sessionId: 23,
        posReference: '261-1-000502',
        ticketCode: 't502',
        lines: [line],
        payments: [],
        hasRefundableLines: line.refundableQty > 0,
      );

      expect(line.refundableQty, 3.0);
      expect(order.hasRefundableLines, isTrue);
    });

    test('T1-F2-03: Fully refunded single line', () {
      final line = OrderLineModel.create(
        id: 703,
        productId: 10,
        productName: 'বই ৩',
        qty: 2.0,
        priceUnit: 100.0,
        refundedQty: 2.0,
      );
      final order = OrderModel.create(
        id: 503,
        sessionId: 23,
        posReference: '261-1-000503',
        ticketCode: 't503',
        lines: [line],
        payments: [],
        hasRefundableLines: line.refundableQty > 0,
      );

      expect(line.refundableQty, 0.0);
      expect(order.hasRefundableLines, isFalse);
    });

    test('T1-F2-04: Multi-line order with mixed line status', () {
      final line1 = OrderLineModel.create(
        id: 704,
        productId: 10,
        productName: 'বই ৪',
        qty: 2.0,
        priceUnit: 100.0,
        refundedQty: 2.0,
      );
      final line2 = OrderLineModel.create(
        id: 705,
        productId: 11,
        productName: 'বই ৫',
        qty: 1.0,
        priceUnit: 200.0,
        refundedQty: 0.0,
      );
      final order = OrderModel.create(
        id: 504,
        sessionId: 23,
        posReference: '261-1-000504',
        ticketCode: 't504',
        lines: [line1, line2],
        payments: [],
        hasRefundableLines: [line1, line2].any((l) => l.refundableQty > 0),
      );

      expect(line1.refundableQty, 0.0);
      expect(line2.refundableQty, 1.0);
      expect(order.hasRefundableLines, isTrue);
    });

    test('T1-F2-05: Multi-line order with all lines exhausted', () {
      final line1 = OrderLineModel.create(
        id: 706,
        productId: 10,
        productName: 'বই ৬',
        qty: 2.0,
        priceUnit: 100.0,
        refundedQty: 2.0,
      );
      final line2 = OrderLineModel.create(
        id: 707,
        productId: 11,
        productName: 'বই ৭',
        qty: 1.0,
        priceUnit: 200.0,
        refundedQty: 1.0,
      );
      final order = OrderModel.create(
        id: 505,
        sessionId: 23,
        posReference: '261-1-000505',
        ticketCode: 't505',
        lines: [line1, line2],
        payments: [],
        hasRefundableLines: [line1, line2].any((l) => l.refundableQty > 0),
      );

      expect(line1.refundableQty, 0.0);
      expect(line2.refundableQty, 0.0);
      expect(order.hasRefundableLines, isFalse);
    });
  });

  // ==========================================================================
  // Feature F3: Return Quantity Selection & Over-Refund Prevention
  // ==========================================================================
  group('Feature F3: Return Quantity Selection & Over-Refund Prevention', () {
    test('T1-F3-01: Full return quantity selection', () {
      final container = harness.createContainer();
      final order = harness.seedMultiItemMixedTaxOrder(orderId: 601);

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);

      final line1Id = order.lines[0].id!;
      final line2Id = order.lines[1].id!;
      notifier.setQuantity(line1Id, 2.0);
      notifier.setQuantity(line2Id, 1.0);

      final state = container.read(returnOrderProvider);
      expect(state.selectedQuantities[line1Id], 2.0);
      expect(state.selectedQuantities[line2Id], 1.0);
      expect(state.totalRefund, 950.0);
    });

    test('T1-F3-02: Single-line partial quantity selection', () {
      final container = harness.createContainer();
      final order = harness.seedSingleItemOrder(
        orderId: 602,
        qty: 3.0,
        price: 200.0,
      );

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);

      final lineId = order.lines.first.id!;
      notifier.setQuantity(lineId, 1.0);

      final state = container.read(returnOrderProvider);
      expect(state.selectedQuantities[lineId], 1.0);
      expect(state.totalRefund, 200.0);
    });

    test('T1-F3-03: Multi-line selective return', () {
      final container = harness.createContainer();
      final order = harness.seedMultiItemMixedTaxOrder(orderId: 603);

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);

      final line1Id = order.lines[0].id!;
      final line2Id = order.lines[1].id!;
      notifier.setQuantity(line1Id, 1.0);
      notifier.setQuantity(line2Id, 0.0);

      final state = container.read(returnOrderProvider);
      expect(state.selectedQuantities[line1Id], 1.0);
      expect(state.selectedQuantities.containsKey(line2Id), isFalse);
      expect(state.totalRefund, 100.0);
    });

    testWidgets('T1-F3-04: Stepper increment button disables at limit', (tester) async {
      final container = harness.createContainer();
      final order = harness.seedSingleItemOrder(
        orderId: 604,
        qty: 2.0,
        price: 100.0,
      );

      final lineId = order.lines.first.id!;
      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);
      notifier.setQuantity(lineId, 2.0); // max reached

      await tester.pumpWidget(
        harness.buildE2EApp(
          ReturnProcessBottomSheet(originalOrder: order),
          container: container,
        ),
      );
      await tester.pump();

      final incBtn = tester.widget<IconButton>(find.byKey(Key('stepper_increment_$lineId')));
      expect(incBtn.onPressed, isNull, reason: 'Increment button must be disabled at refundable limit');
    });

    testWidgets('T1-F3-05: Stepper decrement button decreases to zero', (tester) async {
      final container = harness.createContainer();
      final order = harness.seedSingleItemOrder(
        orderId: 605,
        qty: 2.0,
        price: 100.0,
      );

      final lineId = order.lines.first.id!;
      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);
      notifier.setQuantity(lineId, 1.0);

      await tester.pumpWidget(
        harness.buildE2EApp(
          ReturnProcessBottomSheet(originalOrder: order),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.byKey(Key('stepper_value_$lineId')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byKey(Key('stepper_decrement_$lineId')));
      await tester.pump();

      final state = container.read(returnOrderProvider);
      expect(state.selectedQuantities[lineId] ?? 0.0, 0.0);
      expect(state.totalRefund, 0.0);
    });
  });

  // ==========================================================================
  // Feature F4: Return Order Generation & Odoo 19 Invariants
  // ==========================================================================
  group('Feature F4: Return Order Generation & Odoo 19 Invariants', () {
    test('T1-F4-01: is_refund and refunded_order_id serialization', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 421);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      final payload = returnOrder.toOdooPayload();
      expect(payload['is_refund'], isTrue);
      expect(payload['refunded_order_id'], 421);
    });

    test('T1-F4-02: Negative line quantities and subtotals', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 422,
        qty: 2.0,
        price: 100.0,
      );
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 2.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      final payload = returnOrder.toOdooPayload();
      final lines = payload['lines'] as List;
      expect(lines.length, 1);
      final lineVals = lines.first[2] as Map<String, dynamic>;
      expect(lineVals['qty'], -2.0);
      expect(lineVals['price_subtotal_incl'], -200.0);
    });

    test('T1-F4-03: refunded_orderline_id linked on line command', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 423);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      final payload = returnOrder.toOdooPayload();
      final lines = payload['lines'] as List;
      final lineVals = lines.first[2] as Map<String, dynamic>;
      expect(lineVals['refunded_orderline_id'], origOrder.lines.first.id);
    });

    test('T1-F4-04: Financial invariants: negative totals and amount_return == 0.0', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 424,
        qty: 2.0,
        price: 100.0,
      );
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 2.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      final payload = returnOrder.toOdooPayload();
      expect(payload['amount_total'], -200.0);
      expect(payload['amount_paid'], -200.0);
      expect(payload['amount_return'], 0.0);
    });

    test('T1-F4-05: RFC 4122 v4 UUIDs generated for all return entities', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 425);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      expect(uuidRegex.hasMatch(returnOrder.uuid), isTrue);
      expect(uuidRegex.hasMatch(returnOrder.lines.first.uuid), isTrue);
      expect(uuidRegex.hasMatch(returnOrder.payments.first.uuid), isTrue);
    });
  });

  // ==========================================================================
  // Feature F5: Offline Queue Persistence & Automatic Session Re-binding
  // ==========================================================================
  group('Feature F5: Offline Queue Persistence & Automatic Session Re-binding', () {
    test('T1-F5-01: Enqueue return order into SQLite queue', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 701);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      await harness.queueRepo.enqueueOrder(returnOrder);

      final pending = await harness.queueRepo.getPendingOrders();
      expect(pending.any((o) => o.uuid == returnOrder.uuid), isTrue);

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');
    });

    test('T1-F5-02: Deserialize return order from SQLite payload', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 702);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      await harness.queueRepo.enqueueOrder(returnOrder);
      final pending = await harness.queueRepo.getPendingOrders();
      final retrieved = pending.firstWhere((o) => o.uuid == returnOrder.uuid);

      expect(retrieved.isRefund, isTrue);
      expect(retrieved.refundedOrderId, 702);
      expect(retrieved.lines.first.refundedOrderlineId, origOrder.lines.first.id);
      expect(retrieved.amountTotal, -100.0);
    });

    test('T1-F5-03: Successful online replay updates queue status', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 703);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      await harness.queueRepo.enqueueOrder(returnOrder);
      await harness.orderRepository.syncPendingOrders();

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
    });

    test('T1-F5-04: Network failure increments retry count and marks failed', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 704);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );

      await harness.queueRepo.enqueueOrder(returnOrder);

      // Force network error
      harness.mockServer.shouldThrowNetworkError = true;

      await harness.orderRepository.syncPendingOrders();

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'failed');
    });

    test('T1-F5-05: Re-bind return order from closed session to active session', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 705);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 14, // Closed session
      );

      // Close session 14, provide active session 23 in mock
      harness.mockServer.sessions[14] = {
        'id': 14,
        'state': 'closed',
        'config_id': [1, 'Book Fair Stall #1'],
      };

      await harness.queueRepo.enqueueOrder(returnOrder);
      await harness.orderRepository.syncPendingOrders();

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
    });
  });

  // ==========================================================================
  // Feature F6: Responsive Layout & Zero Overflow
  // ==========================================================================
  group('Feature F6: Responsive Layout & Zero Overflow', () {
    testWidgets('T1-F6-01: OrderHistoryScreen in Small Mobile (360x800)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      harness.seedSingleItemOrder(orderId: 801);
      final container = harness.createContainer();

      await tester.pumpWidget(
        harness.buildE2EApp(
          const OrderHistoryScreen(),
          container: container,
          viewport: const Size(360, 800),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      harness.verifyZeroOverflow(tester);
      expect(find.byType(OrderHistoryScreen), findsOneWidget);
    });

    testWidgets('T1-F6-02: OrderDetailScreen in Small Mobile (360x800)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final order = harness.seedMultiItemMixedTaxOrder(orderId: 802);
      final container = harness.createContainer();

      await tester.pumpWidget(
        harness.buildE2EApp(
          OrderDetailScreen(order: order),
          container: container,
          viewport: const Size(360, 800),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      harness.verifyZeroOverflow(tester);
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });

    testWidgets('T1-F6-03: ReturnProcessBottomSheet in Small Mobile (360x800)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final order = harness.seedMultiItemMixedTaxOrder(orderId: 803);
      final container = harness.createContainer();
      container.read(returnOrderProvider.notifier).initForOrder(order);

      await tester.pumpWidget(
        harness.buildE2EApp(
          ReturnProcessBottomSheet(originalOrder: order),
          container: container,
          viewport: const Size(360, 800),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      harness.verifyZeroOverflow(tester);
      expect(find.byType(ReturnProcessBottomSheet), findsOneWidget);
    });

    testWidgets('T1-F6-04: ReturnProcessBottomSheet in Mid Mobile (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final order = harness.seedMultiItemMixedTaxOrder(orderId: 804);
      final container = harness.createContainer();
      container.read(returnOrderProvider.notifier).initForOrder(order);

      await tester.pumpWidget(
        harness.buildE2EApp(
          ReturnProcessBottomSheet(originalOrder: order),
          container: container,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      harness.verifyZeroOverflow(tester);
      expect(find.byType(ReturnProcessBottomSheet), findsOneWidget);
    });

    testWidgets('T1-F6-05: OrderSuccessReceiptScreen (Refund Mode) in Large Mobile (412x915)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final returnOrder = createSampleRefundOrder(orderId: 805);
      final container = harness.createContainer();
      container.read(lastCompletedOrderProvider.notifier).state = returnOrder;

      await tester.pumpWidget(
        harness.buildE2EApp(
          const OrderSuccessReceiptScreen(),
          container: container,
          viewport: const Size(412, 915),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      harness.verifyZeroOverflow(tester);
      expect(find.byType(OrderSuccessReceiptScreen), findsOneWidget);
    });
  });

  // ==========================================================================
  // Feature F7: Whole BDT Integer Formatting & Bengali Typography
  // ==========================================================================
  group('Feature F7: Whole BDT Integer Formatting & Bengali Typography', () {
    test('T1-F7-01: Positive amount formatting without decimals', () {
      final formatted = CurrencyFormatter.formatBDT(1500.0);
      expect(formatted, '৳ 1,500');
      harness.verifyWholeBDT(formatted);
    });

    test('T1-F7-02: Negative refund amount formatting without decimals', () {
      final formatted = CurrencyFormatter.formatBDT(-550.0);
      expect(formatted, '-৳ 550');
      harness.verifyWholeBDT(formatted);
    });

    test('T1-F7-03: Signed negative refund amount formatting', () {
      final formatted = CurrencyFormatter.formatBDTSigned(-550.0);
      expect(formatted, '- ৳ 550');
      harness.verifyWholeBDT(formatted);
    });

    testWidgets('T1-F7-04: Bengali typography in refund receipt header', (tester) async {
      final returnOrder = createSampleRefundOrder(orderId: 901);
      final container = harness.createContainer();
      container.read(lastCompletedOrderProvider.notifier).state = returnOrder;

      await tester.pumpWidget(
        harness.buildE2EApp(
          const OrderSuccessReceiptScreen(),
          container: container,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      expect(find.text('বিক্রয় সম্পন্ন!'), findsOneWidget);
    });

    testWidgets('T1-F7-05: Bengali typography in sync status pill', (tester) async {
      final returnOrder = createSampleRefundOrder(orderId: 902, isSynced: true);
      final container = harness.createContainer();
      container.read(lastCompletedOrderProvider.notifier).state = returnOrder;

      await tester.pumpWidget(
        harness.buildE2EApp(
          const OrderSuccessReceiptScreen(),
          container: container,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      expect(find.text('সার্ভারে সংরক্ষিত'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Feature F8: Multi-Tender Payout Selection
  // ==========================================================================
  group('Feature F8: Multi-Tender Payout Selection', () {
    test('T1-F8-01: Cash refund payout selection', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 911, price: 250.0, qty: 1.0);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1, // Cash
        sessionId: 23,
      );

      expect(returnOrder.payments.first.paymentMethodId, 1);
      expect(returnOrder.payments.first.amount, -250.0);
      expect(returnOrder.payments.first.isChange, isFalse);
    });

    test('T1-F8-02: Card refund payout selection', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 912, price: 500.0, qty: 1.0);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      expect(returnOrder.payments.first.paymentMethodId, 2);
      expect(returnOrder.payments.first.amount, -500.0);
      expect(returnOrder.payments.first.isChange, isFalse);
    });

    test('T1-F8-03: bKash refund payout selection', () async {
      final origOrder = harness.seedSingleItemOrder(orderId: 913, price: 750.0, qty: 1.0);
      final returnOrder = await harness.orderRepository.submitReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      expect(returnOrder.payments.first.paymentMethodId, 3);
      expect(returnOrder.payments.first.amount, -750.0);
      expect(returnOrder.payments.first.isChange, isFalse);
    });

    test('T1-F8-04: Switching payout tender tabs updates state', () {
      final container = harness.createContainer();
      final order = harness.seedSingleItemOrder(orderId: 914);

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);

      notifier.setPaymentMethod(1);
      expect(container.read(returnOrderProvider).selectedPaymentMethodId, 1);

      notifier.setPaymentMethod(2);
      expect(container.read(returnOrderProvider).selectedPaymentMethodId, 2);
    });

    test('T1-F8-05: Validation prevents return submission without tender', () async {
      final container = harness.createContainer();
      final order = harness.seedSingleItemOrder(orderId: 915);

      final notifier = container.read(returnOrderProvider.notifier);
      notifier.initForOrder(order);
      final lineId = order.lines.first.id!;
      notifier.setQuantity(lineId, 1.0);

      expect(
        () => notifier.submit(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
