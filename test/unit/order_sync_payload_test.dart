import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/data/models/order_model.dart';

void main() {
  group('Order Sync Payload & Financial Calculations Unit Tests', () {
    final uuidV4Regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    test('Order, lines, and payments generate standard RFC 4122 v4 UUIDs', () {
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

      expect(uuidV4Regex.hasMatch(order.uuid), isTrue,
          reason: 'Order UUID must be RFC 4122 v4');
      expect(uuidV4Regex.hasMatch(order.accessToken), isTrue,
          reason: 'Access Token must be RFC 4122 v4');
      expect(uuidV4Regex.hasMatch(line.uuid), isTrue,
          reason: 'Order line UUID must be RFC 4122 v4');
      expect(uuidV4Regex.hasMatch(payment.uuid), isTrue,
          reason: 'Payment line UUID must be RFC 4122 v4');
    });

    test('Cash over-tender automatically pairs tender line with change line ("ফেরত")', () {
      // Order with ৳ 110 total due
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
        isTaxInclusive: false, // 100 base + 10% VAT = 110 total
      );

      // Customer tenders ৳ 500 Cash
      final tenderPayment = PaymentLineModel.create(
        paymentMethodId: 1, // Cash
        amount: 500.0,
        sessionId: 14,
      );

      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [tenderPayment],
      );

      expect(order.amountTotal, 110.0);
      expect(order.amountReturn, 390.0);

      // Generate Odoo 19 sync payload
      final payload = order.toOdooPayload();
      final paymentIds = payload['payment_ids'] as List<dynamic>;

      // Must contain exactly 2 payment command tuples: [0, 0, tender] and [0, 0, change]
      expect(paymentIds.length, 2);

      final tenderLine = paymentIds[0][2] as Map<String, dynamic>;
      expect(tenderLine['amount'], 500.0);
      expect(tenderLine['is_change'], false);

      final changeLine = paymentIds[1][2] as Map<String, dynamic>;
      expect(changeLine['amount'], -390.0);
      expect(changeLine['is_change'], true);
      expect(changeLine['name'], 'ফেরত');

      // CRITICAL ODOO RULE: Sum of all payments must equal amount_total (110.0)
      final netPaymentSum = (tenderLine['amount'] as double) + (changeLine['amount'] as double);
      expect(netPaymentSum, order.amountTotal);
      expect(payload['amount_paid'], order.amountTotal);
      expect(payload['amount_return'], 0.0,
          reason: 'Odoo 19 sync_from_ui invariant requires amount_return == 0.0');
      expect(order.amountReturn, 390.0,
          reason: 'Client-side receipt still preserves local change return amount');
    });

    test('MRP Reverse Net Tax Calculation: cover price ৳ 100.00 maintains ৳ 100.00 gross total with 10% VAT', () {
      // Retail Bookstore Standard: cover price is ৳ 100.00 gross.
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0, // Printed MRP
        isTaxInclusive: true, // Reverse net calculation
      );

      // Unit price before tax: 100 / 1.10 = 90.91
      expect(line.priceUnit, closeTo(90.91, 0.01));
      expect(line.priceSubtotal, closeTo(90.91, 0.01));
      expect(line.priceSubtotalIncl, 100.0);

      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 100.0,
      );

      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
      );

      expect(order.amountTotal, 100.0);
      expect(order.amountTax, closeTo(9.09, 0.01));

      final payload = order.toOdooPayload();
      expect(payload['amount_total'], 100.0);
      expect(payload['amount_tax'], closeTo(9.09, 0.01));
    });

    test('Additive Tax Mode Calculation: base price ৳ 100.00 yields ৳ 110.00 gross with 10% VAT', () {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 1.0,
        priceUnit: 100.0,
        isTaxInclusive: false,
      );

      expect(line.priceUnit, 100.0);
      expect(line.priceSubtotal, 100.0);
      expect(line.priceSubtotalIncl, 110.0);

      final payment = PaymentLineModel.create(
        paymentMethodId: 2, // Card
        amount: 110.0,
      );

      final order = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
      );

      expect(order.amountTotal, 110.0);
      expect(order.amountTax, 10.0);

      final payload = order.toOdooPayload();
      expect(payload['amount_total'], 110.0);
      expect(payload['amount_tax'], 10.0);
    });

    test('Order serialization roundtrip (toJson and fromJson) preserves all fields', () {
      final line = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbrid Classic',
        qty: 2.0,
        priceUnit: 150.0,
        discount: 10.0,
        isTaxInclusive: true,
      );

      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 270.0,
      );

      final originalOrder = OrderModel.create(
        sessionId: 14,
        lines: [line],
        payments: [payment],
        sequenceNumber: 8,
      );

      final json = originalOrder.toJson();
      final reconstituted = OrderModel.fromJson(json);

      expect(reconstituted.uuid, originalOrder.uuid);
      expect(reconstituted.posReference, originalOrder.posReference);
      expect(reconstituted.amountTotal, originalOrder.amountTotal);
      expect(reconstituted.amountTax, originalOrder.amountTax);
      expect(reconstituted.lines.length, 1);
      expect(reconstituted.lines[0].productId, 62);
      expect(reconstituted.lines[0].qty, 2.0);
      expect(reconstituted.lines[0].discount, 10.0);
      expect(reconstituted.payments.length, 1);
      expect(reconstituted.payments[0].amount, 270.0);
    });

    test('Order lines are deterministically sorted by productId ascending in toOdooPayload to prevent PostgreSQL deadlocks', () {
      final line1 = OrderLineModel.create(
        productId: 62,
        productName: 'Blackbird Classic',
        qty: 1.0,
        priceUnit: 100.0,
      );
      final line2 = OrderLineModel.create(
        productId: 44,
        productName: 'Metamorphosis Special',
        qty: 2.0,
        priceUnit: 150.0,
      );
      final line3 = OrderLineModel.create(
        productId: 55,
        productName: 'Intermediate Novel',
        qty: 1.0,
        priceUnit: 80.0,
      );

      final payment = PaymentLineModel.create(
        paymentMethodId: 1,
        amount: 528.0,
      );

      // Lines provided intentionally out of order: [62, 44, 55]
      final order = OrderModel.create(
        sessionId: 14,
        lines: [line1, line2, line3],
        payments: [payment],
      );

      final payload = order.toOdooPayload();
      final odooLines = payload['lines'] as List<dynamic>;

      expect(odooLines.length, 3);
      final productIds = odooLines.map((cmd) => cmd[2]['product_id'] as int).toList();

      expect(productIds, [44, 55, 62],
          reason: 'Lines must be deterministically sorted ascending by productId');
    });
  });
}
