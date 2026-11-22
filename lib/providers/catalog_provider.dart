import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database_helper.dart';
import '../data/models/category_model.dart';
import '../data/models/product_model.dart';
import '../data/remote/odoo_catalog_service.dart';
import '../data/repositories/catalog_repository.dart';
import 'auth_provider.dart';

export '../data/repositories/catalog_repository.dart';

/// Result summary returned by [CatalogNotifier.loadCatalog].
class CatalogSyncResult {
  final bool success;
  final int productsCount;
  final int categoriesCount;
  final bool isFromCache;
  final String? errorMessage;

  const CatalogSyncResult({
    required this.success,
    this.productsCount = 0,
    this.categoriesCount = 0,
    this.isFromCache = false,
    this.errorMessage,
  });
}

/// State representation for catalog browsing, category filtering, and product searches.
class CatalogState {
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? searchQuery;
  final int? selectedCategoryId;
  final String? errorMessage;

  const CatalogState({
    this.products = const [],
    this.categories = const [],
    this.isLoading = false,
    this.searchQuery,
    this.selectedCategoryId,
    this.errorMessage,
  });

  /// Products filtered by active search query and selected category pill.
  List<ProductModel> get filteredProducts {
    final filtered = products.where((product) {
      // Category filter
      if (selectedCategoryId != null) {
        if (!product.posCategIds.contains(selectedCategoryId)) {
          return false;
        }
      }

      // Search filter (title, author, barcode, ISBN, default code)
      final query = (searchQuery ?? '').trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchTitle = product.name.toLowerCase().contains(query) ||
            product.displayName.toLowerCase().contains(query);
        final matchAuthor = product.bookAuthorsDisplay?.toLowerCase().contains(query) ?? false;
        final matchBarcode = product.barcode?.toLowerCase().contains(query) ?? false;
        final matchIsbn = (product.isbn?.toLowerCase().contains(query) ?? false) ||
            (product.isbn10?.toLowerCase().contains(query) ?? false);
        final matchCode = product.defaultCode?.toLowerCase().contains(query) ?? false;

        return matchTitle || matchAuthor || matchBarcode || matchIsbn || matchCode;
      }

      return true;
    }).toList();

    // Books prioritized first, then alphabetical by name
    filtered.sort((a, b) {
      if (a.isBook && !b.isBook) return -1;
      if (!a.isBook && b.isBook) return 1;
      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  CatalogState copyWith({
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    bool? isLoading,
    String? searchQuery,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? errorMessage,
  }) {
    return CatalogState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      errorMessage: errorMessage,
    );
  }
}

/// Provider for Odoo catalog remote service.
final catalogServiceProvider = Provider<OdooCatalogService>((ref) {
  final client = ref.watch(jsonRpcClientProvider);
  return OdooCatalogService(client: client);
});

/// Provider for DatabaseHelper.
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// State notifier managing catalog loading, local SQLite caching, search, and category selection.
class CatalogNotifier extends StateNotifier<CatalogState> {
  final CatalogRepository catalogRepository;

  CatalogNotifier({
    required this.catalogRepository,
  }) : super(const CatalogState());

  /// Loads catalog master data (products and categories).
  ///
  /// Offline-First: Immediately loads locally cached records if available,
  /// then fetches fresh records from Odoo backend when online.
  Future<CatalogSyncResult> loadCatalog({
    bool forceRefresh = false,
    bool isOffline = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // 1. Try local cache first for instant responsiveness
    final cachedProducts = await catalogRepository.getCachedProducts();
    final cachedCategories = await catalogRepository.getCachedCategories();

    if (cachedProducts.isNotEmpty) {
      state = state.copyWith(
        products: cachedProducts,
        categories: cachedCategories,
        isLoading: !isOffline,
      );
    }

    if (isOffline) {
      state = state.copyWith(isLoading: false);
      return CatalogSyncResult(
        success: true,
        productsCount: cachedProducts.length,
        categoriesCount: cachedCategories.length,
        isFromCache: true,
      );
    }

    // 2. Fetch fresh from Odoo 19
    try {
      final freshProducts = await catalogRepository.fetchRemoteProducts();
      final freshCategories = await catalogRepository.fetchRemoteCategories();

      // Persist to SQLite
      await catalogRepository.cacheProducts(freshProducts);
      await catalogRepository.cacheCategories(freshCategories);

      state = state.copyWith(
        products: freshProducts,
        categories: freshCategories,
        isLoading: false,
      );

      return CatalogSyncResult(
        success: true,
        productsCount: freshProducts.length,
        categoriesCount: freshCategories.length,
        isFromCache: false,
      );
    } catch (e) {
      final errorMsg = e.toString();
      // Record error message in state
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
      );

      return CatalogSyncResult(
        success: false,
        productsCount: state.products.length,
        categoriesCount: state.categories.length,
        isFromCache: cachedProducts.isNotEmpty,
        errorMessage: errorMsg,
      );
    }
  }

  /// Sets search query for instant client-side filtering.
  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Selects or clears category filter.
  void selectCategory(int? categoryId) {
    if (categoryId == null || state.selectedCategoryId == categoryId) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
  }

  /// Refreshes stock on hand for visible product templates using fast Odoo hook.
  Future<void> refreshStock(List<int> templateIds) async {
    if (templateIds.isEmpty) return;

    try {
      final stockMap = await catalogRepository.fetchStockOnHand(templateIds);
      if (stockMap.isNotEmpty) {
        final updatedProducts = state.products.map((p) {
          // If template ID matches
          final newStock = stockMap[p.id.toString()];
          if (newStock != null) {
            return p.copyWith(bookQtyOnHand: newStock);
          }
          return p;
        }).toList();

        state = state.copyWith(products: updatedProducts);
        await catalogRepository.cacheProducts(updatedProducts);
      }
    } catch (_) {}
  }
}

/// Global provider for Catalog state and actions.
final catalogProvider =
    StateNotifierProvider<CatalogNotifier, CatalogState>((ref) {
  final catalogRepository = ref.watch(catalogRepositoryProvider);
  return CatalogNotifier(
    catalogRepository: catalogRepository,
  );
});
