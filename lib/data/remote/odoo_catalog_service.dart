import '../models/category_model.dart';
import '../models/product_model.dart';
import 'json_rpc_client.dart';

/// Remote service managing product catalog, stock counts, categories, and taxes from Odoo 19.
class OdooCatalogService {
  final OdooJsonRpcClient client;

  OdooCatalogService({required this.client});

  /// Fetches products available in POS from `product.product`.
  Future<List<ProductModel>> fetchProducts({
    int limit = 500,
    int offset = 0,
    List<dynamic> additionalDomain = const [],
  }) async {
    final domain = [
      ['available_in_pos', '=', true],
      ...additionalDomain,
    ];

    final fields = [
      'id',
      'name',
      'display_name',
      'barcode',
      'default_code',
      'list_price',
      'pos_categ_ids',
      'taxes_id',
      'is_book',
      'isbn',
      'isbn10',
      'book_authors_display',
      'book_publisher_name',
      'book_genre_name',
      'book_qty_on_hand',
      'book_edition',
      'book_format',
      'book_publication_year',
      'publisher_id',
      'image_256',
      'image_128',
    ];

    final result = await client.executeCall(
      'product.product',
      'search_read',
      [domain],
      {
        'fields': fields,
        'limit': limit,
        'offset': offset,
      },
    );

    if (result is List) {
      return result
          .whereType<Map<String, dynamic>>()
          .map((json) => ProductModel.fromJson(json))
          .toList();
    }
    return [];
  }

  /// Fast stock on hand lookup directly from `product.template.book_read_qty_on_hand`.
  ///
  /// Returns a map of template ID strings to current available integer quantities.
  Future<Map<String, int>> fetchStockOnHand(List<int> templateIds) async {
    if (templateIds.isEmpty) return {};

    final result = await client.executeCall(
      'product.template',
      'book_read_qty_on_hand',
      [templateIds],
      {},
    );

    final Map<String, int> stockMap = {};
    if (result is Map) {
      result.forEach((key, value) {
        if (value is num) {
          stockMap[key.toString()] = value.toInt();
        }
      });
    }
    return stockMap;
  }

  /// Fetches POS category tree from `pos.category`.
  Future<List<CategoryModel>> fetchCategories() async {
    final fields = ['id', 'name', 'parent_id', 'child_ids', 'sequence'];

    final result = await client.executeCall(
      'pos.category',
      'search_read',
      [[]],
      {'fields': fields},
    );

    if (result is List) {
      return result
          .whereType<Map<String, dynamic>>()
          .map((json) => CategoryModel.fromJson(json))
          .toList();
    }
    return [];
  }

  /// Fetches taxes configuration from `account.tax`.
  Future<List<Map<String, dynamic>>> fetchTaxes() async {
    final fields = ['id', 'name', 'amount', 'amount_type', 'price_include'];

    final result = await client.executeCall(
      'account.tax',
      'search_read',
      [[]],
      {'fields': fields},
    );

    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Fetches active payment methods from `pos.payment.method`.
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    final fields = ['id', 'name', 'is_cash_count', 'type'];

    final result = await client.executeCall(
      'pos.payment.method',
      'search_read',
      [[]],
      {'fields': fields},
    );

    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Calls unified Odoo 19 `pos.session.load_data` endpoint returning all POS datasets.
  Future<Map<String, dynamic>> loadData(int sessionId) async {
    final result = await client.executeCall(
      'pos.session',
      'load_data',
      [
        [sessionId],
        []
      ],
      {},
    );

    if (result is Map<String, dynamic>) {
      return result;
    }
    return {};
  }
}
