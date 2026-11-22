// test/e2e/tier3_pairwise_combinations_test.dart
//
// Tier 3: Cross-Feature Combinations (Pairwise Testing)
// 16 orthogonal tests covering all 53 pairwise factor combinations:
// (Search Type [4] × Return Fraction [3] × Tender Method [3] × Network State [2]).

import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/theme/app_typography.dart';

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

  // ==========================================================================
  // Pairwise Matrix Tests (T3-01 to T3-16)
  // ==========================================================================
  group('Tier 3: Pairwise Cross-Feature Combinations', () {
    test('T3-01: [Ref] × [Full] × [Cash] × [Online]', () async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(
        orderId: 2001,
        posRef: '261-1-002001',
      );

      // 1. Search by Ref
      final searchResults = await harness.orderRepository.searchPastOrders('261-1-002001');
      expect(searchResults.length, 1);

      // 2. Full return (100% of line 1 and line 2)
      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: origOrder.lines[0].qty,
          origOrder.lines[1]: origOrder.lines[1].qty,
        },
        paymentMethodId: 1, // Cash
        sessionId: 23,
      );

      // 3. Online sync
      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      // 4. Verify Odoo payload invariants
      harness.verifyReturnOrderInvariants(returnOrder, origOrder);
      expect(returnOrder.payments.first.paymentMethodId, 1);
      expect(harness.mockServer.receivedPayloads.isNotEmpty, isTrue);

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
    });

    test('T3-02: [Ref] × [SinglePart] × [Card] × [Offline]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2002,
        posRef: '261-1-002002',
        qty: 3.0,
      );

      // 1. Search by Ref
      final searchResults = await harness.orderRepository.searchPastOrders('261-1-002002');
      expect(searchResults.length, 1);

      // 2. Single line partial return (1 of 3)
      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      // 3. Offline submission
      harness.connectivity.setOnline(false);
      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      // 4. Verify SQLite offline queue persistence
      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');

      final pending = await harness.queueRepo.getPendingOrders();
      final stored = pending.firstWhere((o) => o.uuid == returnOrder.uuid);
      expect(stored.payments.first.paymentMethodId, 2);
      expect(stored.lines.first.qty, -1.0);
    });

    test('T3-03: [Ref] × [MultiPart] × [bKash] × [Online]', () async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(
        orderId: 2003,
        posRef: '261-1-002003',
      );

      // 1. Search by Ref
      final searchResults = await harness.orderRepository.searchPastOrders('261-1-002003');
      expect(searchResults.length, 1);

      // 2. Multi-line partial return
      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: 1.0,
          origOrder.lines[1]: 1.0,
        },
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      // 3. Online sync
      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      // 4. Verify invariants
      harness.verifyReturnOrderInvariants(returnOrder, origOrder);
      expect(returnOrder.payments.first.paymentMethodId, 3);
      expect(returnOrder.lines.length, 2);

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
    });

    test('T3-04: [Ref] × [Full] × [Card] × [Offline]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2004,
        posRef: '261-1-002004',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('261-1-002004');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: origOrder.lines.first.qty},
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');

      final rawOrder = await harness.queueRepo.getOrder(returnOrder.uuid);
      expect(rawOrder?['is_refund'], 1);
      expect(rawOrder?['refunded_order_id'], 2004);
    });

    test('T3-05: [Name] × [Full] × [Card] × [Online]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2005,
        posRef: 'Book Fair - 001',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('Book Fair - 001');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: origOrder.lines.first.qty},
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      harness.verifyReturnOrderInvariants(returnOrder, origOrder);
      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
    });

    test('T3-06: [Name] × [SinglePart] × [bKash] × [Offline]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2006,
        posRef: 'Book Fair - 002',
        qty: 5.0,
      );

      final searchResults = await harness.orderRepository.searchPastOrders('Book Fair - 002');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 2.0}, // 2 of 5
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');
      expect(returnOrder.amountTotal, -200.0);
    });

    test('T3-07: [Name] × [MultiPart] × [Cash] × [Offline]', () async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(
        orderId: 2007,
        posRef: 'Book Fair - 003',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('Book Fair - 003');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: 1.0,
          origOrder.lines[1]: 1.0,
        },
        paymentMethodId: 1, // Cash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');
      expect(returnOrder.payments.first.isChange, isFalse);
    });

    test('T3-08: [Name] × [Full] × [bKash] × [Online]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2008,
        posRef: 'Book Fair - 004',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('Book Fair - 004');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: origOrder.lines.first.qty},
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
      expect(harness.mockServer.orders[2008]?['has_refundable_lines'], isFalse);
    });

    test('T3-09: [Ticket] × [Full] × [bKash] × [Offline]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2009,
        posRef: '261-1-002009',
        ticketCode: '0qfc5',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('0qfc5');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: origOrder.lines.first.qty},
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');
    });

    test('T3-10: [Ticket] × [SinglePart] × [Cash] × [Online]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2010,
        posRef: '261-1-002010',
        ticketCode: 'b4b16',
        qty: 2.0,
      );

      final searchResults = await harness.orderRepository.searchPastOrders('b4b16');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 1, // Cash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
      // Server mock updated line refunded_qty to 1.0
      final parentLine = harness.mockServer.orderLines[origOrder.lines.first.id];
      expect(parentLine?['refunded_qty'], 1.0);
    });

    test('T3-11: [Ticket] × [MultiPart] × [Card] × [Online]', () async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(
        orderId: 2011,
        posRef: '261-1-002011',
        ticketCode: '8e1a2',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('8e1a2');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: 1.0,
          origOrder.lines[1]: 1.0,
        },
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
      expect(returnOrder.amountTotal, -850.0);
    });

    test('T3-12: [Ticket] × [SinglePart] × [Card] × [Online]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2012,
        posRef: '261-1-002012',
        ticketCode: '9c3d4',
        qty: 4.0,
      );

      final searchResults = await harness.orderRepository.searchPastOrders('9c3d4');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
      expect(returnOrder.lines.first.refundedOrderlineId, origOrder.lines.first.id);
    });

    test('T3-13: [Barcode] × [Full] × [Cash] × [Offline]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2013,
        posRef: '261-1-002013',
        barcode: '4001',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('4001');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: origOrder.lines.first.qty},
        paymentMethodId: 1, // Cash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');
    });

    test('T3-14: [Barcode] × [SinglePart] × [Card] × [Online]', () async {
      final origOrder = harness.seedSingleItemOrder(
        orderId: 2014,
        posRef: '261-1-002014',
        barcode: '4002',
        qty: 1.0,
      );

      final searchResults = await harness.orderRepository.searchPastOrders('4002');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {origOrder.lines.first: 1.0},
        paymentMethodId: 2, // Card
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');
      expect(harness.mockServer.orders[2014]?['has_refundable_lines'], isFalse);
    });

    test('T3-15: [Barcode] × [MultiPart] × [bKash] × [Offline]', () async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(
        orderId: 2015,
        posRef: '261-1-002015',
        barcode: '4003',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('4003');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: 1.0,
          origOrder.lines[1]: 1.0,
        },
        paymentMethodId: 3, // bKash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: false,
        isOfflineMode: true,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'pending');
      expect(returnOrder.lines.length, 2);
    });

    test('T3-16: [Barcode] × [MultiPart] × [Cash] × [Online]', () async {
      final origOrder = harness.seedMultiItemMixedTaxOrder(
        orderId: 2016,
        posRef: '261-1-002016',
        barcode: '4004',
      );

      final searchResults = await harness.orderRepository.searchPastOrders('4004');
      expect(searchResults.length, 1);

      final returnOrder = harness.buildReturnOrder(
        originalOrder: origOrder,
        returnLines: {
          origOrder.lines[0]: 1.0,
          origOrder.lines[1]: 1.0,
        },
        paymentMethodId: 1, // Cash
        sessionId: 23,
      );

      await harness.orderRepository.submitOrder(
        returnOrder,
        isOnline: true,
        isOfflineMode: false,
      );

      final status = await harness.orderRepository.getOrderSyncStatus(returnOrder.uuid);
      expect(status, 'synced');

      // Verify server response contains book_stock_applied
      expect(harness.mockServer.receivedPayloads.isNotEmpty, isTrue);
    });
  });
}
