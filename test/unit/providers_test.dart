import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/models/partner_model.dart';
import 'package:metapos/data/models/product_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/providers/auth_provider.dart';
import 'package:metapos/providers/cart_provider.dart';
import 'package:metapos/providers/catalog_provider.dart';
import 'package:metapos/providers/payment_provider.dart';
import 'package:metapos/providers/session_provider.dart';
import 'package:metapos/providers/sync_queue_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late OfflineQueueRepository queueRepo;

  setUp(() async {
    dbHelper = DatabaseHelper(customDbPath: inMemoryDatabasePath);
    queueRepo = OfflineQueueRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Riverpod Providers Unit Tests', () {
    test('CartProvider: adding items and discounts recalculates MRP-inclusive totals correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);

      const product1 = ProductModel(
        id: 62,
        name: 'Blackbrid Classic',
        displayName: 'Blackbrid Classic',
        listPrice: 500.0,
      );

      const product2 = ProductModel(
        id: 63,
        name: 'Ekattorer Dinguli',
        displayName: 'Ekattorer Dinguli',
        listPrice: 300.0,
      );

      // Add items
      cartNotifier.addItem(product1, 2.0); // 1000.0
      cartNotifier.addItem(product2, 1.0); // 300.0

      var state = container.read(cartProvider);
      expect(state.items.length, 2);
      expect(state.totalItemsCount, 3);
      expect(state.grandTotal, 1300.0);
      expect(state.subtotal, closeTo(1181.82, 0.01));
      expect(state.taxAmount, closeTo(118.18, 0.01));

      // Apply 10% global discount across all items
      cartNotifier.setDiscount(10.0);
      state = container.read(cartProvider);
      // 1300 * 0.90 = 1170.0
      expect(state.grandTotal, 1170.0);
      expect(state.grossSubtotal, 1300.0);
      expect(state.totalDiscountAmount, 130.0);
      expect(state.discountPercent, 10.0);

      // Customer assignment
      const customer = PartnerModel(id: 9, name: 'Anik Rahman');
      cartNotifier.setCustomer(customer);
      state = container.read(cartProvider);
      expect(state.customer?.name, 'Anik Rahman');

      // Clear cart
      cartNotifier.clearCart();
      state = container.read(cartProvider);
      expect(state.items.isEmpty, isTrue);
      expect(state.grandTotal, 0.0);
    });

    test('CartProvider: independent line-item discounts and global order discounts adhere to Odoo rules', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);

      const book1 = ProductModel(
        id: 62,
        name: 'Blackbird Classic',
        displayName: 'Blackbird Classic',
        listPrice: 100.0,
      );

      const book2 = ProductModel(
        id: 249,
        name: 'A Life in Fifty Books',
        displayName: 'A Life in Fifty Books',
        listPrice: 1500.0,
      );

      // Add 2 copies of book1 (200.0) and 1 copy of book2 (1500.0)
      cartNotifier.addItem(book1, 2.0);
      cartNotifier.addItem(book2, 1.0);

      var state = container.read(cartProvider);
      expect(state.grossSubtotal, 1700.0);
      expect(state.grandTotal, 1700.0);
      expect(state.totalDiscountAmount, 0.0);

      // 1. Set line-item discount on book1 only (20% discount on book1)
      cartNotifier.setLineDiscount(62, 20.0);
      state = container.read(cartProvider);
      final item1 = state.items.firstWhere((i) => i.product.id == 62);
      final item2 = state.items.firstWhere((i) => i.product.id == 249);

      expect(item1.discount, 20.0);
      expect(item1.hasCustomDiscount, isTrue);
      expect(item1.lineGross, 200.0);
      expect(item1.lineDiscountAmount, 40.0);
      expect(item1.lineNetTotal, 160.0);

      expect(item2.discount, 0.0);
      expect(item2.lineGross, 1500.0);
      expect(item2.lineNetTotal, 1500.0);

      // Total payable = 160 + 1500 = 1660.0
      expect(state.grandTotal, 1660.0);
      expect(state.totalDiscountAmount, 40.0);

      // 2. Set global order discount (10% Boi Mela Fair Discount)
      cartNotifier.setGlobalDiscount(10.0, applyToAll: true);
      state = container.read(cartProvider);

      final updatedItem1 = state.items.firstWhere((i) => i.product.id == 62);
      final updatedItem2 = state.items.firstWhere((i) => i.product.id == 249);
      expect(updatedItem1.discount, 10.0);
      expect(updatedItem2.discount, 10.0);

      // book1: 200 * 0.90 = 180.0; book2: 1500 * 0.90 = 1350.0
      // Total payable = 180 + 1350 = 1530.0; Total discount = 170.0
      expect(state.grandTotal, 1530.0);
      expect(state.totalDiscountAmount, 170.0);
      expect(state.grossSubtotal, 1700.0);

      // 3. Convert to OrderLineModels and check Odoo command tuple structure
      final orderLine1 = updatedItem1.toOrderLine();
      expect(orderLine1.discount, 10.0);
      expect(orderLine1.priceSubtotalIncl, 180.0);

      final odooTuple = orderLine1.toOdooCommand();
      expect(odooTuple[0], 0);
      expect(odooTuple[1], 0);
      final tupleValues = odooTuple[2] as Map<String, dynamic>;
      expect(tupleValues['discount'], 10.0);
      expect(tupleValues['product_id'], 62);
    });

    test('CartProvider: multiple active carts, cycling, item isolation, and removal', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);

      const book1 = ProductModel(
        id: 101,
        name: 'Ekattorer Dinguli',
        displayName: 'Ekattorer Dinguli',
        listPrice: 500.0,
      );

      const book2 = ProductModel(
        id: 102,
        name: 'Gitanjali',
        displayName: 'Gitanjali',
        listPrice: 300.0,
      );

      // 1. Initial State: 1 Cart (cart_1)
      var state = container.read(cartProvider);
      expect(state.cartCount, 1);
      final initialCartId = state.activeCartId;
      expect(state.activeCartName, 'কার্ট ১');

      // Add 2 copies of book1 to Cart 1
      cartNotifier.addItem(book1, 2.0);
      state = container.read(cartProvider);
      expect(state.totalItemsCount, 2);
      expect(state.grandTotal, 1000.0);

      // 2. Add New Cart for Walk-In Customer B
      final cart2Id = cartNotifier.addNewCart(customName: 'কার্ট ২');
      state = container.read(cartProvider);
      expect(state.cartCount, 2);
      expect(state.activeCartId, cart2Id);
      expect(state.activeCartName, 'কার্ট ২');
      // Customer B's cart starts fresh with 0 items (Item Isolation!)
      expect(state.totalItemsCount, 0);
      expect(state.grandTotal, 0.0);

      // Add 1 copy of book2 to Customer B's cart
      cartNotifier.addItem(book2, 1.0);
      state = container.read(cartProvider);
      expect(state.totalItemsCount, 1);
      expect(state.grandTotal, 300.0);

      // 3. Cycle Back to Customer A's Cart (Cart 1)
      cartNotifier.switchCart(initialCartId);
      state = container.read(cartProvider);
      expect(state.activeCartId, initialCartId);
      // Customer A's items are completely preserved without data loss!
      expect(state.totalItemsCount, 2);
      expect(state.grandTotal, 1000.0);

      // 4. Rename Cart 1 to Customer Name
      cartNotifier.renameCart(initialCartId, 'আহমেদ ভাই');
      state = container.read(cartProvider);
      expect(state.activeCartName, 'আহমেদ ভাই');

      // 5. Customer A checks out / leaves: Remove Cart 1
      cartNotifier.removeCart(initialCartId);
      state = container.read(cartProvider);
      expect(state.cartCount, 1);
      // Automatically switches to remaining held Cart 2
      expect(state.activeCartId, cart2Id);
      expect(state.totalItemsCount, 1);
      expect(state.grandTotal, 300.0);
    });

    test('PaymentProvider: multi-tender and change calculation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final paymentNotifier = container.read(paymentProvider.notifier);

      paymentNotifier.setTotal(1000.0);
      var state = container.read(paymentProvider);
      expect(state.amountTotal, 1000.0);
      expect(state.remainingDue, 1000.0);
      expect(state.isCompleted, isFalse);

      // Tender 500 Card
      paymentNotifier.addPayment(2, 500.0, methodName: 'Card');
      state = container.read(paymentProvider);
      expect(state.amountTendered, 500.0);
      expect(state.remainingDue, 500.0);
      expect(state.changeDue, 0.0);
      expect(state.isCompleted, isFalse);

      // Tender 700 Cash (over-tender)
      paymentNotifier.addPayment(1, 700.0, methodName: 'Cash');
      state = container.read(paymentProvider);
      expect(state.amountTendered, 1200.0);
      expect(state.remainingDue, 0.0);
      expect(state.changeDue, 200.0);
      expect(state.isCompleted, isTrue);
    });

    test('SyncQueueProvider: submits order to offline queue and syncs when online', () async {
      bool syncCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('sync_from_ui')) {
          syncCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final args = body['params']['args'] as List<dynamic>;
          final orderDict = (args[0] as List<dynamic>)[0] as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': null,
              'result': {
                'pos.order': [
                  {
                    'id': 101,
                    'uuid': orderDict['uuid'],
                    'pos_reference': orderDict['pos_reference'],
                    'amount_total': orderDict['amount_total'],
                    'state': 'paid',
                  }
                ],
                'pos.payment': [],
                'pos.order.line': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"jsonrpc":"2.0","result":[]}', 200);
      });

      final jsonClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          jsonRpcClientProvider.overrideWithValue(jsonClient),
          databaseHelperProvider.overrideWithValue(dbHelper),
          offlineQueueRepositoryProvider.overrideWithValue(queueRepo),
          orderServiceProvider.overrideWithValue(OdooOrderService(client: jsonClient)),
          sessionServiceProvider.overrideWithValue(OdooSessionService(client: jsonClient)),
        ],
      );
      addTearDown(container.dispose);

      final syncNotifier = container.read(syncQueueProvider.notifier);

      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );
      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 110.0,
      );
      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
      );

      // Submit order
      final success = await syncNotifier.submitOrder(order, isOnline: true);
      expect(success, isTrue);
      expect(syncCalled, isTrue);

      final state = container.read(syncQueueProvider);
      expect(state.syncedCount, 1);
      expect(state.pendingCount, 0);
    });
  });
}
