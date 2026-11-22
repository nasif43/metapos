import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/data/repositories/order_repository.dart';

void main() {
  DatabaseHelper.initializeFfi();

  group('OdooOrderService Past Orders & Lines Fetch', () {
    test('searchPastOrders executes search_read with proper domain and fields', () async {
      String? capturedModel;
      String? capturedMethod;
      List<dynamic>? capturedArgs;
      Map<String, dynamic>? capturedKwargs;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final params = body['params'] as Map<String, dynamic>;
        capturedModel = params['model'] as String;
        capturedMethod = params['method'] as String;
        capturedArgs = params['args'] as List<dynamic>;
        capturedKwargs = params['kwargs'] as Map<String, dynamic>;

        final sampleResponse = [
          {
            'id': 420,
            'name': 'Book Fair - 000001',
            'pos_reference': '264-1-000001',
            'date_order': '2026-11-21 15:30:00',
            'partner_id': false,
            'amount_total': 1350.0,
            'amount_paid': 1350.0,
            'amount_tax': 234.3,
            'is_refund': false,
            'refunded_order_id': false,
            'has_refundable_lines': true,
            'refund_orders_count': 0,
            'lines': [473, 474],
            'ticket_code': '0qfc5',
            'tracking_number': '4001',
            'session_id': [23, 'Book Fair/00014'],
          }
        ];

        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': sampleResponse,
          }),
          200,
        );
      });

      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );
      final orderService = OdooOrderService(client: rpcClient);

      final orders = await orderService.searchPastOrders('264-1-000001');

      expect(capturedModel, 'pos.order');
      expect(capturedMethod, 'search_read');
      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.isNotEmpty, isTrue);
      expect(capturedKwargs, isNotNull);
      expect(capturedKwargs!['fields'], isNotNull);
      expect(capturedKwargs!['limit'], 50);

      final domain = capturedArgs![0] as List;
      expect(
        domain.any((e) => e is List && e.isNotEmpty && e[0] == 'pos_reference'),
        isTrue,
      );
      expect(
        domain.any((e) => e is List && e.isNotEmpty && e[0] == 'state'),
        isTrue,
      );
      expect(capturedKwargs, isNotNull);

      expect(orders.length, 1);
      final order = orders.first;
      expect(order.id, 420);
      expect(order.posReference, '264-1-000001');
      expect(order.hasRefundableLines, isTrue);
      expect(order.lineIds, [473, 474]);
    });

    test('fetchOrderLines executes read on pos.order.line with correct field list', () async {
      String? capturedModel;
      String? capturedMethod;
      List<dynamic>? capturedArgs;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final params = body['params'] as Map<String, dynamic>;
        capturedModel = params['model'] as String;
        capturedMethod = params['method'] as String;
        capturedArgs = params['args'] as List<dynamic>;

        final sampleLines = [
          {
            'id': 474,
            'product_id': [242, 'Christmas at Hogwarts'],
            'full_product_name': 'Christmas at Hogwarts',
            'qty': 2.0,
            'price_unit': 1239.67,
            'discount': 0.0,
            'price_subtotal': 2479.34,
            'price_subtotal_incl': 2700.00,
            'tax_ids': [1],
            'refunded_qty': 1.0,
            'refund_orderline_ids': [479],
            'refunded_orderline_id': false,
          }
        ];

        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': sampleLines,
          }),
          200,
        );
      });

      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );
      final orderService = OdooOrderService(client: rpcClient);

      final lines = await orderService.fetchOrderLines([474]);

      expect(capturedModel, 'pos.order.line');
      expect(capturedMethod, 'read');
      expect(capturedArgs![0], [474]);

      expect(lines.length, 1);
      final line = lines.first;
      expect(line.id, 474);
      expect(line.productName, 'Christmas at Hogwarts');
      expect(line.qty, 2.0);
      expect(line.refundedQty, 1.0);
      expect(line.refundableQty, 1.0);
    });
  });

  group('OrderRepository Past Orders Search & Return Submission', () {
    late Directory tempDir;
    late String dbPath;
    late DatabaseHelper dbHelper;
    late OfflineQueueRepository queueRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('metapos_repo_test_');
      dbPath = join(tempDir.path, 'repo_test.db');
      dbHelper = DatabaseHelper(customDbPath: dbPath);
      queueRepo = OfflineQueueRepository(dbHelper: dbHelper);
      await dbHelper.close();
    });

    tearDown(() async {
      await dbHelper.close();
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('searchPastOrders falls back gracefully to local SQLite orders when remote fails', () async {
      // Seed a local order in SQLite
      final localOrder = OrderModel.create(
        sessionId: 23,
        posReference: '264-1-LOCAL01',
        lines: [
          OrderLineModel.create(
            productId: 101,
            productName: 'Local Book',
            qty: 1.0,
            priceUnit: 200.0,
          )
        ],
        payments: [
          PaymentLineModel(
            uuid: 'pay-local',
            paymentMethodId: 1,
            amount: 220.0,
          )
        ],
      );
      await queueRepo.enqueueOrder(localOrder);

      // Create an order service whose HTTP client fails (offline simulation)
      final failingClient = MockClient((_) async {
        throw http.ClientException('Network unreachable');
      });
      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: failingClient,
      );
      final orderService = OdooOrderService(client: rpcClient);
      final sessionService = OdooSessionService(client: rpcClient);

      final repository = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      // Search for the local order while remote is down
      final results = await repository.searchPastOrders('LOCAL01');

      expect(results.length, 1);
      expect(results.first.posReference, '264-1-LOCAL01');
      expect(results.first.amountTotal, 220.0);
    });

    test('submitReturnOrder builds genuine Odoo 19 return order and synchronizes online', () async {
      OrderModel? submittedToOdoo;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final params = body['params'] as Map<String, dynamic>;
        final method = params['method'] as String;

        if (method == 'sync_from_ui') {
          final payloadList = params['args'][0] as List;
          final orderPayload = payloadList[0] as Map<String, dynamic>;
          submittedToOdoo = OrderModel.fromJson(orderPayload);

          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': {
                'pos.order': [
                  {
                    'id': 1002,
                    'pos_reference': orderPayload['pos_reference'],
                  }
                ]
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );
      final orderService = OdooOrderService(client: rpcClient);
      final sessionService = OdooSessionService(client: rpcClient);

      final repository = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      final origLine = OrderLineModel(
        id: 474,
        uuid: 'orig-line-uuid',
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: 2.0,
        priceUnit: 1239.67,
        priceSubtotal: 2479.34,
        priceSubtotalIncl: 2700.00,
        taxIds: const [1],
      );

      final originalOrder = OrderModel(
        id: 420,
        uuid: 'orig-order-uuid',
        posReference: '264-1-000001',
        ticketCode: '0qfc5',
        trackingNumber: '4001',
        sessionId: 19,
        configId: 1,
        companyId: 1,
        userId: 2,
        amountTotal: 2700.00,
        amountPaid: 2700.00,
        amountTax: 220.66,
        lines: [origLine],
        payments: [],
        createdAt: DateTime.now(),
        accessToken: 'orig-token',
        isSynced: true,
      );

      // Return 1 unit out of 2
      final returnOrder = await repository.submitReturnOrder(
        originalOrder: originalOrder,
        returnLines: {origLine: 1.0},
        paymentMethodId: 1,
        sessionId: 23, // Active current session
      );

      // Verify return order object
      expect(returnOrder.isRefund, isTrue);
      expect(returnOrder.refundedOrderId, 420);
      expect(returnOrder.sessionId, 23);
      expect(returnOrder.amountTotal, -1350.00);
      expect(returnOrder.amountPaid, -1350.00);
      expect(returnOrder.isSynced, isTrue);

      // Verify payload received by Odoo endpoint
      expect(submittedToOdoo, isNotNull);
      expect(submittedToOdoo!.isRefund, isTrue);
      expect(submittedToOdoo!.refundedOrderId, 420);
      expect(submittedToOdoo!.amountTotal, -1350.00);
      expect(submittedToOdoo!.lines.first.qty, -1.0);
      expect(submittedToOdoo!.lines.first.refundedOrderlineId, 474);
      expect(submittedToOdoo!.payments.first.amount, -1350.00);

      // Verify persisted in local SQLite with synced status
      final persisted = await queueRepo.getOrder(returnOrder.uuid);
      expect(persisted, isNotNull);
      expect(persisted!['is_refund'], 1);
      expect(persisted['refunded_order_id'], 420);
      expect(persisted['sync_status'], 'synced');
    });

    test('submitReturnOrder persists to SQLite and stays pending when offline', () async {
      final offlineClient = MockClient((_) async {
        throw const SocketException('No Internet Connection');
      });
      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: offlineClient,
      );
      final orderService = OdooOrderService(client: rpcClient);
      final sessionService = OdooSessionService(client: rpcClient);

      final repository = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      final origLine = OrderLineModel(
        id: 476,
        uuid: 'orig-line-2',
        productId: 200,
        productName: 'Offline Test Book',
        qty: 1.0,
        priceUnit: 50.0,
        priceSubtotal: 50.0,
        priceSubtotalIncl: 55.0,
      );

      final originalOrder = OrderModel(
        id: 421,
        uuid: 'orig-order-2',
        posReference: '264-1-000002',
        ticketCode: 'abcde',
        trackingNumber: '4002',
        sessionId: 23,
        amountTotal: 55.0,
        amountPaid: 55.0,
        amountTax: 5.0,
        lines: [origLine],
        payments: [],
        createdAt: DateTime.now(),
        accessToken: 'token-2',
      );

      // Submit return order with isOnline: false (clean offline queue behavior)
      final returnOrder = await repository.submitReturnOrder(
        originalOrder: originalOrder,
        returnLines: {origLine: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
        isOnline: false,
        isOfflineMode: false,
      );

      // Return order is created and returned with isSynced: false
      expect(returnOrder.isRefund, isTrue);
      expect(returnOrder.refundedOrderId, 421);
      expect(returnOrder.amountTotal, -55.0);
      expect(returnOrder.isSynced, isFalse);

      // Order is safely queued in SQLite with pending status and 0 retries
      final queuedRow = await queueRepo.getOrder(returnOrder.uuid);
      expect(queuedRow, isNotNull);
      expect(queuedRow!['is_refund'], 1);
      expect(queuedRow['refunded_order_id'], 421);
      expect(queuedRow['sync_status'], 'pending');
      expect(queuedRow['retry_count'], 0);
    });

    test('submitReturnOrder fails and increments retry_count when online sync encounters network failure', () async {
      final offlineClient = MockClient((_) async {
        throw const SocketException('Connection lost during transmission');
      });
      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: offlineClient,
      );
      final orderService = OdooOrderService(client: rpcClient);
      final sessionService = OdooSessionService(client: rpcClient);

      final repository = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: orderService,
        sessionService: sessionService,
      );

      final origLine = OrderLineModel(
        id: 477,
        uuid: 'orig-line-3',
        productId: 201,
        productName: 'Failed Sync Book',
        qty: 1.0,
        priceUnit: 100.0,
        priceSubtotal: 100.0,
        priceSubtotalIncl: 115.0,
      );

      final originalOrder = OrderModel(
        id: 422,
        uuid: 'orig-order-3',
        posReference: '264-1-000003',
        ticketCode: 'fghij',
        trackingNumber: '4003',
        sessionId: 23,
        amountTotal: 115.0,
        amountPaid: 115.0,
        amountTax: 15.0,
        lines: [origLine],
        payments: [],
        createdAt: DateTime.now(),
        accessToken: 'token-3',
      );

      // Online submission that fails due to SocketException transitions to 'failed'
      final returnOrder = await repository.submitReturnOrder(
        originalOrder: originalOrder,
        returnLines: {origLine: 1.0},
        paymentMethodId: 1,
        sessionId: 23,
        isOnline: true,
        isOfflineMode: false,
      );

      expect(returnOrder.isRefund, isTrue);
      expect(returnOrder.isSynced, isFalse);

      final queuedRow = await queueRepo.getOrder(returnOrder.uuid);
      expect(queuedRow, isNotNull);
      expect(queuedRow!['sync_status'], 'failed');
      expect(queuedRow['retry_count'], 1);
    });

    group('submitReturnOrder Domain Validation Preconditions', () {
      late OrderRepository repository;
      late OrderModel testOriginalOrder;
      late OrderLineModel testLine1;

      setUp(() {
        final mockClient = MockClient((_) async => http.Response('{}', 200));
        final rpcClient = OdooJsonRpcClient(
          baseUrl: 'https://demostore.metaposbd.com',
          httpClient: mockClient,
        );
        repository = OrderRepositoryImpl(
          queueRepo: queueRepo,
          orderService: OdooOrderService(client: rpcClient),
          sessionService: OdooSessionService(client: rpcClient),
        );

        testLine1 = const OrderLineModel(
          id: 501,
          uuid: 'line-val-1',
          productId: 101,
          productName: 'Valid Book',
          qty: 3.0,
          priceUnit: 100.0,
          priceSubtotal: 300.0,
          priceSubtotalIncl: 330.0,
          refundedQty: 1.0, // refundableQty = 2.0
        );

        testOriginalOrder = OrderModel(
          id: 601,
          uuid: 'order-val-1',
          posReference: '264-1-VAL01',
          ticketCode: 'val01',
          trackingNumber: '4004',
          sessionId: 23,
          amountTotal: 330.0,
          amountPaid: 330.0,
          amountTax: 30.0,
          lines: [testLine1],
          payments: [],
          createdAt: DateTime.now(),
          accessToken: 'token-val',
        );
      });

      test('throws ArgumentError when returnLines is empty', () async {
        expect(
          () => repository.submitReturnOrder(
            originalOrder: testOriginalOrder,
            returnLines: {},
            paymentMethodId: 1,
            sessionId: 23,
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no valid return items'),
          )),
        );
      });

      test('throws ArgumentError when returnLines contains negative quantity', () async {
        expect(
          () => repository.submitReturnOrder(
            originalOrder: testOriginalOrder,
            returnLines: {testLine1: -1.0},
            paymentMethodId: 1,
            sessionId: 23,
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cannot be negative'),
          )),
        );
      });

      test('throws ArgumentError when all return quantities are 0.0', () async {
        expect(
          () => repository.submitReturnOrder(
            originalOrder: testOriginalOrder,
            returnLines: {testLine1: 0.0},
            paymentMethodId: 1,
            sessionId: 23,
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('all quantities <= 0'),
          )),
        );
      });

      test('throws ArgumentError when return quantity exceeds refundableQty', () async {
        // refundableQty is 2.0 (qty 3.0 - refundedQty 1.0)
        expect(
          () => repository.submitReturnOrder(
            originalOrder: testOriginalOrder,
            returnLines: {testLine1: 2.5},
            paymentMethodId: 1,
            sessionId: 23,
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('exceeds refundable quantity'),
          )),
        );
      });

      test('throws ArgumentError when original line qty is non-positive', () async {
        const nonPositiveLine = OrderLineModel(
          id: 502,
          uuid: 'neg-line-orig',
          productId: 102,
          productName: 'Refund Line As Source',
          qty: -1.0,
          priceUnit: 50.0,
          priceSubtotal: -50.0,
          priceSubtotalIncl: -55.0,
        );

        expect(
          () => repository.submitReturnOrder(
            originalOrder: testOriginalOrder,
            returnLines: {nonPositiveLine: 1.0},
            paymentMethodId: 1,
            sessionId: 23,
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('non-positive original quantity'),
          )),
        );
      });
    });

    test('searchPastOrders preserves rich local lines when remote order only contains stub line IDs', () async {
      // 1. Enqueue local order with rich line information in SQLite
      const richLine = OrderLineModel(
        id: null,
        uuid: 'local-rich-line-1',
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: 2.0,
        priceUnit: 1239.67,
        priceSubtotal: 2479.34,
        priceSubtotalIncl: 2700.0,
        taxIds: [1],
      );

      final localOrder = OrderModel.create(
        sessionId: 23,
        lines: [richLine],
        payments: const [],
        posReference: '264-1-RICH01',
      );
      await queueRepo.enqueueOrder(localOrder);

      // 2. Mock remote service returning backend authoritative state with integer line IDs [474]
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'result': [
              {
                'id': 425,
                'name': 'Book Fair - RICH01',
                'pos_reference': '264-1-RICH01',
                'date_order': '2026-11-21 16:00:00',
                'amount_total': 2700.0,
                'amount_paid': 2700.0,
                'amount_tax': 220.66,
                'is_refund': false,
                'refunded_order_id': false,
                'has_refundable_lines': true,
                'lines': [474], // Stub integer ID
                'session_id': [23, 'Book Fair/00014'],
              }
            ],
          }),
          200,
        );
      });

      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );
      final repository = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: OdooOrderService(client: rpcClient),
        sessionService: OdooSessionService(client: rpcClient),
      );

      // 3. Search past orders
      final results = await repository.searchPastOrders('RICH01');

      expect(results.length, 1);
      final mergedOrder = results.first;
      expect(mergedOrder.posReference, '264-1-RICH01');
      expect(mergedOrder.id, 425);
      expect(mergedOrder.uuid, localOrder.uuid); // Preserved local UUID
      expect(mergedOrder.lines.length, 1);

      // Verifies rich line data is preserved from local order and mapped to remote line ID
      final line = mergedOrder.lines.first;
      expect(line.productName, 'Christmas at Hogwarts');
      expect(line.qty, 2.0);
      expect(line.priceSubtotalIncl, 2700.0);
      expect(line.id, 474); // Mapped backend line ID
    });

    test('searchPastOrders does not throw RangeError when limit is 0 or negative', () async {
      final mockClient = MockClient((_) async => http.Response('{"jsonrpc":"2.0","id":1,"result":[]}', 200));
      final rpcClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );
      final repository = OrderRepositoryImpl(
        queueRepo: queueRepo,
        orderService: OdooOrderService(client: rpcClient),
        sessionService: OdooSessionService(client: rpcClient),
      );

      // Should return without RangeError
      final resZero = await repository.searchPastOrders('', limit: 0);
      expect(resZero, isEmpty);

      final resNegative = await repository.searchPastOrders('', limit: -1);
      expect(resNegative, isEmpty);
    });
  });
}
