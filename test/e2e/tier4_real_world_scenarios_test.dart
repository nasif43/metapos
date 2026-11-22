// test/e2e/tier4_real_world_scenarios_test.dart
//
// Tier 4: Real-World Scenarios (End-to-End Workloads)
// 6 comprehensive scenarios executing multi-step customer journeys mimicking
// live retail operations during peak bookstore and book fair hours (S1 through S6).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/theme/app_typography.dart';
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

  group('Tier 4: Real-World Scenarios (End-to-End Workloads)', () {
    // ========================================================================
    // Scenario S1: Full Cash Return Flow
    // (Barcode Scan -> Cash Payout -> Sync -> Receipt)
    // ========================================================================
    testWidgets(
      'Scenario S1: Full Cash Return Flow (Barcode Scan -> Cash Payout -> Sync -> Receipt)',
      (tester) async {
        // 1. Order Creation & Precondition
        final line1 = OrderLineModel.create(
          id: 601,
          productId: 62,
          productName: 'ব্ল্যাকবার্ড ক্লাসিক',
          qty: 2.0,
          priceUnit: 100.0,
          taxIds: [1],
          isTaxInclusive: true,
        );
        final line2 = OrderLineModel.create(
          id: 602,
          productId: 242,
          productName: 'ক্রিসমাস অ্যাট হগওয়ার্টস',
          qty: 1.0,
          priceUnit: 750.0,
          taxIds: [],
          taxRate: 0.0,
          isTaxInclusive: true,
        );
        final payment = PaymentLineModel.create(
          paymentMethodId: 1,
          paymentMethodName: 'নগদ (Cash)',
          amount: 950.0,
          sessionId: 23,
        );
        final origOrder = harness.mockServer.seedOriginalOrder(
          orderId: 1001,
          posReference: 'Order - 000001',
          ticketCode: 't1001',
          barcode: '4001',
          sessionId: 23,
          lines: [line1, line2],
          payments: [payment],
        );

        // 2. Scan & Lookup via UI
        final container = harness.createContainer();
        await tester.pumpWidget(harness.buildE2EApp(const OrderHistoryScreen(), container: container));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Barcode Scanner button
        final barcodeBtn = find.byKey(const Key('barcode_scanner_button'));
        expect(barcodeBtn, findsOneWidget);
        await tester.tap(barcodeBtn);
        await tester.runAsync(() async {
          await container.read(pastOrdersProvider.notifier).scanBarcode('4001');
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // UI displays Order - 000001 in results list
        expect(find.text('Order - 000001'), findsOneWidget);

        // 3. Order Inspection via Model & Detail Screen
        final searchResults = await tester.runAsync(() async => await harness.orderRepository.searchPastOrders('4001'));
        expect(searchResults!.length, 1);
        final foundOrder = searchResults.first;
        final lines = await tester.runAsync(
          () async => await harness.orderRepository.fetchOrderLines(
            foundOrder.lines.map((l) => l.id!).toList(),
          ),
        );
        final inspectedOrder = foundOrder.copyWith(lines: lines);
        expect(inspectedOrder.lines[0].refundableQty, 2.0);
        expect(inspectedOrder.lines[1].refundableQty, 1.0);
        expect(inspectedOrder.amountTotal, 950.0);

        // 4. Return Order Generation (Full Return: 2 of Line 1, 1 of Line 2)
        final returnOrder = harness.buildReturnOrder(
          originalOrder: origOrder,
          returnLines: {
            origOrder.lines[0]: 2.0,
            origOrder.lines[1]: 1.0,
          },
          paymentMethodId: 1, // Cash
          sessionId: 23,
        );

        // Verify invariants
        harness.verifyReturnOrderInvariants(returnOrder, origOrder);
        expect(returnOrder.amountTotal, -950.0);
        expect(returnOrder.amountPaid, -950.0);
        expect(returnOrder.amountReturn, 0.0);

        // 5. Submit Order Online
        await tester.runAsync(() async {
          await harness.orderRepository.submitOrder(
            returnOrder,
            isOnline: true,
            isOfflineMode: false,
          );
        });
        final status = await tester.runAsync(() async => await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid));
        expect(status, 'synced');

        // 6. Receipt Verification
        container.read(lastCompletedOrderProvider.notifier).state = returnOrder;
        await tester.pumpWidget(harness.buildE2EApp(const OrderSuccessReceiptScreen(), container: container));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('বিক্রয় সম্পন্ন!'), findsOneWidget);
        expect(find.text('-৳ 950'), findsAtLeastNWidgets(1));
        harness.verifyZeroOverflow(tester);
      },
    );

    // ========================================================================
    // Scenario S2: Multi-Stage Partial Returns
    // (Day 1 -> Day 2 -> Over-refund Blocked)
    // ========================================================================
    test('Scenario S2: Multi-Stage Partial Returns (Day 1 -> Day 2 -> Over-refund Blocked)', () async {
      // 1. Precondition: Order #500 created with 1 line item: 3 copies of "হিমু সমগ্র" @ ৳300 = ৳900.
      final line = OrderLineModel.create(
        id: 701,
        productId: 301,
        productName: 'হিমু সমগ্র',
        qty: 3.0,
        priceUnit: 300.0,
        isTaxInclusive: true,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 3, // bKash
        paymentMethodName: 'বিকাশ (bKash)',
        amount: 900.0,
        sessionId: 23,
      );
      final origOrder = harness.mockServer.seedOriginalOrder(
        orderId: 500,
        posReference: '261-1-000500',
        ticketCode: 'h500a',
        barcode: '5001',
        sessionId: 23,
        lines: [line],
        payments: [payment],
      );

      // 2. Day 1 Partial Return: Customer returns 1 copy (qty: 1.0)
      final day1Return = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );
      await harness.orderRepository.submitOrder(
        day1Return,
        isOnline: true,
        isOfflineMode: false,
      );
      final status1 = await harness.orderRepository.getOrderSyncStatus(day1Return.uuid);
      expect(status1, 'synced');

      // Verify server line 701 updated: refunded_qty = 1.0, order has_refundable_lines remains true
      expect(harness.mockServer.orderLines[701]?['refunded_qty'], 1.0);
      expect(harness.mockServer.orders[500]?['has_refundable_lines'], isTrue);

      // 3. Day 2 Second Partial Return: Customer returns a 2nd copy (qty: 1.0)
      final day2Return = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );
      await harness.orderRepository.submitOrder(
        day2Return,
        isOnline: true,
        isOfflineMode: false,
      );
      final status2 = await harness.orderRepository.getOrderSyncStatus(day2Return.uuid);
      expect(status2, 'synced');

      expect(harness.mockServer.orderLines[701]?['refunded_qty'], 2.0);
      expect(harness.mockServer.orders[500]?['has_refundable_lines'], isTrue);

      // 4. Day 3 Over-Refund Prevention:
      // Only 1 copy remaining. Attempting to refund 2 copies must be rejected by mock Odoo server!
      final overRefundAttempt = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 2.0},
        paymentMethodId: 3,
        sessionId: 23,
      );
      await harness.orderRepository.submitOrder(
        overRefundAttempt,
        isOnline: true,
        isOfflineMode: false,
      );
      final overRefundStatus = await harness.orderRepository.getOrderSyncStatus(overRefundAttempt.uuid);
      expect(overRefundStatus, 'failed'); // Rejected due to Over-refund attempt on line 701!

      // Now submit the valid remaining 1 copy
      final day3FinalReturn = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 3,
        sessionId: 23,
      );
      await harness.orderRepository.submitOrder(
        day3FinalReturn,
        isOnline: true,
        isOfflineMode: false,
      );
      final status3 = await harness.orderRepository.getOrderSyncStatus(day3FinalReturn.uuid);
      expect(status3, 'synced');

      // Line 701 fully exhausted: refunded_qty = 3.0, has_refundable_lines = false
      expect(harness.mockServer.orderLines[701]?['refunded_qty'], 3.0);
      expect(harness.mockServer.orders[500]?['has_refundable_lines'], isFalse);
    });

    // ========================================================================
    // Scenario S3: Offline Store Outage Return
    // (Network Drop -> Offline Queue -> Restored Sync)
    // ========================================================================
    testWidgets(
      'Scenario S3: Offline Store Outage Return (Network Drop -> Offline Queue -> Restored Sync)',
      (tester) async {
        // 1. Precondition: Order seeded in local SQLite queue
        final origOrder = harness.seedSingleItemOrder(
          orderId: 301,
          posRef: '261-1-000301',
          price: 250.0,
          qty: 2.0,
        );
        await tester.runAsync(() async => await harness.queueRepo.enqueueOrder(origOrder));

        // Network fails: connectivity is false
        harness.connectivity.setOnline(false);

        // 2. Local Lookup: Query past orders
        final searchResults = await tester.runAsync(() async => await harness.orderRepository.searchPastOrders('261-1-000301'));
        expect(searchResults!.any((o) => o.posReference == '261-1-000301'), isTrue);

        // 3. Process Offline Return: 1 item, Card payout (2)
        final returnOrder = harness.buildReturnOrder(
          originalOrder: origOrder,
          returnLines: {origOrder.lines.first: 1.0},
          paymentMethodId: 2, // Card
          sessionId: 23,
        );

        // 4. Offline Enqueue
        await tester.runAsync(() async {
          await harness.orderRepository.submitOrder(
            returnOrder,
            isOnline: false,
            isOfflineMode: true,
          );
        });

        final status = await tester.runAsync(() async => await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid));
        expect(status, 'pending');

        final storedRow = await tester.runAsync(() async => await harness.queueRepo.getOrder(returnOrder.uuid));
        expect(storedRow?['sync_status'], 'pending');
        expect(storedRow?['is_refund'], 1);
        expect(storedRow?['refunded_order_id'], 301);

        // 5. UI Offline Indication on Receipt Screen
        final container = harness.createContainer();
        container.read(lastCompletedOrderProvider.notifier).state = returnOrder;
        await tester.pumpWidget(harness.buildE2EApp(const OrderSuccessReceiptScreen(), container: container));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('অফলাইনে জমা হয়েছে'), findsOneWidget);
        harness.verifyZeroOverflow(tester);

        // 6. Network Restoration & Queue Flush
        harness.connectivity.setOnline(true);
        await tester.runAsync(() async {
          await harness.orderRepository.syncPendingOrders();
        });

        // 7. Verify sync success in SQLite and remote server
        final syncedStatus = await tester.runAsync(() async => await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid));
        expect(syncedStatus, 'synced');
        expect(harness.mockServer.receivedPayloads.any((p) => p['uuid'] == returnOrder.uuid), isTrue);
      },
    );

    // ========================================================================
    // Scenario S4: Expired Session Return Re-binding
    // (Closed Session #19 -> Active Session #23)
    // ========================================================================
    test('Scenario S4: Expired Session Return Re-binding (Closed Session #19 -> Active Session #23)', () async {
      // 1. Precondition: Closed session #19, active session #23
      harness.mockServer.sessions[19] = {
        'id': 19,
        'name': 'Book Fair/00019',
        'state': 'closed',
        'config_id': [1, 'Book Fair Stall #1'],
      };
      harness.mockServer.configs[1] = {
        'id': 1,
        'name': 'Book Fair Stall #1',
        'current_session_id': [23, 'Book Fair/00023'],
        'current_session_state': 'opened',
        'payment_method_ids': [1, 2, 3],
      };
      harness.mockServer.sessions[23] = {
        'id': 23,
        'name': 'Book Fair/00023',
        'state': 'opened',
        'config_id': [1, 'Book Fair Stall #1'],
      };

      // Original order created in closed session #19
      final origOrder = harness.seedSingleItemOrder(
        orderId: 419,
        posRef: '261-1-000019',
      );

      // 2. Return created with old session 19
      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1, // Cash
        sessionId: 19, // Closed session
      );

      // 3. Submit order: OrderRepositoryImpl._attemptSessionRebind automatically detects closed session
      // and rebinds to active session #23!
      final submittedOrder = await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      // 4. Verify server acceptance and remapped session
      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
      expect(submittedOrder.isSynced, isTrue);

      final received = harness.mockServer.receivedPayloads.lastWhere((p) => p['uuid'] == returnOrder.uuid);
      expect(received['session_id'], 23);
      expect(received['is_refund'], isTrue);
      expect(received['refunded_order_id'], 419);
    });

    // ========================================================================
    // Scenario S5: Multi-Item Selective Return with Mixed Taxes
    // ========================================================================
    test('Scenario S5: Multi-Item Selective Return with Mixed Taxes', () async {
      // 1. Precondition: 3 items with different tax treatments
      // Line 1: Book A (qty: 2.0, priceUnit: 200.0, MRP-inclusive 10% VAT). Total: ৳400.
      final line1 = OrderLineModel.create(
        id: 801,
        productId: 701,
        productName: 'বই ক (Book A)',
        qty: 2.0,
        priceUnit: 200.0,
        taxIds: [1],
        taxRate: 0.10,
        isTaxInclusive: true,
      );
      // Line 2: Book B (qty: 1.0, priceUnit: 300.0, 0% VAT exempt). Total: ৳300.
      final line2 = OrderLineModel.create(
        id: 802,
        productId: 702,
        productName: 'বই খ (Book B)',
        qty: 1.0,
        priceUnit: 300.0,
        taxIds: [],
        taxRate: 0.0,
        isTaxInclusive: true,
      );
      // Line 3: Notebook C (qty: 4.0, priceUnit: 50.0, additive 15% VAT). Total: ৳230 (Base ৳200 + Tax ৳30).
      final line3 = OrderLineModel.create(
        id: 803,
        productId: 703,
        productName: 'খাতা গ (Notebook C)',
        qty: 4.0,
        priceUnit: 50.0,
        taxIds: [2],
        taxRate: 0.15,
        isTaxInclusive: false,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 3, // bKash
        paymentMethodName: 'বিকাশ (bKash)',
        amount: 930.0,
        sessionId: 23,
      );
      final origOrder = harness.mockServer.seedOriginalOrder(
        orderId: 800,
        posReference: '261-1-000800',
        ticketCode: 'm800x',
        barcode: '8001',
        sessionId: 23,
        lines: [line1, line2, line3],
        payments: [payment],
      );

      // 2. Selective Return: 1 copy of Line 1, 0 of Line 2, 2 of Line 3
      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: 1.0, // 1 of Book A (৳200 gross)
          origOrder.lines[2]: 2.0, // 2 of Notebook C (৳115 gross)
        },
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      // 3. Proportional calculations & totals verification
      expect(returnOrder.lines.length, 2);
      // Line 1 returned: qty -1.0, priceSubtotalIncl -200.0, priceSubtotal -181.82
      final retLine1 = returnOrder.lines.firstWhere((l) => l.productId == 701);
      expect(retLine1.qty, -1.0);
      expect(retLine1.priceSubtotalIncl, -200.0);
      expect(retLine1.priceSubtotal, -181.82);

      // Line 3 returned: qty -2.0, priceSubtotalIncl -115.0, priceSubtotal -100.0
      final retLine3 = returnOrder.lines.firstWhere((l) => l.productId == 703);
      expect(retLine3.qty, -2.0);
      expect(retLine3.priceSubtotalIncl, -115.0);
      expect(retLine3.priceSubtotal, -100.0);

      // Total refund: -(200 + 115) = -315.0
      expect(returnOrder.amountTotal, -315.0);
      expect(returnOrder.amountPaid, -315.0);
      expect(returnOrder.amountReturn, 0.0);
      expect(returnOrder.amountTax, -33.18);

      // 4. Online submission & Odoo 19 sync
      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );
      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');

      final odooPayload = returnOrder.toOdooPayload();
      expect(odooPayload['amount_total'], -315.0);
      expect(odooPayload['amount_paid'], -315.0);
      expect(odooPayload['amount_return'], 0.0);
      expect(odooPayload['is_refund'], isTrue);
    });

    // ========================================================================
    // Scenario S6: Small Screen Mobile Responsiveness
    // (360x800 Full Journey)
    // ========================================================================
    testWidgets('Scenario S6: Small Screen Mobile Responsiveness (360x800 Full Journey)', (tester) async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(orderId: 601, posRef: '261-1-000601');
      final container = harness.createContainer();

      // 1. Configure Small Mobile Viewport (360x800)
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 2. Render OrderHistoryScreen with 0 RenderFlex overflow
      await tester.pumpWidget(harness.buildE2EApp(
        const OrderHistoryScreen(),
        container: container,
        viewport: const Size(360, 800),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('order_search_field')), findsOneWidget);
      harness.verifyZeroOverflow(tester);

      // 3. Render OrderDetailScreen with 0 overflow
      await tester.pumpWidget(harness.buildE2EApp(
        OrderDetailScreen(order: origOrder),
        container: container,
        viewport: const Size(360, 800),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('process_return_button')), findsOneWidget);
      harness.verifyZeroOverflow(tester);

      // 4. Open ReturnProcessBottomSheet with 0 overflow
      container.read(returnOrderProvider.notifier).initForOrder(origOrder);
      await tester.pumpWidget(harness.buildE2EApp(
        Scaffold(
          body: ReturnProcessBottomSheet(originalOrder: origOrder),
        ),
        container: container,
        viewport: const Size(360, 800),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('confirm_refund_button')), findsOneWidget);
      harness.verifyZeroOverflow(tester);

      // 5. Interact with Steppers & Tender Tabs with 0 overflow
      final incBtn = find.byKey(Key('stepper_increment_${origOrder.lines.first.id}'));
      if (incBtn.evaluate().isNotEmpty) {
        await tester.tap(incBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      harness.verifyZeroOverflow(tester);

      // 6. Render OrderSuccessReceiptScreen (Refund Mode) with 0 overflow
      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
      );
      container.read(lastCompletedOrderProvider.notifier).state = returnOrder;
      await tester.pumpWidget(harness.buildE2EApp(
        const OrderSuccessReceiptScreen(),
        container: container,
        viewport: const Size(360, 800),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('বিক্রয় সম্পন্ন!'), findsOneWidget);
      harness.verifyZeroOverflow(tester);
    });
  });
}
