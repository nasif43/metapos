import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/dashboard_model.dart';
import '../data/remote/odoo_dashboard_service.dart';
import 'auth_provider.dart';

/// State representation for live POS dashboard metrics.
class DashboardState {
  final DashboardModel data;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastFetched;

  const DashboardState({
    required this.data,
    this.isLoading = false,
    this.errorMessage,
    this.lastFetched,
  });

  DashboardState copyWith({
    DashboardModel? data,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastFetched,
  }) {
    return DashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

/// Provider for remote Odoo dashboard service.
final dashboardServiceProvider = Provider<OdooDashboardService>((ref) {
  final client = ref.watch(jsonRpcClientProvider);
  return OdooDashboardService(client: client);
});

/// State notifier managing live POS dashboard KPIs and histogram telemetry.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final OdooDashboardService dashboardService;

  DashboardNotifier({required this.dashboardService})
      : super(DashboardState(data: DashboardModel.empty())) {
    fetchDashboard();
  }

  /// Fetches live dashboard data from Odoo 19 backend.
  Future<void> fetchDashboard({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final dashboard = await dashboardService.fetchDashboardData();
      state = state.copyWith(
        data: dashboard,
        isLoading: false,
        lastFetched: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Main dashboard provider.
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final service = ref.watch(dashboardServiceProvider);
  return DashboardNotifier(dashboardService: service);
});
