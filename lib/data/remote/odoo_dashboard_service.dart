import '../models/dashboard_model.dart';
import 'json_rpc_client.dart';

/// Remote service for retrieving real-time POS dashboard analytics from Odoo 19 `book.fair.dashboard`.
class OdooDashboardService {
  final OdooJsonRpcClient client;

  OdooDashboardService({required this.client});

  /// Fetches live dashboard KPIs, hourly histogram buckets, and sales metrics.
  Future<DashboardModel> fetchDashboardData({
    String? dateFrom,
    String? dateTo,
  }) async {
    final Map<String, dynamic> kwargs = {};
    if (dateFrom != null) kwargs['date_from'] = dateFrom;
    if (dateTo != null) kwargs['date_to'] = dateTo;

    final result = await client.executeCall(
      'book.fair.dashboard',
      'get_dashboard_data',
      [],
      kwargs,
    );

    if (result is Map<String, dynamic>) {
      return DashboardModel.fromJson(result);
    }
    return DashboardModel.empty();
  }

  /// Calls Odoo 19 native `report.point_of_sale.report_saledetails.get_sale_details`
  /// to fetch real-time session sales figures, payment methods, and product totals.
  Future<Map<String, dynamic>> fetchSessionSaleDetails(int sessionId) async {
    try {
      final result = await client.executeCall(
        'report.point_of_sale.report_saledetails',
        'get_sale_details',
        [],
        {'session_ids': [sessionId]},
      );
      if (result is Map<String, dynamic>) {
        return result;
      }
    } catch (_) {
      // Return empty map on network or RPC errors
    }
    return {};
  }
}
