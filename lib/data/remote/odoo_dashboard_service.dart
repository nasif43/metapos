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
}
