import 'dart:convert';

/// Product model representing Odoo 19 `product.product` with Book Fair extensions.
class ProductModel {
  final int id;
  final String name;
  final String displayName;
  final String? barcode;
  final String? defaultCode;
  final double listPrice;
  final List<int> posCategIds;
  final List<int> taxesId;
  final bool isBook;
  final String? isbn;
  final String? isbn10;
  final String? bookAuthorsDisplay;
  final String? bookPublisherName;
  final String? bookGenreName;
  final int bookQtyOnHand;
  final String? bookEdition;
  final String? bookFormat;
  final int? bookPublicationYear;
  final int? publisherId;
  final String? image128;

  const ProductModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.barcode,
    this.defaultCode,
    required this.listPrice,
    this.posCategIds = const [],
    this.taxesId = const [],
    this.isBook = false,
    this.isbn,
    this.isbn10,
    this.bookAuthorsDisplay,
    this.bookPublisherName,
    this.bookGenreName,
    this.bookQtyOnHand = 0,
    this.bookEdition,
    this.bookFormat,
    this.bookPublicationYear,
    this.publisherId,
    this.image128,
  });

  /// Factory constructor from Odoo 19 JSON-RPC `search_read` record.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<int> parsedPosCategIds = [];
    final categs = json['pos_categ_ids'];
    if (categs is List) {
      parsedPosCategIds = categs.whereType<int>().toList();
    }

    List<int> parsedTaxesId = [];
    final taxes = json['taxes_id'];
    if (taxes is List) {
      parsedTaxesId = taxes.whereType<int>().toList();
    }

    int? parsedPublisherId;
    final pub = json['publisher_id'];
    if (pub is List && pub.isNotEmpty) {
      parsedPublisherId = (pub[0] as num).toInt();
    } else if (pub is num) {
      parsedPublisherId = pub.toInt();
    }

    return ProductModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      displayName: (json['display_name'] ?? json['name'] ?? '') as String,
      barcode: json['barcode'] is String ? json['barcode'] as String : null,
      defaultCode:
          json['default_code'] is String ? json['default_code'] as String : null,
      listPrice: (json['list_price'] as num?)?.toDouble() ?? 0.0,
      posCategIds: parsedPosCategIds,
      taxesId: parsedTaxesId,
      isBook: json['is_book'] == true,
      isbn: json['isbn'] is String ? json['isbn'] as String : null,
      isbn10: json['isbn10'] is String ? json['isbn10'] as String : null,
      bookAuthorsDisplay: json['book_authors_display'] is String
          ? json['book_authors_display'] as String
          : null,
      bookPublisherName: json['book_publisher_name'] is String
          ? json['book_publisher_name'] as String
          : null,
      bookGenreName: json['book_genre_name'] is String
          ? json['book_genre_name'] as String
          : null,
      bookQtyOnHand: (json['book_qty_on_hand'] as num?)?.toInt() ?? 0,
      bookEdition: json['book_edition'] is String
          ? json['book_edition'] as String
          : null,
      bookFormat: json['book_format'] is String
          ? json['book_format'] as String
          : null,
      bookPublicationYear: (json['book_publication_year'] as num?)?.toInt(),
      publisherId: parsedPublisherId,
      image128: (json['image_256'] is String && (json['image_256'] as String).isNotEmpty)
          ? json['image_256'] as String
          : (json['image_128'] is String && (json['image_128'] as String).isNotEmpty)
              ? json['image_128'] as String
              : null,
    );
  }

  /// Converts model to standard JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'barcode': barcode,
      'default_code': defaultCode,
      'list_price': listPrice,
      'pos_categ_ids': posCategIds,
      'taxes_id': taxesId,
      'is_book': isBook,
      'isbn': isbn,
      'isbn10': isbn10,
      'book_authors_display': bookAuthorsDisplay,
      'book_publisher_name': bookPublisherName,
      'book_genre_name': bookGenreName,
      'book_qty_on_hand': bookQtyOnHand,
      'book_edition': bookEdition,
      'book_format': bookFormat,
      'book_publication_year': bookPublicationYear,
      'publisher_id': publisherId,
      'image_128': image128,
    };
  }

  /// Factory constructor from SQLite `cached_products` table row.
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    List<int> parsedPosCategIds = [];
    final rawCategs = map['pos_categ_ids'] ?? map['category_id'];
    if (rawCategs is String && rawCategs.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCategs);
        if (decoded is List) {
          parsedPosCategIds = decoded.whereType<int>().toList();
        }
      } catch (_) {
        parsedPosCategIds = [];
      }
    } else if (rawCategs is num) {
      parsedPosCategIds = [rawCategs.toInt()];
    }

    List<int> parsedTaxesId = [];
    final rawTaxes = map['taxes_id'];
    if (rawTaxes is String && rawTaxes.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTaxes);
        if (decoded is List) {
          parsedTaxesId = decoded.whereType<int>().toList();
        }
      } catch (_) {
        parsedTaxesId = [];
      }
    }

    final double price = (map['list_price'] as num?)?.toDouble() ??
        (map['price'] as num?)?.toDouble() ??
        0.0;

    final int qty = (map['book_qty_on_hand'] as num?)?.toInt() ??
        (map['stock_qty'] as num?)?.toInt() ??
        0;

    final String? authors = map['book_authors_display'] as String? ??
        map['authors'] as String?;

    final String? publisher = map['book_publisher_name'] as String? ??
        map['publisher'] as String?;

    final String? genre = map['book_genre_name'] as String? ??
        map['genre'] as String?;

    return ProductModel(
      id: map['id'] as int,
      name: (map['name'] ?? '') as String,
      displayName: (map['display_name'] ?? map['name'] ?? '') as String,
      barcode: map['barcode'] as String?,
      defaultCode: map['default_code'] as String?,
      listPrice: price,
      posCategIds: parsedPosCategIds,
      taxesId: parsedTaxesId,
      isBook: (map['is_book'] == 1 || map['is_book'] == true),
      isbn: map['isbn'] as String?,
      isbn10: map['isbn10'] as String?,
      bookAuthorsDisplay: authors,
      bookPublisherName: publisher,
      bookGenreName: genre,
      bookQtyOnHand: qty,
      bookEdition: map['book_edition'] as String?,
      bookFormat: map['book_format'] as String?,
      bookPublicationYear: (map['book_publication_year'] as num?)?.toInt(),
      publisherId: (map['publisher_id'] as num?)?.toInt(),
      image128: (map['image_128'] is String && (map['image_128'] as String).isNotEmpty)
          ? map['image_128'] as String
          : null,
    );
  }

  /// Converts model to SQLite `cached_products` table row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'barcode': barcode,
      'default_code': defaultCode,
      'list_price': listPrice,
      'price': listPrice,
      'pos_categ_ids': jsonEncode(posCategIds),
      'category_id': posCategIds.isNotEmpty ? posCategIds.first : null,
      'taxes_id': jsonEncode(taxesId),
      'is_book': isBook ? 1 : 0,
      'isbn': isbn,
      'isbn10': isbn10,
      'book_authors_display': bookAuthorsDisplay,
      'authors': bookAuthorsDisplay,
      'book_publisher_name': bookPublisherName,
      'publisher': bookPublisherName,
      'book_genre_name': bookGenreName,
      'genre': bookGenreName,
      'book_qty_on_hand': bookQtyOnHand,
      'stock_qty': bookQtyOnHand,
      'book_edition': bookEdition,
      'book_format': bookFormat,
      'book_publication_year': bookPublicationYear,
      'publisher_id': publisherId,
      'image_128': image128,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? displayName,
    String? barcode,
    String? defaultCode,
    double? listPrice,
    List<int>? posCategIds,
    List<int>? taxesId,
    bool? isBook,
    String? isbn,
    String? isbn10,
    String? bookAuthorsDisplay,
    String? bookPublisherName,
    String? bookGenreName,
    int? bookQtyOnHand,
    String? bookEdition,
    String? bookFormat,
    int? bookPublicationYear,
    int? publisherId,
    String? image128,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      barcode: barcode ?? this.barcode,
      defaultCode: defaultCode ?? this.defaultCode,
      listPrice: listPrice ?? this.listPrice,
      posCategIds: posCategIds ?? this.posCategIds,
      taxesId: taxesId ?? this.taxesId,
      isBook: isBook ?? this.isBook,
      isbn: isbn ?? this.isbn,
      isbn10: isbn10 ?? this.isbn10,
      bookAuthorsDisplay: bookAuthorsDisplay ?? this.bookAuthorsDisplay,
      bookPublisherName: bookPublisherName ?? this.bookPublisherName,
      bookGenreName: bookGenreName ?? this.bookGenreName,
      bookQtyOnHand: bookQtyOnHand ?? this.bookQtyOnHand,
      bookEdition: bookEdition ?? this.bookEdition,
      bookFormat: bookFormat ?? this.bookFormat,
      bookPublicationYear: bookPublicationYear ?? this.bookPublicationYear,
      publisherId: publisherId ?? this.publisherId,
      image128: image128 ?? this.image128,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          barcode == other.barcode &&
          listPrice == other.listPrice &&
          bookQtyOnHand == other.bookQtyOnHand &&
          image128 == other.image128;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      (barcode?.hashCode ?? 0) ^
      listPrice.hashCode ^
      bookQtyOnHand.hashCode ^
      (image128?.hashCode ?? 0);

  @override
  String toString() =>
      'ProductModel(id: $id, name: $name, price: $listPrice, stock: $bookQtyOnHand, hasImage: ${image128 != null})';
}
