import '../models/order_model.dart';
import 'json_rpc_client.dart';

/// Remote service handling order synchronization with Odoo 19 via `pos.order.sync_from_ui`.
class OdooOrderService {
  final OdooJsonRpcClient client;

  OdooOrderService({required this.client});

  /// Synchronizes a batch of orders with Odoo 19 `pos.order.sync_from_ui`.
  ///
  /// Features:
  /// - Client-generated RFC 4122 v4 UUIDs provide automatic idempotency.
  /// - Automatic cash over-tender change line balancing (`is_change: true`, name: "ফেরত").
  /// - Dual tax pricing calculations (supports [reverseNetTax] for MRP-inclusive retail).
  Future<Map<String, dynamic>> syncFromUi(
    List<OrderModel> orders, {
    bool reverseNetTax = false,
  }) async {
    if (orders.isEmpty) return {};

    final payload = orders
        .map((order) => order.toOdooPayload(reverseNetTax: reverseNetTax))
        .toList();

    final result = await client.executeCall(
      'pos.order',
      'sync_from_ui',
      [payload],
      {},
    );

    if (result is Map<String, dynamic>) {
      return result;
    }
    return {'result': result};
  }

  /// Synchronizes a single order with Odoo 19.
  Future<Map<String, dynamic>> syncSingleOrder(
    OrderModel order, {
    bool reverseNetTax = false,
  }) async {
    return await syncFromUi([order], reverseNetTax: reverseNetTax);
  }

  /// Searches past POS orders from Odoo 19 matching receipt reference, name, ticket code, or tracking number.
  Future<List<OrderModel>> searchPastOrders(
    String query, {
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    final List<dynamic> domain;
    if (trimmed.isEmpty) {
      domain = [
        ['state', 'in', ['paid', 'done', 'invoiced']],
      ];
    } else {
      domain = [
        '|',
        '|',
        '|',
        ['pos_reference', 'ilike', trimmed],
        ['name', 'ilike', trimmed],
        ['ticket_code', 'ilike', trimmed],
        ['tracking_number', 'ilike', trimmed],
        ['state', 'in', ['paid', 'done', 'invoiced']],
      ];
    }

    final fields = [
      'id',
      'name',
      'pos_reference',
      'date_order',
      'partner_id',
      'amount_total',
      'amount_paid',
      'amount_tax',
      'is_refund',
      'refunded_order_id',
      'has_refundable_lines',
      'refund_orders_count',
      'lines',
      'ticket_code',
      'tracking_number',
      'session_id',
    ];

    final result = await client.executeCall(
      'pos.order',
      'search_read',
      [domain],
      {
        'fields': fields,
        'limit': limit,
        'order': 'date_order desc',
      },
    );

    if (result is List) {
      return result
          .whereType<Map<String, dynamic>>()
          .map((json) => OrderModel.fromJson(json))
          .toList();
    }
    return [];
  }

  /// Fetches order line details by line IDs from Odoo 19 `pos.order.line`.
  Future<List<OrderLineModel>> fetchOrderLines(List<int> lineIds) async {
    if (lineIds.isEmpty) return [];

    final fields = [
      'id',
      'product_id',
      'full_product_name',
      'qty',
      'price_unit',
      'discount',
      'price_subtotal',
      'price_subtotal_incl',
      'tax_ids',
      'refunded_qty',
      'refund_orderline_ids',
      'refunded_orderline_id',
    ];

    final result = await client.executeCall(
      'pos.order.line',
      'read',
      [lineIds],
      {
        'fields': fields,
      },
    );

    if (result is List) {
      return result
          .whereType<Map<String, dynamic>>()
          .map((json) => OrderLineModel.fromJson(json))
          .toList();
    }
    return [];
  }
}
