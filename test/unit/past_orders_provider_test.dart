import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/repositories/order_repository.dart';
import 'package:metapos/providers/past_orders_provider.dart';

/// Test mock implementation of [OrderRepository].
class FakeOrderRepository implements OrderRepository {
  List<OrderModel> mockOrders = [];
  String? lastSearchQuery;
  int? lastSearchLimit;
  bool shouldThrowError = false;
  String errorMessage = 'Failed to fetch past orders from server';

  @override
  Future<List<OrderModel>> searchPastOrders(String query, {int limit = 50}) async {
    lastSearchQuery = query;
    lastSearchLimit = limit;

    if (shouldThrowError) {
      throw Exception(errorMessage);
    }

    if (query.isEmpty) {
      return mockOrders;
    }

    return mockOrders.where((order) {
      final q = query.toLowerCase();
      final posRef = order.posReference.toLowerCase();
      final name = (order.name ?? '').toLowerCase();
      final ticket = order.ticketCode.toLowerCase();
      final tracking = order.trackingNumber.toLowerCase();
      return posRef.contains(q) ||
          name.contains(q) ||
          ticket.contains(q) ||
          tracking.contains(q);
    }).toList();
  }

  @override
  Future<OrderModel> submitOrder(
    OrderModel order, {
    required bool isOnline,
    required bool isOfflineMode,
    bool reverseNetTax = false,
  }) async {
    return order;
  }

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
    throw UnimplementedError();
  }
}

void main() {
  group('PastOrdersProvider Unit Tests', () {
    late FakeOrderRepository fakeRepository;

    // Sample orders representing different statuses
    late OrderModel standardOrder;
    late OrderModel fullyRefundedOrder;
    late OrderModel returnOrder;
    late OrderModel pendingOfflineOrder;

    setUp(() {
      fakeRepository = FakeOrderRepository();

      // 1. Standard sales order with remaining refundable quantity
      standardOrder = OrderModel.create(
        id: 101,
        sessionId: 23,
        posReference: '264-1-000101',
        ticketCode: 't101',
        trackingNumber: '4101',
        isSynced: true,
        hasRefundableLines: true,
        lines: [
          OrderLineModel.create(
            id: 501,
            productId: 10,
            productName: 'Flutter Book',
            qty: 2.0,
            priceUnit: 500.0,
            refundedQty: 0.0,
          ),
        ],
        payments: [],
      );

      // 2. Fully refunded sales order (refundableQty == 0)
      fullyRefundedOrder = OrderModel.create(
        id: 102,
        sessionId: 23,
        posReference: '264-1-000102',
        ticketCode: 't102',
        trackingNumber: '4102',
        isSynced: true,
        hasRefundableLines: false,
        lines: [
          OrderLineModel.create(
            id: 502,
            productId: 11,
            productName: 'Dart Guide',
            qty: 1.0,
            priceUnit: 400.0,
            refundedQty: 1.0, // Fully refunded
          ),
        ],
        payments: [],
      );

      // 3. Return / Refund order
      returnOrder = OrderModel.create(
        id: 103,
        sessionId: 23,
        posReference: 'RETURN-264-1-000101-abc',
        ticketCode: 't103',
        trackingNumber: '4103',
        isRefund: true,
        refundedOrderId: 101,
        hasRefundableLines: false,
        isSynced: true,
        lines: [
          OrderLineModel.create(
            id: 503,
            productId: 10,
            productName: 'Flutter Book',
            qty: -1.0,
            priceUnit: 500.0,
            refundedOrderlineId: 501,
          ),
        ],
        payments: [],
      );

      // 4. Pending / Offline order
      pendingOfflineOrder = OrderModel.create(
        id: null,
        sessionId: 23,
        posReference: '264-1-OFFLINE01',
        ticketCode: 't104',
        trackingNumber: '4104',
        isSynced: false, // Offline pending
        hasRefundableLines: true,
        lines: [
          OrderLineModel.create(
            id: 504,
            productId: 12,
            productName: 'Offline Novel',
            qty: 1.0,
            priceUnit: 300.0,
          ),
        ],
        payments: [],
      );

      fakeRepository.mockOrders = [
        standardOrder,
        fullyRefundedOrder,
        returnOrder,
        pendingOfflineOrder,
      ];
    });

    test('Initial state contains default values', () {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(pastOrdersProvider);
      expect(state.orders, isEmpty);
      expect(state.filteredOrders, isEmpty);
      expect(state.filter, PastOrdersFilter.all);
      expect(state.searchQuery, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('search() queries repository and populates orders and filteredOrders', () async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pastOrdersProvider.notifier);
      await notifier.search('101');

      final state = container.read(pastOrdersProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.searchQuery, '101');
      // Matches standardOrder and returnOrder (which has posReference containing 000101)
      expect(state.orders.length, 2);
      expect(state.filteredOrders.length, 2);
      expect(fakeRepository.lastSearchQuery, '101');
    });

    test('loadOrders() executes query with active searchQuery', () async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pastOrdersProvider.notifier);
      await notifier.loadOrders();

      final state = container.read(pastOrdersProvider);
      expect(state.orders.length, 4);
      expect(state.filteredOrders.length, 4);
      expect(fakeRepository.lastSearchQuery, '');
    });

    test('scanBarcode() delegates search to query by ticket or barcode', () async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pastOrdersProvider.notifier);
      await notifier.scanBarcode('t101');

      final state = container.read(pastOrdersProvider);
      expect(state.orders.length, 1);
      expect(state.orders.first.posReference, '264-1-000101');
      expect(fakeRepository.lastSearchQuery, 't101');
    });

    test('refresh() re-executes search with active search query', () async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pastOrdersProvider.notifier);
      await notifier.search('OFFLINE');
      expect(container.read(pastOrdersProvider).orders.length, 1);

      // Add another order to repository
      final newOrder = OrderModel.create(
        sessionId: 23,
        posReference: '264-1-OFFLINE02',
        ticketCode: 't105',
        trackingNumber: '4105',
        lines: [],
        payments: [],
      );
      fakeRepository.mockOrders.add(newOrder);

      await notifier.refresh();
      final refreshedState = container.read(pastOrdersProvider);
      expect(refreshedState.orders.length, 2);
      expect(fakeRepository.lastSearchQuery, 'OFFLINE');
    });

    group('PastOrdersFilter Filtering Modes', () {
      late ProviderContainer container;
      late PastOrdersNotifier notifier;

      setUp(() async {
        container = ProviderContainer(
          overrides: [
            orderRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        notifier = container.read(pastOrdersProvider.notifier);
        // Load all 4 orders
        await notifier.loadOrders();
      });

      tearDown(() {
        container.dispose();
      });

      test('Filter "all" includes every loaded order', () {
        notifier.setFilter(PastOrdersFilter.all);
        final state = container.read(pastOrdersProvider);
        expect(state.filter, PastOrdersFilter.all);
        expect(state.filteredOrders.length, 4);
      });

      test('Filter "refundable" includes only orders with remaining refundable items and excludes return orders', () {
        notifier.setFilter(PastOrdersFilter.refundable);
        final state = container.read(pastOrdersProvider);
        expect(state.filter, PastOrdersFilter.refundable);
        // standardOrder (has refundable line) and pendingOfflineOrder (has refundable line)
        expect(state.filteredOrders.length, 2);
        expect(
          state.filteredOrders.map((o) => o.posReference).toSet(),
          {'264-1-000101', '264-1-OFFLINE01'},
        );
        // Excludes fullyRefundedOrder and returnOrder
        expect(state.filteredOrders.any((o) => o.isRefund), isFalse);
        expect(state.filteredOrders.any((o) => o.id == 102), isFalse);
      });

      test('Filter "refunds" includes only return/refund orders', () {
        notifier.setFilter(PastOrdersFilter.refunds);
        final state = container.read(pastOrdersProvider);
        expect(state.filter, PastOrdersFilter.refunds);
        expect(state.filteredOrders.length, 1);
        expect(state.filteredOrders.first.isRefund, isTrue);
        expect(state.filteredOrders.first.posReference, contains('RETURN-'));
      });

      test('Filter "pending" includes only unsynced or draft/pending orders', () {
        notifier.setFilter(PastOrdersFilter.pending);
        final state = container.read(pastOrdersProvider);
        expect(state.filter, PastOrdersFilter.pending);
        expect(state.filteredOrders.length, 1);
        expect(state.filteredOrders.first.posReference, '264-1-OFFLINE01');
        expect(state.filteredOrders.first.isSynced, isFalse);
      });

      test('Client-side setFilter updates filteredOrders without re-fetching repository', () {
        fakeRepository.lastSearchQuery = null;
        notifier.setFilter(PastOrdersFilter.refunds);

        expect(fakeRepository.lastSearchQuery, isNull,
            reason: 'setFilter must operate on cached orders without repository calls');
        final state = container.read(pastOrdersProvider);
        expect(state.filteredOrders.length, 1);
        expect(state.filteredOrders.first.isRefund, isTrue);
      });
    });

    test('Error handling: repository failure captures error message and resets isLoading', () async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      fakeRepository.shouldThrowError = true;
      fakeRepository.errorMessage = 'Network connection timed out';

      final notifier = container.read(pastOrdersProvider.notifier);
      await notifier.search('test');

      final state = container.read(pastOrdersProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('ইন্টারনেট সংযোগে সমস্যা হচ্ছে'));
      expect(state.orders, isEmpty);
      expect(state.filteredOrders, isEmpty);
    });

    test('PastOrdersState copyWith and value equality', () {
      final state1 = PastOrdersState(
        orders: [standardOrder],
        filteredOrders: [standardOrder],
        filter: PastOrdersFilter.refundable,
        searchQuery: 'abc',
        isLoading: false,
        error: null,
      );

      final state2 = state1.copyWith();
      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      final state3 = state1.copyWith(
        filter: PastOrdersFilter.refunds,
        searchQuery: 'xyz',
      );
      expect(state1 == state3, isFalse);
      expect(state3.filter, PastOrdersFilter.refunds);
      expect(state3.searchQuery, 'xyz');

      // Clear error test
      final errorState = state1.copyWith(error: 'Some error');
      expect(errorState.error, 'Some error');
      final clearedState = errorState.copyWith(clearError: true);
      expect(clearedState.error, isNull);
    });
  });
}
