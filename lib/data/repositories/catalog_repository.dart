import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_helper.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../remote/odoo_catalog_service.dart';
import '../../providers/catalog_provider.dart';

/// Repository interface for catalog operations, product caching, and search.
abstract class CatalogRepository {
  /// Loads products, optionally forcing a refresh from Odoo or restricting to local cache.
  Future<List<ProductModel>> getCatalog({bool forceRefresh = false, bool isOffline = false});

  /// Persists a list of products to the local SQLite database.
  Future<void> cacheProducts(List<ProductModel> products);

  /// Performs a client-side search across title, author, barcode, ISBN, and default code.
  Future<List<ProductModel>> searchProducts(String query);

  /// Loads categories from cache or remote Odoo backend.
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false, bool isOffline = false});

  /// Persists categories to the local SQLite database.
  Future<void> cacheCategories(List<CategoryModel> categories);

  /// Retrieves products currently stored in local SQLite cache.
  Future<List<ProductModel>> getCachedProducts();

  /// Retrieves categories currently stored in local SQLite cache.
  Future<List<CategoryModel>> getCachedCategories();

  /// Fetches fresh products directly from Odoo backend via JSON-RPC.
  Future<List<ProductModel>> fetchRemoteProducts();

  /// Fetches fresh categories directly from Odoo backend via JSON-RPC.
  Future<List<CategoryModel>> fetchRemoteCategories();

  /// Fetches live stock on hand for given product template IDs.
  Future<Map<String, int>> fetchStockOnHand(List<int> templateIds);
}

/// Concrete implementation of [CatalogRepository] encapsulating SQLite and Odoo JSON-RPC.
class CatalogRepositoryImpl implements CatalogRepository {
  final DatabaseHelper dbHelper;
  final OdooCatalogService catalogService;

  CatalogRepositoryImpl({
    required this.dbHelper,
    required this.catalogService,
  });

  @override
  Future<List<ProductModel>> getCatalog({
    bool forceRefresh = false,
    bool isOffline = false,
  }) async {
    if (!forceRefresh) {
      final cached = await dbHelper.getCachedProducts();
      if (cached.isNotEmpty) {
        if (isOffline) {
          return cached;
        }
      }
    }

    if (isOffline) {
      return await dbHelper.getCachedProducts();
    }

    try {
      final fresh = await catalogService.fetchProducts();
      await dbHelper.cacheProducts(fresh);
      return fresh;
    } catch (e) {
      final cached = await dbHelper.getCachedProducts();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<void> cacheProducts(List<ProductModel> products) async {
    await dbHelper.cacheProducts(products);
  }

  @override
  Future<List<ProductModel>> searchProducts(String query) async {
    final cached = await dbHelper.getCachedProducts();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return cached;
    return cached.where((product) {
      final matchTitle = product.name.toLowerCase().contains(q) ||
          product.displayName.toLowerCase().contains(q);
      final matchAuthor =
          product.bookAuthorsDisplay?.toLowerCase().contains(q) ?? false;
      final matchBarcode =
          product.barcode?.toLowerCase().contains(q) ?? false;
      final matchIsbn = (product.isbn?.toLowerCase().contains(q) ?? false) ||
          (product.isbn10?.toLowerCase().contains(q) ?? false);
      final matchCode =
          product.defaultCode?.toLowerCase().contains(q) ?? false;

      return matchTitle ||
          matchAuthor ||
          matchBarcode ||
          matchIsbn ||
          matchCode;
    }).toList();
  }

  @override
  Future<List<CategoryModel>> getCategories({
    bool forceRefresh = false,
    bool isOffline = false,
  }) async {
    if (!forceRefresh) {
      final cached = await dbHelper.getCachedCategories();
      if (cached.isNotEmpty && isOffline) {
        return cached;
      }
    }

    if (isOffline) {
      return await dbHelper.getCachedCategories();
    }

    try {
      final fresh = await catalogService.fetchCategories();
      await dbHelper.cacheCategories(fresh);
      return fresh;
    } catch (_) {
      final cached = await dbHelper.getCachedCategories();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    await dbHelper.cacheCategories(categories);
  }

  @override
  Future<List<ProductModel>> getCachedProducts() async {
    return await dbHelper.getCachedProducts();
  }

  @override
  Future<List<CategoryModel>> getCachedCategories() async {
    return await dbHelper.getCachedCategories();
  }

  @override
  Future<List<ProductModel>> fetchRemoteProducts() async {
    return await catalogService.fetchProducts();
  }

  @override
  Future<List<CategoryModel>> fetchRemoteCategories() async {
    return await catalogService.fetchCategories();
  }

  @override
  Future<Map<String, int>> fetchStockOnHand(List<int> templateIds) async {
    return await catalogService.fetchStockOnHand(templateIds);
  }
}

/// Global Riverpod provider for [CatalogRepository].
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final catalogService = ref.watch(catalogServiceProvider);
  return CatalogRepositoryImpl(
    dbHelper: dbHelper,
    catalogService: catalogService,
  );
});
