import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Line item for a POS order matching Odoo 19 `pos.order.line`.
class OrderLineModel {
  final int? id;
  final String uuid;
  final int productId;
  final String productName;
  final double qty;
  final double priceUnit;
  final double discount; // 0.0 to 100.0
  final double priceSubtotal;
  final double priceSubtotalIncl;
  final List<int> taxIds;
  final String? customerNote;
  final int? refundedOrderlineId;
  final double refundedQty;

  const OrderLineModel({
    this.id,
    required this.uuid,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.priceUnit,
    this.discount = 0.0,
    required this.priceSubtotal,
    required this.priceSubtotalIncl,
    this.taxIds = const [1],
    this.customerNote,
    this.refundedOrderlineId,
    this.refundedQty = 0.0,
  });

  /// Computed remaining refundable quantity on this line item.
  double get refundableQty => (qty - refundedQty).clamp(0.0, double.infinity);

  /// Helper factory to create line item with auto-generated UUID and calculations.
  factory OrderLineModel.create({
    int? id,
    required int productId,
    required String productName,
    required double qty,
    required double priceUnit,
    double discount = 0.0,
    List<int> taxIds = const [1],
    double taxRate = 0.10, // 10%
    bool isTaxInclusive = false,
    String? customerNote,
    String? uuid,
    int? refundedOrderlineId,
    double refundedQty = 0.0,
  }) {
    final effectiveUuid = uuid ?? const Uuid().v4();
    final discountFactor = 1.0 - (discount / 100.0);

    double computedPriceUnit = priceUnit;
    double computedSubtotal;
    double computedSubtotalIncl;

    if (isTaxInclusive) {
      // In MRP-Inclusive mode (reverse net tax calculation):
      // priceUnit is the printed gross MRP.
      // Net priceUnit = gross / (1 + taxRate)
      computedPriceUnit = double.parse((priceUnit / (1.0 + taxRate)).toStringAsFixed(4));
      computedSubtotal = double.parse(
          (computedPriceUnit * qty * discountFactor).toStringAsFixed(2));
      computedSubtotalIncl = double.parse(
          (priceUnit * qty * discountFactor).toStringAsFixed(2));
    } else {
      // Additive mode:
      computedPriceUnit = priceUnit;
      computedSubtotal = double.parse(
          (priceUnit * qty * discountFactor).toStringAsFixed(2));
      computedSubtotalIncl = double.parse(
          (computedSubtotal * (1.0 + taxRate)).toStringAsFixed(2));
    }

    return OrderLineModel(
      id: id,
      uuid: effectiveUuid,
      productId: productId,
      productName: productName,
      qty: qty,
      priceUnit: computedPriceUnit,
      discount: discount,
      priceSubtotal: computedSubtotal,
      priceSubtotalIncl: computedSubtotalIncl,
      taxIds: taxIds,
      customerNote: customerNote,
      refundedOrderlineId: refundedOrderlineId,
      refundedQty: refundedQty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'product_id': productId,
      'product_name': productName,
      'qty': qty,
      'price_unit': priceUnit,
      'discount': discount,
      'price_subtotal': priceSubtotal,
      'price_subtotal_incl': priceSubtotalIncl,
      'tax_ids': taxIds,
      'customer_note': customerNote,
      'refunded_orderline_id': refundedOrderlineId,
      'refunded_qty': refundedQty,
    };
  }

  factory OrderLineModel.fromJson(Map<String, dynamic> json) {
    // 1. tax_ids: [[6, 0, [int id, ...]]] vs [int id, ...]
    final List<int> parsedTaxIds = switch (json['tax_ids']) {
      [[6, _, final List<dynamic> ids], ...] => ids.whereType<num>().map((e) => e.toInt()).toList(),
      final List<dynamic> list => list.whereType<num>().map((e) => e.toInt()).toList(),
      _ => const [],
    };

    // 2. product_id: [int id, String name] vs int id vs null
    final (int parsedProductId, String? tupleProductName) = switch (json['product_id']) {
      [final num id, final String name, ...] => (id.toInt(), name),
      [final num id, ...] => (id.toInt(), null),
      final num id => (id.toInt(), null),
      _ => (0, null),
    };

    // 3. product_name: 4-way record pattern matching in order of precedence
    final String parsedProductName = switch ((
      json['product_name'],
      json['full_product_name'],
      json['name'],
      tupleProductName,
    )) {
      (final String s, _, _, _) when s.isNotEmpty => s,
      (_, final String s, _, _) when s.isNotEmpty => s,
      (_, _, final String s, _) when s.isNotEmpty => s,
      (_, _, _, final String s) when s.isNotEmpty => s,
      _ => '',
    };

    // 4. refunded_orderline_id: [int id, String name] vs int id vs false/null
    final int? parsedRefundedOrderlineId = switch (
        json['refunded_orderline_id'] ?? json['refundedOrderlineId']) {
      final num id => id.toInt(),
      [final num id, ...] => id.toInt(),
      _ => null,
    };

    final double parsedRefundedQty = switch (
        json['refunded_qty'] ?? json['refundedQty']) {
      final num q => q.toDouble(),
      _ => 0.0,
    };

    final int? parsedId = switch (json['id']) {
      final num id => id.toInt(),
      _ => null,
    };

    final String effectiveUuid = switch (json['uuid']) {
      final String u when u.isNotEmpty => u,
      _ => parsedId != null ? 'odoo-line-$parsedId' : const Uuid().v4(),
    };

    final String? parsedCustomerNote = switch (json['customer_note']) {
      final String note when note.isNotEmpty => note,
      _ => null,
    };

    return OrderLineModel(
      id: parsedId,
      uuid: effectiveUuid,
      productId: parsedProductId,
      productName: parsedProductName,
      qty: switch (json['qty']) {
        final num q => q.toDouble(),
        _ => 1.0,
      },
      priceUnit: switch (json['price_unit']) {
        final num p => p.toDouble(),
        _ => 0.0,
      },
      discount: switch (json['discount']) {
        final num d => d.toDouble(),
        _ => 0.0,
      },
      priceSubtotal: switch (json['price_subtotal']) {
        final num p => p.toDouble(),
        _ => 0.0,
      },
      priceSubtotalIncl: switch (json['price_subtotal_incl']) {
        final num p => p.toDouble(),
        _ => 0.0,
      },
      taxIds: parsedTaxIds,
      customerNote: parsedCustomerNote,
      refundedOrderlineId: parsedRefundedOrderlineId,
      refundedQty: parsedRefundedQty,
    );
  }

  OrderLineModel copyWith({
    int? id,
    String? uuid,
    int? productId,
    String? productName,
    double? qty,
    double? priceUnit,
    double? discount,
    double? priceSubtotal,
    double? priceSubtotalIncl,
    List<int>? taxIds,
    String? customerNote,
    int? refundedOrderlineId,
    double? refundedQty,
  }) {
    return OrderLineModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      qty: qty ?? this.qty,
      priceUnit: priceUnit ?? this.priceUnit,
      discount: discount ?? this.discount,
      priceSubtotal: priceSubtotal ?? this.priceSubtotal,
      priceSubtotalIncl: priceSubtotalIncl ?? this.priceSubtotalIncl,
      taxIds: taxIds ?? this.taxIds,
      customerNote: customerNote ?? this.customerNote,
      refundedOrderlineId: refundedOrderlineId ?? this.refundedOrderlineId,
      refundedQty: refundedQty ?? this.refundedQty,
    );
  }

  /// Converts to Odoo 19 one2many command tuple: `[0, 0, values]`.
  List<dynamic> toOdooCommand() {
    return [
      0,
      0,
      {
        'name': productName,
        'product_id': productId,
        'qty': qty,
        'price_unit': priceUnit,
        'discount': discount,
        'price_subtotal': priceSubtotal,
        'price_subtotal_incl': priceSubtotalIncl,
        'tax_ids': [
          [6, 0, taxIds]
        ],
        'customer_note': customerNote ?? false,
        'full_product_name': productName,
        'uuid': uuid,
        'refunded_orderline_id': refundedOrderlineId ?? false,
      }
    ];
  }
}

/// Payment tender line for an order matching Odoo 19 `pos.payment`.
class PaymentLineModel {
  final String uuid;
  final int paymentMethodId;
  final String? paymentMethodName;
  final double amount;
  final bool isChange;
  final String? name; // e.g. "ফেরত" for change return
  final DateTime? paymentDate;
  final int? sessionId;
  final String? paymentRefNo;
  final String? transactionId;
  final String? cardNo;
  final String? cardBrand;
  final String? authCode;

  const PaymentLineModel({
    required this.uuid,
    required this.paymentMethodId,
    this.paymentMethodName,
    required this.amount,
    this.isChange = false,
    this.name,
    this.paymentDate,
    this.sessionId,
    this.paymentRefNo,
    this.transactionId,
    this.cardNo,
    this.cardBrand,
    this.authCode,
  });

  /// Factory constructor to create payment line.
  factory PaymentLineModel.create({
    required int paymentMethodId,
    String? paymentMethodName,
    required double amount,
    bool isChange = false,
    String? name,
    int? sessionId,
    String? paymentRefNo,
    String? transactionId,
    String? cardNo,
    String? cardBrand,
    String? authCode,
    String? uuid,
  }) {
    return PaymentLineModel(
      uuid: uuid ?? const Uuid().v4(),
      paymentMethodId: paymentMethodId,
      paymentMethodName: paymentMethodName,
      amount: amount,
      isChange: isChange,
      name: isChange ? (name ?? 'ফেরত') : name,
      paymentDate: DateTime.now(),
      sessionId: sessionId,
      paymentRefNo: paymentRefNo,
      transactionId: transactionId,
      cardNo: cardNo,
      cardBrand: cardBrand,
      authCode: authCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'payment_method_id': paymentMethodId,
      'payment_method_name': paymentMethodName,
      'amount': amount,
      'is_change': isChange,
      'name': name,
      'payment_date': paymentDate?.toIso8601String(),
      'session_id': sessionId,
      'payment_ref_no': paymentRefNo,
      'transaction_id': transactionId,
      'card_no': cardNo,
      'card_brand': cardBrand,
      'auth_code': authCode,
    };
  }

  factory PaymentLineModel.fromJson(Map<String, dynamic> json) {
    final DateTime? date = switch (json['payment_date']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    };

    final (int parsedMethodId, String? tupleMethodName) = switch (json['payment_method_id']) {
      [final num id, final String name, ...] => (id.toInt(), name),
      [final num id, ...] => (id.toInt(), null),
      final num id => (id.toInt(), null),
      _ => (1, null),
    };

    final String? parsedMethodName = switch (json['payment_method_name'] ?? tupleMethodName) {
      final String s when s.isNotEmpty => s,
      _ => null,
    };

    final int? parsedSessionId = switch (json['session_id']) {
      final num id => id.toInt(),
      [final num id, ...] => id.toInt(),
      _ => null,
    };

    return PaymentLineModel(
      uuid: switch (json['uuid']) {
        final String u when u.isNotEmpty => u,
        _ => const Uuid().v4(),
      },
      paymentMethodId: parsedMethodId,
      paymentMethodName: parsedMethodName,
      amount: switch (json['amount']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      isChange: json['is_change'] == true,
      name: switch (json['name']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      paymentDate: date,
      sessionId: parsedSessionId,
      paymentRefNo: switch (json['payment_ref_no']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      transactionId: switch (json['transaction_id']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      cardNo: switch (json['card_no']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      cardBrand: switch (json['card_brand']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      authCode: switch (json['auth_code']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
    );
  }

  /// Converts to Odoo 19 one2many command tuple: `[0, 0, values]`.
  List<dynamic> toOdooCommand({int? fallbackSessionId}) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDate = dateFormat.format(paymentDate ?? DateTime.now());

    final Map<String, dynamic> vals = {
      'name': isChange ? (name ?? 'ফেরত') : (name ?? false),
      'payment_method_id': paymentMethodId,
      'amount': amount,
      'payment_date': formattedDate,
      'is_change': isChange,
      'session_id': sessionId ?? fallbackSessionId ?? 0,
      'uuid': uuid,
    };

    if (transactionId != null && transactionId!.isNotEmpty) {
      vals['transaction_id'] = transactionId;
    }
    if (paymentRefNo != null && paymentRefNo!.isNotEmpty) {
      vals['payment_ref_no'] = paymentRefNo;
    }
    if (cardNo != null && cardNo!.isNotEmpty) {
      vals['card_no'] = cardNo;
    }
    if (cardBrand != null && cardBrand!.isNotEmpty) {
      vals['card_brand'] = cardBrand;
    }
    if (authCode != null && authCode!.isNotEmpty) {
      vals['payment_method_authcode'] = authCode;
    }

    return [0, 0, vals];
  }
}

/// Order model matching Odoo 19 `pos.order` and `pos.order.sync_from_ui`.
class OrderModel {
  final int? id;
  final String uuid;
  final String posReference;
  final String ticketCode;
  final String trackingNumber;
  final int sessionId;
  final int? configId;
  final int? companyId;
  final int? userId;
  final int? partnerId;
  final double amountTotal;
  final double amountPaid;
  final double amountReturn;
  final double amountTax;
  final List<OrderLineModel> lines;
  final List<PaymentLineModel> payments;
  final DateTime createdAt;
  final DateTime? dateOrder;
  final String state;
  final bool toInvoice;
  final String? name;
  final int sequenceNumber;
  final String accessToken;
  final bool isSynced;
  final bool isRefund;
  final int? refundedOrderId;
  final bool hasRefundableLines;

  const OrderModel({
    this.id,
    required this.uuid,
    required this.posReference,
    required this.ticketCode,
    required this.trackingNumber,
    required this.sessionId,
    this.configId = 1,
    this.companyId = 1,
    this.userId = 2,
    this.partnerId,
    required this.amountTotal,
    required this.amountPaid,
    this.amountReturn = 0.0,
    required this.amountTax,
    required this.lines,
    required this.payments,
    required this.createdAt,
    this.dateOrder,
    this.state = 'paid',
    this.toInvoice = false,
    this.name,
    this.sequenceNumber = 1,
    required this.accessToken,
    this.isSynced = false,
    this.isRefund = false,
    this.refundedOrderId,
    this.hasRefundableLines = false,
  });

  /// Helper getter returning integer line IDs associated with this order.
  List<int> get lineIds => lines.map((l) => l.id).whereType<int>().toList();

  /// Factory to generate a new order with standard RFC 4122 v4 UUIDs and POS references.
  factory OrderModel.create({
    int? id,
    required int sessionId,
    int configId = 1,
    int companyId = 1,
    int userId = 2,
    int? partnerId,
    required List<OrderLineModel> lines,
    required List<PaymentLineModel> payments,
    int sequenceNumber = 1,
    String? posReference,
    String? ticketCode,
    String? trackingNumber,
    String? uuid,
    String? accessToken,
    DateTime? createdAt,
    bool isSynced = false,
    bool isRefund = false,
    int? refundedOrderId,
    bool hasRefundableLines = false,
    String? name,
  }) {
    final now = createdAt ?? DateTime.now();
    final effectiveUuid = uuid ?? const Uuid().v4();
    final effectiveAccessToken = accessToken ?? const Uuid().v4();

    // Year 2 digits + device + config + seq (e.g. 264-1-000008)
    final year2 = DateFormat('yy').format(now);
    final seqFormatted = sequenceNumber.toString().padLeft(6, '0');
    final effectivePosReference = posReference ??
        (isRefund
            ? 'RETURN-$year2$configId-$configId-$seqFormatted'
            : '$year2$configId-$configId-$seqFormatted');

    // 5-character alphanumeric ticket code (e.g. '0qfc5')
    final effectiveTicketCode = ticketCode ??
        effectiveUuid.replaceAll('-', '').substring(0, 5).toLowerCase();

    // 4-digit tracking number
    final effectiveTrackingNumber =
        trackingNumber ?? (4000 + sequenceNumber).toString();

    // Sum calculations from lines
    double total = 0.0;
    double tax = 0.0;
    for (final line in lines) {
      total += line.priceSubtotalIncl;
      tax += (line.priceSubtotalIncl - line.priceSubtotal);
    }
    total = double.parse(total.toStringAsFixed(2));
    tax = double.parse(tax.toStringAsFixed(2));

    // Calculate total payments & handle change
    double tenderSum = 0.0;
    for (final p in payments) {
      if (!p.isChange) {
        tenderSum += p.amount;
      }
    }
    tenderSum = double.parse(tenderSum.toStringAsFixed(2));

    final returnAmount = (!isRefund && tenderSum > total)
        ? double.parse((tenderSum - total).toStringAsFixed(2))
        : 0.0;

    final effectiveName = name ??
        (isRefund ? 'Order - $seqFormatted ফেরত' : 'Order - $seqFormatted');

    return OrderModel(
      id: id,
      uuid: effectiveUuid,
      posReference: effectivePosReference,
      ticketCode: effectiveTicketCode,
      trackingNumber: effectiveTrackingNumber,
      sessionId: sessionId,
      configId: configId,
      companyId: companyId,
      userId: userId,
      partnerId: partnerId,
      amountTotal: total,
      amountPaid: total,
      amountReturn: returnAmount,
      amountTax: tax,
      lines: lines,
      payments: payments,
      createdAt: now,
      dateOrder: now,
      state: 'paid',
      toInvoice: false,
      name: effectiveName,
      sequenceNumber: sequenceNumber,
      accessToken: effectiveAccessToken,
      isSynced: isSynced,
      isRefund: isRefund,
      refundedOrderId: refundedOrderId,
      hasRefundableLines: hasRefundableLines || lines.any((l) => l.refundableQty > 0),
    );
  }

  /// Builds the serialized payload structure for Odoo 19 `pos.order.sync_from_ui`.
  ///
  /// CRITICAL ODOO 19 SPEC RULES:
  /// 1. All payment entries in `payment_ids` must sum to `amount_paid` (== `amount_total`).
  ///    When tender > total (cash over-tender), a change line (`is_change: true`, name: "ফেরত",
  ///    amount: -change) MUST be included. For refund orders, NO change lines are added.
  /// 2. If [reverseNetTax] is true (MRP-inclusive retail standard), unit prices are
  ///    recomputed so that Odoo's additive 10% VAT equals the printed MRP cover price.
  Map<String, dynamic> toOdooPayload({bool reverseNetTax = false}) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDateOrder = dateFormat.format(dateOrder ?? createdAt);

    // Prepare lines (sorted deterministically by product_id ascending to prevent PostgreSQL deadlocks)
    final sortedLines = List<OrderLineModel>.from(lines)
      ..sort((a, b) => a.productId.compareTo(b.productId));

    final List<dynamic> odooLines = [];
    for (final line in sortedLines) {
      if (reverseNetTax) {
        // Reverse net calculation if not already calculated
        const taxRate = 0.10;
        final netUnit = double.parse((line.priceUnit / (1.0 + taxRate)).toStringAsFixed(4));
        final discountFactor = 1.0 - (line.discount / 100.0);
        final netSubtotal = double.parse((netUnit * line.qty * discountFactor).toStringAsFixed(2));
        final subtotalIncl = line.priceSubtotalIncl;

        odooLines.add([
          0,
          0,
          {
            'name': line.productName,
            'product_id': line.productId,
            'qty': line.qty,
            'price_unit': netUnit,
            'discount': line.discount,
            'price_subtotal': netSubtotal,
            'price_subtotal_incl': subtotalIncl,
            'tax_ids': [
              [6, 0, line.taxIds]
            ],
            'customer_note': line.customerNote ?? false,
            'full_product_name': line.productName,
            'uuid': line.uuid,
            'refunded_orderline_id': line.refundedOrderlineId ?? false,
          }
        ]);
      } else {
        odooLines.add(line.toOdooCommand());
      }
    }

    // Prepare payments & ensure change line is properly paired
    final List<dynamic> odooPayments = [];
    bool hasChangeLine = false;
    int? cashMethodId;

    for (final p in payments) {
      if (p.isChange) {
        hasChangeLine = true;
        if (isRefund) {
          // Do not send change lines for refund orders
          continue;
        }
      } else {
        cashMethodId = p.paymentMethodId;
      }
      odooPayments.add(p.toOdooCommand(fallbackSessionId: sessionId));
    }

    // If over-tender exists and no explicit change line was added, add change return line (sales only, NEVER on refunds!)
    if (!isRefund && !hasChangeLine && amountReturn > 0 && cashMethodId != null) {
      odooPayments.add([
        0,
        0,
        {
          'name': 'ফেরত',
          'payment_method_id': cashMethodId,
          'amount': -amountReturn,
          'payment_date': formattedDateOrder,
          'is_change': true,
          'session_id': sessionId,
          'uuid': const Uuid().v4(),
        }
      ]);
    }

    return {
      'name': name ?? 'Order - ${sequenceNumber.toString().padLeft(6, '0')}',
      'pos_reference': posReference,
      'sequence_number': sequenceNumber,
      'session_id': sessionId,
      'config_id': configId ?? 1,
      'company_id': companyId ?? 1,
      'user_id': userId ?? 2,
      'partner_id': partnerId ?? false,
      'date_order': formattedDateOrder,
      'amount_tax': amountTax,
      'amount_total': amountTotal,
      'amount_paid': isRefund ? amountTotal : amountPaid, // Odoo expects amount_paid == amount_total
      'amount_return': 0.0, // Odoo 19 sync_from_ui invariant: must be 0.0 (overpayment reconciled via balancing change lines)
      'state': state,
      'to_invoice': toInvoice,
      'uuid': uuid,
      'access_token': accessToken,
      'ticket_code': ticketCode,
      'tracking_number': trackingNumber,
      'is_refund': isRefund,
      'refunded_order_id': refundedOrderId ?? false,
      'lines': odooLines,
      'payment_ids': odooPayments,
    };
  }

  /// Converts order to JSON for SQLite `payload_json` and network serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'pos_reference': posReference,
      'ticket_code': ticketCode,
      'tracking_number': trackingNumber,
      'session_id': sessionId,
      'config_id': configId,
      'company_id': companyId,
      'user_id': userId,
      'partner_id': partnerId,
      'amount_total': amountTotal,
      'amount_paid': amountPaid,
      'amount_return': amountReturn,
      'amount_tax': amountTax,
      'lines': lines.map((l) => l.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'date_order': dateOrder?.toIso8601String(),
      'state': state,
      'to_invoice': toInvoice,
      'name': name,
      'sequence_number': sequenceNumber,
      'access_token': accessToken,
      'is_synced': isSynced,
      'is_refund': isRefund,
      'refunded_order_id': refundedOrderId,
      'has_refundable_lines': hasRefundableLines,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // 1. lines: Maps vs Odoo [0, 0, Map] command tuples vs integer stub IDs
    final List<OrderLineModel> parsedLines = switch (json['lines']) {
      final List<dynamic> rawList => [
          for (final item in rawList)
            switch (item) {
              final Map<String, dynamic> map => OrderLineModel.fromJson(map),
              final Map map => OrderLineModel.fromJson(Map<String, dynamic>.from(map)),
              [_, _, final Map map] => OrderLineModel.fromJson(Map<String, dynamic>.from(map)),
              final num lineId => OrderLineModel(
                  id: lineId.toInt(),
                  uuid: const Uuid().v4(),
                  productId: 0,
                  productName: '',
                  qty: 0.0,
                  priceUnit: 0.0,
                  priceSubtotal: 0.0,
                  priceSubtotalIncl: 0.0,
                ),
              _ => null,
            }
        ].whereType<OrderLineModel>().toList(),
      _ => const [],
    };

    // 2. payments: Maps vs Odoo [0, 0, Map] command tuples
    final List<PaymentLineModel> parsedPayments = switch (
        json['payments'] ?? json['payment_ids']) {
      final List<dynamic> rawList => [
          for (final item in rawList)
            switch (item) {
              final Map<String, dynamic> map => PaymentLineModel.fromJson(map),
              final Map map => PaymentLineModel.fromJson(Map<String, dynamic>.from(map)),
              [_, _, final Map map] => PaymentLineModel.fromJson(Map<String, dynamic>.from(map)),
              _ => null,
            }
        ].whereType<PaymentLineModel>().toList(),
      _ => const [],
    };

    final DateTime? parsedDateOrder = switch (json['date_order']) {
      final String d => DateTime.tryParse(d),
      _ => null,
    };

    final DateTime parsedCreatedAt = switch (json['created_at']) {
      final String c => DateTime.tryParse(c) ?? parsedDateOrder ?? DateTime.now(),
      _ => parsedDateOrder ?? DateTime.now(),
    };

    // 3. partner_id: [int id, String name] vs int id vs false/null
    final int? parsedPartnerId = switch (json['partner_id']) {
      final num id => id.toInt(),
      [final num id, ...] => id.toInt(),
      _ => null,
    };

    final bool parsedIsSynced = switch ((
      json['is_synced'],
      json['isSynced'],
      json['sync_status'],
    )) {
      (true, _, _) || (_, true, _) || (_, _, 'synced') => true,
      _ => false,
    };

    final int? parsedId = switch (json['id']) {
      final num id => id.toInt(),
      _ => null,
    };

    final bool parsedIsRefund = switch ((json['is_refund'], json['isRefund'])) {
      (true, _) || (_, true) => true,
      _ => false,
    };

    // 4. refunded_order_id: [int id, String name] vs int id vs false/null
    final int? parsedRefundedOrderId = switch (
        json['refunded_order_id'] ?? json['refundedOrderId']) {
      final num id => id.toInt(),
      [final num id, ...] => id.toInt(),
      _ => null,
    };

    final bool parsedHasRefundableLines = switch ((
      json['has_refundable_lines'],
      json['hasRefundableLines'],
    )) {
      (true, _) || (_, true) => true,
      _ => false,
    };

    // 5. session_id: [int id, String name] vs int id vs null
    final int parsedSessionId = switch (json['session_id']) {
      final num id => id.toInt(),
      [final num id, ...] => id.toInt(),
      _ => 1,
    };

    final String effectiveUuid = switch (json['uuid']) {
      final String u when u.isNotEmpty => u,
      _ => parsedId != null ? 'odoo-order-$parsedId' : const Uuid().v4(),
    };

    final String parsedPosReference = switch ((json['pos_reference'], json['name'])) {
      (final String ref, _) when ref.isNotEmpty => ref,
      (_, final String name) => name,
      _ => '',
    };

    return OrderModel(
      id: parsedId,
      uuid: effectiveUuid,
      posReference: parsedPosReference,
      ticketCode: switch (json['ticket_code']) {
        final String s => s,
        _ => '',
      },
      trackingNumber: switch (json['tracking_number']) {
        final String s => s,
        _ => '',
      },
      sessionId: parsedSessionId,
      configId: switch (json['config_id']) {
        final num id => id.toInt(),
        _ => 1,
      },
      companyId: switch (json['company_id']) {
        final num id => id.toInt(),
        _ => 1,
      },
      userId: switch (json['user_id']) {
        final num id => id.toInt(),
        _ => 2,
      },
      partnerId: parsedPartnerId,
      amountTotal: switch (json['amount_total']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      amountPaid: switch (json['amount_paid'] ?? json['amount_total']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      amountReturn: switch (json['amount_return']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      amountTax: switch (json['amount_tax']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      lines: parsedLines,
      payments: parsedPayments,
      createdAt: parsedCreatedAt,
      dateOrder: parsedDateOrder,
      state: switch (json['state']) {
        final String s => s,
        _ => 'paid',
      },
      toInvoice: json['to_invoice'] == true,
      name: switch (json['name']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      sequenceNumber: switch (json['sequence_number']) {
        final num s => s.toInt(),
        _ => 1,
      },
      accessToken: switch (json['access_token']) {
        final String s when s.isNotEmpty => s,
        _ => const Uuid().v4(),
      },
      isSynced: parsedIsSynced,
      isRefund: parsedIsRefund,
      refundedOrderId: parsedRefundedOrderId,
      hasRefundableLines: parsedHasRefundableLines,
    );
  }

  /// Converts order to row map for SQLite `local_orders` table.
  Map<String, dynamic> toMap({String? syncStatus, int retryCount = 0, String? lastError}) {
    final effectiveStatus = syncStatus ?? (isSynced ? 'synced' : 'pending');
    return {
      'id': id,
      'uuid': uuid,
      'pos_reference': posReference,
      'session_id': sessionId,
      'partner_id': partnerId,
      'amount_total': amountTotal,
      'payload_json': jsonEncode(toJson()),
      'sync_status': effectiveStatus,
      'retry_count': retryCount,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'synced_at': (effectiveStatus == 'synced' || isSynced) ? DateTime.now().toIso8601String() : null,
      'is_synced': (effectiveStatus == 'synced' || isSynced) ? 1 : 0,
      'is_refund': isRefund ? 1 : 0,
      'refunded_order_id': refundedOrderId,
    };
  }

  /// Factory constructor from SQLite `local_orders` row map.
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    if (map['payload_json'] case final String payload when payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        final order = OrderModel.fromJson(decoded);
        final bool synced = switch ((map['sync_status'], map['is_synced'], order.isSynced)) {
          ('synced', _, _) || (_, 1, _) || (_, true, _) || (_, _, true) => true,
          _ => false,
        };
        final bool isRefund = switch ((map['is_refund'], order.isRefund)) {
          (1, _) || (true, _) || (_, true) => true,
          _ => false,
        };
        final int? refundedOrderId = switch (map['refunded_order_id']) {
          final num id => id.toInt(),
          _ => order.refundedOrderId,
        };
        final int? parsedId = switch (map['id']) {
          final num id => id.toInt(),
          _ => order.id,
        };
        return order.copyWith(
          id: parsedId,
          isSynced: synced,
          isRefund: isRefund,
          refundedOrderId: refundedOrderId,
        );
      } catch (_) {}
    }

    final bool synced = switch ((map['sync_status'], map['is_synced'])) {
      ('synced', _) || (_, 1) || (_, true) => true,
      _ => false,
    };
    final bool refund = switch (map['is_refund']) {
      1 || true => true,
      _ => false,
    };
    final int? refundedOrderId = switch (map['refunded_order_id']) {
      final num id => id.toInt(),
      _ => null,
    };
    final int? parsedId = switch (map['id']) {
      final num id => id.toInt(),
      _ => null,
    };

    return OrderModel(
      id: parsedId,
      uuid: switch (map['uuid']) {
        final String u when u.isNotEmpty => u,
        _ => const Uuid().v4(),
      },
      posReference: switch (map['pos_reference']) {
        final String ref => ref,
        _ => '',
      },
      ticketCode: switch (map['ticket_code']) {
        final String s => s,
        _ => '',
      },
      trackingNumber: switch (map['tracking_number']) {
        final String s => s,
        _ => '',
      },
      sessionId: switch (map['session_id']) {
        final num id => id.toInt(),
        _ => 1,
      },
      configId: switch (map['config_id']) {
        final num id => id.toInt(),
        _ => 1,
      },
      companyId: switch (map['company_id']) {
        final num id => id.toInt(),
        _ => 1,
      },
      userId: switch (map['user_id']) {
        final num id => id.toInt(),
        _ => 2,
      },
      partnerId: switch (map['partner_id']) {
        final num id => id.toInt(),
        _ => null,
      },
      amountTotal: switch (map['amount_total']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      amountPaid: switch (map['amount_paid'] ?? map['amount_total']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      amountReturn: switch (map['amount_return']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      amountTax: switch (map['amount_tax']) {
        final num a => a.toDouble(),
        _ => 0.0,
      },
      lines: const [],
      payments: const [],
      createdAt: switch (map['created_at']) {
        final String c => DateTime.tryParse(c) ?? DateTime.now(),
        _ => DateTime.now(),
      },
      dateOrder: switch (map['date_order']) {
        final String d => DateTime.tryParse(d),
        _ => null,
      },
      state: switch (map['state']) {
        final String s => s,
        _ => 'paid',
      },
      toInvoice: map['to_invoice'] == 1 || map['to_invoice'] == true,
      name: switch (map['name']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
      sequenceNumber: switch (map['sequence_number']) {
        final num s => s.toInt(),
        _ => 1,
      },
      accessToken: switch (map['access_token']) {
        final String s when s.isNotEmpty => s,
        _ => const Uuid().v4(),
      },
      isSynced: synced,
      isRefund: refund,
      refundedOrderId: refundedOrderId,
    );
  }

  /// Creates a copy of this order with modified properties.
  OrderModel copyWith({
    int? id,
    String? uuid,
    String? posReference,
    String? ticketCode,
    String? trackingNumber,
    int? sessionId,
    int? configId,
    int? companyId,
    int? userId,
    int? partnerId,
    double? amountTotal,
    double? amountPaid,
    double? amountReturn,
    double? amountTax,
    List<OrderLineModel>? lines,
    List<PaymentLineModel>? payments,
    DateTime? createdAt,
    DateTime? dateOrder,
    String? state,
    bool? toInvoice,
    String? name,
    int? sequenceNumber,
    String? accessToken,
    bool? isSynced,
    bool? isRefund,
    int? refundedOrderId,
    bool? hasRefundableLines,
  }) {
    return OrderModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      posReference: posReference ?? this.posReference,
      ticketCode: ticketCode ?? this.ticketCode,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      sessionId: sessionId ?? this.sessionId,
      configId: configId ?? this.configId,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      partnerId: partnerId ?? this.partnerId,
      amountTotal: amountTotal ?? this.amountTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      amountReturn: amountReturn ?? this.amountReturn,
      amountTax: amountTax ?? this.amountTax,
      lines: lines ?? this.lines,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      dateOrder: dateOrder ?? this.dateOrder,
      state: state ?? this.state,
      toInvoice: toInvoice ?? this.toInvoice,
      name: name ?? this.name,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      accessToken: accessToken ?? this.accessToken,
      isSynced: isSynced ?? this.isSynced,
      isRefund: isRefund ?? this.isRefund,
      refundedOrderId: refundedOrderId ?? this.refundedOrderId,
      hasRefundableLines: hasRefundableLines ?? this.hasRefundableLines,
    );
  }

  /// Re-binds this order to a new session (used in offline sync recovery).
  OrderModel copyWithSession(int newSessionId) {
    return copyWith(
      sessionId: newSessionId,
      payments: payments
          .map((p) => PaymentLineModel(
                uuid: p.uuid,
                paymentMethodId: p.paymentMethodId,
                paymentMethodName: p.paymentMethodName,
                amount: p.amount,
                isChange: p.isChange,
                name: p.name,
                paymentDate: p.paymentDate,
                sessionId: newSessionId,
                paymentRefNo: p.paymentRefNo,
                transactionId: p.transactionId,
                cardNo: p.cardNo,
                cardBrand: p.cardBrand,
                authCode: p.authCode,
              ))
          .toList(),
    );
  }
}
