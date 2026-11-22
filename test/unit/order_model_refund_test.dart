import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/data/models/order_model.dart';

void main() {
  group('OrderLineModel Refund Fields & Calculations', () {
    test('Default values: refundedQty is 0.0, refundedOrderlineId is null, id is null', () {
      final line = OrderLineModel.create(
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: 2.0,
        priceUnit: 50.0,
      );

      expect(line.id, isNull);
      expect(line.refundedOrderlineId, isNull);
      expect(line.refundedQty, 0.0);
      expect(line.refundableQty, 2.0);
    });

    test('refundableQty correctly computes remaining refundable quantity', () {
      final line1 = OrderLineModel(
        id: 474,
        uuid: 'uuid-1',
        productId: 242,
        productName: 'Book',
        qty: 5.0,
        priceUnit: 100.0,
        priceSubtotal: 500.0,
        priceSubtotalIncl: 550.0,
        refundedQty: 2.0,
      );
      expect(line1.refundableQty, 3.0);

      // Fully refunded line
      final line2 = line1.copyWith(refundedQty: 5.0);
      expect(line2.refundableQty, 0.0);

      // Over-refunded line in legacy or corrupt data is safely clamped to 0.0
      final line3 = line1.copyWith(refundedQty: 7.0);
      expect(line3.refundableQty, 0.0);
    });

    test('toOdooCommand includes refunded_orderline_id for return lines', () {
      final refundLine = OrderLineModel(
        uuid: 'refund-line-uuid',
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: -1.0,
        priceUnit: 1239.67,
        priceSubtotal: -1115.70,
        priceSubtotalIncl: -1350.00,
        refundedOrderlineId: 474,
      );

      final cmd = refundLine.toOdooCommand();
      expect(cmd, isList);
      expect(cmd.length, 3);
      expect(cmd[0], 0);
      expect(cmd[1], 0);

      final vals = cmd[2] as Map<String, dynamic>;
      expect(vals['product_id'], 242);
      expect(vals['qty'], -1.0);
      expect(vals['price_subtotal_incl'], -1350.00);
      expect(vals['refunded_orderline_id'], 474);
    });

    test('toOdooCommand sets refunded_orderline_id to false for standard sale lines', () {
      final saleLine = OrderLineModel.create(
        productId: 242,
        productName: 'Book',
        qty: 1.0,
        priceUnit: 100.0,
      );

      final cmd = saleLine.toOdooCommand();
      final vals = cmd[2] as Map<String, dynamic>;
      expect(vals['refunded_orderline_id'], false);
    });

    test('toJson and fromJson round-trip preserves all refund fields', () {
      final original = OrderLineModel(
        id: 474,
        uuid: 'test-line-uuid',
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: 2.0,
        priceUnit: 100.0,
        discount: 5.0,
        priceSubtotal: 190.0,
        priceSubtotalIncl: 209.0,
        taxIds: const [1],
        customerNote: 'First edition',
        refundedOrderlineId: 300,
        refundedQty: 1.0,
      );

      final json = original.toJson();
      expect(json['id'], 474);
      expect(json['refunded_orderline_id'], 300);
      expect(json['refunded_qty'], 1.0);

      final restored = OrderLineModel.fromJson(json);
      expect(restored.id, 474);
      expect(restored.uuid, 'test-line-uuid');
      expect(restored.productId, 242);
      expect(restored.productName, 'Christmas at Hogwarts');
      expect(restored.qty, 2.0);
      expect(restored.priceUnit, 100.0);
      expect(restored.discount, 5.0);
      expect(restored.priceSubtotal, 190.0);
      expect(restored.priceSubtotalIncl, 209.0);
      expect(restored.taxIds, [1]);
      expect(restored.customerNote, 'First edition');
      expect(restored.refundedOrderlineId, 300);
      expect(restored.refundedQty, 1.0);
      expect(restored.refundableQty, 1.0);
    });

    test('fromJson seamlessly parses Odoo 19 pos.order.line read response format', () {
      // In Odoo 19 RPC, many2one fields return [id, name] or false
      final odooReadMap = {
        'id': 474,
        'product_id': [242, 'Christmas at Hogwarts'],
        'full_product_name': 'Christmas at Hogwarts',
        'qty': 2.0,
        'price_unit': 1239.6695,
        'discount': 0.0,
        'price_subtotal': 2231.40,
        'price_subtotal_incl': 2700.00,
        'tax_ids': [1],
        'refunded_qty': 1.0,
        'refund_orderline_ids': [479],
        'refunded_orderline_id': false,
      };

      final line = OrderLineModel.fromJson(odooReadMap);
      expect(line.id, 474);
      expect(line.productId, 242);
      expect(line.productName, 'Christmas at Hogwarts');
      expect(line.qty, 2.0);
      expect(line.refundedQty, 1.0);
      expect(line.refundableQty, 1.0);
      expect(line.refundedOrderlineId, isNull);
    });

    test('copyWith updates or preserves refund properties', () {
      final line = OrderLineModel(
        id: 10,
        uuid: 'uuid-10',
        productId: 100,
        productName: 'Novel',
        qty: 3.0,
        priceUnit: 50.0,
        priceSubtotal: 150.0,
        priceSubtotalIncl: 165.0,
        refundedOrderlineId: null,
        refundedQty: 0.0,
      );

      final updated = line.copyWith(
        refundedQty: 2.0,
        refundedOrderlineId: 99,
      );

      expect(updated.id, 10);
      expect(updated.refundedQty, 2.0);
      expect(updated.refundedOrderlineId, 99);
      expect(updated.refundableQty, 1.0);
    });
  });

  group('OrderModel Refund Fields & Serialization', () {
    test('Default values: isRefund is false, refundedOrderId is null, hasRefundableLines is false', () {
      final order = OrderModel.create(
        sessionId: 23,
        lines: [],
        payments: [],
      );

      expect(order.id, isNull);
      expect(order.isRefund, isFalse);
      expect(order.refundedOrderId, isNull);
      expect(order.hasRefundableLines, isFalse);
    });

    test('OrderModel.create with isRefund: true builds return order structure', () {
      final returnLine = OrderLineModel(
        uuid: 'ret-line-1',
        productId: 242,
        productName: 'Book',
        qty: -1.0,
        priceUnit: 50.0,
        priceSubtotal: -50.0,
        priceSubtotalIncl: -55.0,
        refundedOrderlineId: 474,
      );

      final payment = PaymentLineModel(
        uuid: 'ret-pay-1',
        paymentMethodId: 1,
        amount: -55.0,
      );

      final returnOrder = OrderModel.create(
        sessionId: 23,
        lines: [returnLine],
        payments: [payment],
        isRefund: true,
        refundedOrderId: 420,
      );

      expect(returnOrder.isRefund, isTrue);
      expect(returnOrder.refundedOrderId, 420);
      expect(returnOrder.amountTotal, -55.0);
      expect(returnOrder.amountPaid, -55.0);
      expect(returnOrder.amountReturn, 0.0);
      expect(returnOrder.posReference.startsWith('RETURN-'), isTrue);
      expect(returnOrder.name?.contains('ফেরত'), isTrue);
    });

    test('toOdooPayload enforces Odoo 19 return payload invariants', () {
      final returnLine = OrderLineModel(
        uuid: 'line-uuid',
        productId: 242,
        productName: 'Christmas at Hogwarts',
        qty: -1.0,
        priceUnit: 1239.67,
        priceSubtotal: -1115.70,
        priceSubtotalIncl: -1350.00,
        refundedOrderlineId: 474,
      );

      final payment = PaymentLineModel(
        uuid: 'pay-uuid',
        paymentMethodId: 1,
        amount: -1350.00,
        sessionId: 23,
      );

      final returnOrder = OrderModel.create(
        sessionId: 23,
        configId: 1,
        lines: [returnLine],
        payments: [payment],
        isRefund: true,
        refundedOrderId: 420,
      );

      final payload = returnOrder.toOdooPayload();

      // Invariant 1: is_refund is true
      expect(payload['is_refund'], isTrue);

      // Invariant 2: refunded_order_id matches parent order ID
      expect(payload['refunded_order_id'], 420);

      // Invariant 3: amount_total and amount_paid are negative and equal
      expect(payload['amount_total'], -1350.00);
      expect(payload['amount_paid'], -1350.00);

      // Invariant 4: amount_return is strictly 0.0
      expect(payload['amount_return'], 0.0);

      // Invariant 5: No change lines generated for refund orders
      final payments = payload['payment_ids'] as List;
      expect(payments.length, 1);
      final paymentVals = payments[0][2] as Map<String, dynamic>;
      expect(paymentVals['amount'], -1350.00);
      expect(paymentVals['is_change'], isFalse);

      // Invariant 6: Lines contain negative qty and refunded_orderline_id
      final lines = payload['lines'] as List;
      expect(lines.length, 1);
      final lineVals = lines[0][2] as Map<String, dynamic>;
      expect(lineVals['qty'], -1.0);
      expect(lineVals['refunded_orderline_id'], 474);
    });

    test('toOdooPayload with reverseNetTax: true handles return lines correctly', () {
      final returnLine = OrderLineModel(
        uuid: 'rev-line-uuid',
        productId: 242,
        productName: 'Book',
        qty: -2.0,
        priceUnit: 100.0, // Gross MRP
        priceSubtotal: -181.82,
        priceSubtotalIncl: -200.0,
        refundedOrderlineId: 500,
      );

      final payment = PaymentLineModel(
        uuid: 'rev-pay-uuid',
        paymentMethodId: 1,
        amount: -200.0,
      );

      final returnOrder = OrderModel.create(
        sessionId: 23,
        lines: [returnLine],
        payments: [payment],
        isRefund: true,
        refundedOrderId: 100,
      );

      final payload = returnOrder.toOdooPayload(reverseNetTax: true);
      expect(payload['is_refund'], isTrue);
      expect(payload['refunded_order_id'], 100);

      final lines = payload['lines'] as List;
      final lineVals = lines[0][2] as Map<String, dynamic>;
      expect(lineVals['qty'], -2.0);
      expect(lineVals['refunded_orderline_id'], 500);
      expect(lineVals['price_subtotal_incl'], -200.0);
    });

    test('toJson and fromJson round-trip preserves all return fields', () {
      final original = OrderModel(
        id: 424,
        uuid: 'test-order-uuid',
        posReference: 'RETURN-264-1-000009',
        ticketCode: '4f54c',
        trackingNumber: '4009',
        sessionId: 23,
        configId: 1,
        companyId: 1,
        userId: 2,
        partnerId: 55,
        amountTotal: -1350.00,
        amountPaid: -1350.00,
        amountReturn: 0.0,
        amountTax: -234.30,
        lines: [
          OrderLineModel(
            id: 479,
            uuid: 'line-uuid',
            productId: 242,
            productName: 'Christmas at Hogwarts',
            qty: -1.0,
            priceUnit: 1239.67,
            priceSubtotal: -1115.70,
            priceSubtotalIncl: -1350.00,
            refundedOrderlineId: 474,
          )
        ],
        payments: [
          PaymentLineModel(
            uuid: 'pay-uuid',
            paymentMethodId: 1,
            amount: -1350.00,
          )
        ],
        createdAt: DateTime(2026, 11, 21, 16, 10),
        dateOrder: DateTime(2026, 11, 21, 16, 10),
        state: 'paid',
        name: 'Order - 000009 ফেরত',
        sequenceNumber: 9,
        accessToken: 'access-uuid',
        isSynced: true,
        isRefund: true,
        refundedOrderId: 420,
        hasRefundableLines: false,
      );

      final json = original.toJson();
      expect(json['id'], 424);
      expect(json['is_refund'], isTrue);
      expect(json['refunded_order_id'], 420);
      expect(json['has_refundable_lines'], isFalse);

      final restored = OrderModel.fromJson(json);
      expect(restored.id, 424);
      expect(restored.uuid, 'test-order-uuid');
      expect(restored.posReference, 'RETURN-264-1-000009');
      expect(restored.isRefund, isTrue);
      expect(restored.refundedOrderId, 420);
      expect(restored.hasRefundableLines, isFalse);
      expect(restored.amountTotal, -1350.00);
      expect(restored.amountPaid, -1350.00);
      expect(restored.lines.first.refundedOrderlineId, 474);
    });

    test('fromJson seamlessly parses Odoo 19 search_read response format', () {
      final odooSearchReadMap = {
        'id': 420,
        'name': 'Book Fair - 000001',
        'pos_reference': '264-1-000001',
        'date_order': '2026-11-21 15:30:00',
        'partner_id': [55, 'Rahim Uddin'],
        'amount_total': 1350.0,
        'amount_paid': 1350.0,
        'amount_tax': 234.3,
        'is_refund': false,
        'refunded_order_id': false,
        'has_refundable_lines': true,
        'refund_orders_count': 1,
        'lines': [473, 474],
        'ticket_code': '0qfc5',
        'tracking_number': '4001',
        'session_id': [23, 'Book Fair/00014'],
      };

      final order = OrderModel.fromJson(odooSearchReadMap);
      expect(order.id, 420);
      expect(order.name, 'Book Fair - 000001');
      expect(order.posReference, '264-1-000001');
      expect(order.partnerId, 55);
      expect(order.sessionId, 23);
      expect(order.isRefund, isFalse);
      expect(order.refundedOrderId, isNull);
      expect(order.hasRefundableLines, isTrue);
      expect(order.lineIds, [473, 474]);
    });

    test('toMap and fromMap preserves is_refund and refunded_order_id for SQLite queue', () {
      final order = OrderModel.create(
        sessionId: 23,
        lines: [],
        payments: [],
        isRefund: true,
        refundedOrderId: 420,
      );

      final map = order.toMap();
      expect(map['is_refund'], 1);
      expect(map['refunded_order_id'], 420);

      final restored = OrderModel.fromMap(map);
      expect(restored.isRefund, isTrue);
      expect(restored.refundedOrderId, 420);
    });

    test('copyWithSession preserves all refund fields when rebinding closed session', () {
      final original = OrderModel.create(
        sessionId: 19,
        lines: [],
        payments: [
          PaymentLineModel(
            uuid: 'pay-1',
            paymentMethodId: 1,
            amount: -100.0,
            sessionId: 19,
          )
        ],
        isRefund: true,
        refundedOrderId: 420,
      );

      final rebound = original.copyWithSession(25);
      expect(rebound.sessionId, 25);
      expect(rebound.payments.first.sessionId, 25);
      expect(rebound.isRefund, isTrue);
      expect(rebound.refundedOrderId, 420);
    });

    test('PaymentLineModel.fromJson parses both integer and many2one tuple payment_method_id with Dart 3 patterns', () {
      final jsonWithTuple = {
        'uuid': 'pay-tuple',
        'payment_method_id': [3, 'Bank Card'],
        'amount': 500.0,
        'session_id': [23, 'Session 23'],
      };
      final paymentFromTuple = PaymentLineModel.fromJson(jsonWithTuple);
      expect(paymentFromTuple.paymentMethodId, 3);
      expect(paymentFromTuple.paymentMethodName, 'Bank Card');
      expect(paymentFromTuple.sessionId, 23);
      expect(paymentFromTuple.amount, 500.0);

      final jsonWithInt = {
        'uuid': 'pay-int',
        'payment_method_id': 1,
        'payment_method_name': 'Cash',
        'amount': 200.0,
        'session_id': 23,
      };
      final paymentFromInt = PaymentLineModel.fromJson(jsonWithInt);
      expect(paymentFromInt.paymentMethodId, 1);
      expect(paymentFromInt.paymentMethodName, 'Cash');
      expect(paymentFromInt.sessionId, 23);
      expect(paymentFromInt.amount, 200.0);
    });

    test('OrderModel.create dynamically calculates hasRefundableLines for sales and refund orders', () {
      const saleLine = OrderLineModel(
        uuid: 'sale-line-1',
        productId: 101,
        productName: 'Sale Item',
        qty: 2.0,
        priceUnit: 100.0,
        priceSubtotal: 200.0,
        priceSubtotalIncl: 200.0,
        refundedQty: 0.0,
      );

      final saleOrder = OrderModel.create(
        sessionId: 23,
        lines: [saleLine],
        payments: const [],
      );
      expect(saleOrder.hasRefundableLines, isTrue,
          reason: 'Positive sales lines should make order refundable by default');

      const refundLine = OrderLineModel(
        uuid: 'refund-line-1',
        productId: 101,
        productName: 'Refund Item',
        qty: -2.0,
        priceUnit: 100.0,
        priceSubtotal: -200.0,
        priceSubtotalIncl: -200.0,
        refundedQty: 0.0,
      );

      final returnOrder = OrderModel.create(
        sessionId: 23,
        lines: [refundLine],
        payments: const [],
        isRefund: true,
      );
      expect(returnOrder.hasRefundableLines, isFalse,
          reason: 'Return order has no positive refundable lines, must evaluate to false');
    });

    test('OrderModel.fromJson parses lines from maps, Odoo command tuples, and integer stub IDs with Dart 3 switch expressions', () {
      final json = {
        'id': 789,
        'name': 'Mixed Lines Order',
        'lines': [
          // Plain map
          {
            'id': 1,
            'product_id': [10, 'Map Product'],
            'qty': 1.0,
            'price_unit': 50.0,
          },
          // Odoo command tuple [0, 0, Map]
          [
            0,
            0,
            {
              'id': 2,
              'product_id': [20, 'Tuple Product'],
              'qty': 2.0,
              'price_unit': 100.0,
            }
          ],
          // Integer stub ID
          999,
        ],
      };

      final order = OrderModel.fromJson(json);
      expect(order.lines.length, 3);
      expect(order.lines[0].productId, 10);
      expect(order.lines[0].productName, 'Map Product');
      expect(order.lines[1].productId, 20);
      expect(order.lines[1].productName, 'Tuple Product');
      expect(order.lines[2].id, 999);
      expect(order.lines[2].productName, '');
      expect(order.lines[2].qty, 0.0);
    });
  });
}
