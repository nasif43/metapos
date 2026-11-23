import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database_helper.dart';
import '../data/models/partner_model.dart';
import '../data/remote/odoo_partner_service.dart';
import 'auth_provider.dart';
import 'catalog_provider.dart';

/// State representation for customer lookup, selection, and creation.
class CustomerState {
  final List<PartnerModel> customers;
  final PartnerModel? selectedCustomer;
  final bool isLoading;
  final String? searchQuery;
  final String? errorMessage;
  final DateTime? lastFetched;

  const CustomerState({
    this.customers = const [],
    this.selectedCustomer,
    this.isLoading = false,
    this.searchQuery,
    this.errorMessage,
    this.lastFetched,
  });

  CustomerState copyWith({
    List<PartnerModel>? customers,
    PartnerModel? selectedCustomer,
    bool clearSelection = false,
    bool? isLoading,
    String? searchQuery,
    String? errorMessage,
    DateTime? lastFetched,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      selectedCustomer:
          clearSelection ? null : (selectedCustomer ?? this.selectedCustomer),
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

/// Provider for Odoo partner remote service.
final partnerServiceProvider = Provider<OdooPartnerService>((ref) {
  final client = ref.watch(jsonRpcClientProvider);
  return OdooPartnerService(client: client);
});

/// State notifier managing customer searches and quick customer creation.
class CustomerNotifier extends StateNotifier<CustomerState> {
  final OdooPartnerService partnerService;
  final DatabaseHelper dbHelper;

  CustomerNotifier({
    required this.partnerService,
    required this.dbHelper,
  }) : super(const CustomerState());

  /// Searches customers by phone, name, or barcode.
  Future<void> searchCustomers(
    String query, {
    bool isOffline = false,
  }) async {
    // Optimization: If initial empty query was recently fetched (< 5 mins), reuse cached data
    if (query.isEmpty &&
        state.customers.isNotEmpty &&
        state.lastFetched != null) {
      final elapsed = DateTime.now().difference(state.lastFetched!);
      if (elapsed < const Duration(minutes: 5)) {
        return;
      }
    }

    state = state.copyWith(isLoading: true, searchQuery: query, errorMessage: null);

    // Try local database first
    final localMatches = await dbHelper.getCachedPartners(search: query);
    if (localMatches.isNotEmpty) {
      state = state.copyWith(customers: localMatches, isLoading: !isOffline);
    }

    if (isOffline) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final remoteMatches = await partnerService.searchPartners(query);
      if (remoteMatches.isNotEmpty) {
        await dbHelper.cachePartners(remoteMatches);
      }
      state = state.copyWith(
        customers: remoteMatches,
        isLoading: false,
        lastFetched: query.isEmpty ? DateTime.now() : state.lastFetched,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: localMatches.isEmpty ? e.toString() : null,
      );
    }
  }

  /// Creates a new customer record via `res.partner.create`.
  Future<PartnerModel?> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? street,
    String? city,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final newId = await partnerService.createPartner(
        name: name,
        phone: phone,
        email: email,
        street: street,
        city: city,
      );

      final newCustomer = PartnerModel(
        id: newId,
        name: name,
        phone: phone,
        email: email,
        street: street,
        city: city,
      );

      await dbHelper.cachePartners([newCustomer]);

      state = state.copyWith(
        selectedCustomer: newCustomer,
        customers: [newCustomer, ...state.customers],
        isLoading: false,
      );

      return newCustomer;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Selects customer for active order.
  void selectCustomer(PartnerModel? customer) {
    if (customer == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  /// Clears active customer selection.
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }
}

/// Global provider for Customer state and actions.
final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  final partnerService = ref.watch(partnerServiceProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  return CustomerNotifier(
    partnerService: partnerService,
    dbHelper: dbHelper,
  );
});
