import '../models/partner_model.dart';
import 'json_rpc_client.dart';

/// Remote service managing customer searches and quick customer creation in Odoo 19 `res.partner`.
class OdooPartnerService {
  final OdooJsonRpcClient client;

  OdooPartnerService({required this.client});

  /// Searches customers by name, phone, or barcode.
  ///
  /// CRITICAL ODOO 19 SCHEMA RULE:
  /// Do NOT query or reference the `mobile` field. In Odoo 19, mobile numbers
  /// are unified into `phone`.
  Future<List<PartnerModel>> searchPartners(String query, {int limit = 50}) async {
    final cleanQuery = query.trim();
    final List<dynamic> domain;

    if (cleanQuery.isEmpty) {
      domain = [
        ['customer_rank', '>', 0]
      ];
    } else {
      domain = [
        ['customer_rank', '>', 0],
        '|',
        '|',
        ['name', 'ilike', cleanQuery],
        ['phone', 'ilike', cleanQuery],
        ['barcode', '=', cleanQuery],
      ];
    }

    final fields = [
      'id',
      'name',
      'phone',
      'email',
      'street',
      'city',
      'barcode',
    ];

    final result = await client.executeCall(
      'res.partner',
      'search_read',
      [domain],
      {
        'fields': fields,
        'limit': limit,
      },
    );

    if (result is List) {
      return result
          .whereType<Map<String, dynamic>>()
          .map((json) => PartnerModel.fromJson(json))
          .toList();
    }
    return [];
  }

  /// Creates a new customer record via `res.partner.create`.
  ///
  /// Always assigns `customer_rank: 1` and uses `phone` instead of `mobile`.
  /// Returns the newly created partner ID.
  Future<int> createPartner({
    required String name,
    required String phone,
    String? email,
    String? street,
    String? city,
  }) async {
    final Map<String, dynamic> vals = {
      'name': name.trim(),
      'phone': phone.trim(),
      'customer_rank': 1,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
    };

    final result = await client.executeCall(
      'res.partner',
      'create',
      [vals],
      {},
    );

    if (result is int) {
      return result;
    } else if (result is List && result.isNotEmpty && result.first is int) {
      return result.first as int;
    }
    throw OdooServerException(message: 'Unexpected result from partner create: $result');
  }
}
