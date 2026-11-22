import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/category_model.dart';
import '../models/partner_model.dart';
import '../models/product_model.dart';

/// Database helper managing SQLite persistence for cached master data and offline orders.
class DatabaseHelper {
  static const int currentDatabaseVersion = 4;
  static DatabaseHelper? _instance;
  static Database? _database;

  final String? customDbPath;
  final int? _schemaVersion;

  DatabaseHelper._internal({this.customDbPath, int? versionOverride})
      : _schemaVersion = versionOverride;

  /// Factory constructor returning singleton or custom-pathed helper (for tests).
  factory DatabaseHelper({String? customDbPath, int? schemaVersion}) {
    if (customDbPath != null || schemaVersion != null) {
      return DatabaseHelper._internal(
        customDbPath: customDbPath,
        versionOverride: schemaVersion,
      );
    }
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Initializes SQLite FFI if running in unit tests or on desktop platforms.
  static void initializeFfi() {
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Returns active SQLite database instance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    initializeFfi();

    String path;
    if (customDbPath != null) {
      path = customDbPath!;
    } else if (kIsWeb) {
      path = 'metapos.db';
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final docDir = await getApplicationDocumentsDirectory();
      path = join(docDir.path, 'metapos.db');
    } else {
      path = join(await getDatabasesPath(), 'metapos.db');
    }

    final version = _schemaVersion ?? currentDatabaseVersion;

    return await openDatabase(
      path,
      version: version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE cached_products ADD COLUMN book_edition TEXT');
      await db.execute('ALTER TABLE cached_products ADD COLUMN book_format TEXT');
      await db.execute('ALTER TABLE cached_products ADD COLUMN book_publication_year INTEGER');
      await db.execute('ALTER TABLE cached_products ADD COLUMN publisher_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE cached_products ADD COLUMN image_128 TEXT');
    }
    if (oldVersion < 4) {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='local_orders'",
      );
      if (tables.isNotEmpty) {
        final columns = await db.rawQuery("PRAGMA table_info('local_orders')");
        final columnNames = columns.map((c) => c['name'] as String).toSet();
        if (!columnNames.contains('is_refund')) {
          await db.execute('ALTER TABLE local_orders ADD COLUMN is_refund INTEGER DEFAULT 0');
        }
        if (!columnNames.contains('refunded_order_id')) {
          await db.execute('ALTER TABLE local_orders ADD COLUMN refunded_order_id INTEGER');
        }
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Cached Products Table
    await db.execute('''
      CREATE TABLE cached_products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        display_name TEXT,
        barcode TEXT,
        default_code TEXT,
        list_price REAL NOT NULL,
        price REAL NOT NULL,
        pos_categ_ids TEXT,
        category_id INTEGER,
        taxes_id TEXT,
        is_book INTEGER NOT NULL DEFAULT 1,
        isbn TEXT,
        isbn10 TEXT,
        book_authors_display TEXT,
        authors TEXT,
        book_publisher_name TEXT,
        publisher TEXT,
        book_genre_name TEXT,
        genre TEXT,
        book_qty_on_hand INTEGER NOT NULL DEFAULT 0,
        stock_qty INTEGER NOT NULL DEFAULT 0,
        book_edition TEXT,
        book_format TEXT,
        book_publication_year INTEGER,
        publisher_id INTEGER,
        image_128 TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Cached Categories Table
    await db.execute('''
      CREATE TABLE cached_categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id INTEGER,
        child_ids TEXT,
        sequence INTEGER DEFAULT 0
      )
    ''');

    // 3. Cached Partners Table
    await db.execute('''
      CREATE TABLE cached_partners (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        street TEXT,
        city TEXT,
        barcode TEXT
      )
    ''');

    // 4. Local Offline Orders Queue Table
    await db.execute('''
      CREATE TABLE local_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE NOT NULL,
        pos_reference TEXT NOT NULL,
        session_id INTEGER NOT NULL,
        partner_id INTEGER,
        amount_total REAL NOT NULL,
        payload_json TEXT NOT NULL,
        sync_status TEXT CHECK(sync_status IN ('pending', 'syncing', 'synced', 'failed')) DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        is_refund INTEGER DEFAULT 0,
        refunded_order_id INTEGER
      )
    ''');
  }

  // --- Products Cache Methods ---

  Future<void> cacheProducts(List<ProductModel> products) async {
    final db = await database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'cached_products',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ProductModel>> getCachedProducts() async {
    final db = await database;
    final maps = await db.query('cached_products');
    return maps.map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<void> clearProducts() async {
    final db = await database;
    await db.delete('cached_products');
  }

  // --- Categories Cache Methods ---

  Future<void> cacheCategories(List<CategoryModel> categories) async {
    final db = await database;
    final batch = db.batch();
    for (final c in categories) {
      batch.insert(
        'cached_categories',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CategoryModel>> getCachedCategories() async {
    final db = await database;
    final maps = await db.query('cached_categories', orderBy: 'sequence ASC');
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  // --- Partners Cache Methods ---

  Future<void> cachePartners(List<PartnerModel> partners) async {
    final db = await database;
    final batch = db.batch();
    for (final p in partners) {
      batch.insert(
        'cached_partners',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<PartnerModel>> getCachedPartners({String? search}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      maps = await db.query(
        'cached_partners',
        where: 'name LIKE ? OR phone LIKE ? OR barcode = ?',
        whereArgs: [q, q, search.trim()],
      );
    } else {
      maps = await db.query('cached_partners');
    }
    return maps.map((m) => PartnerModel.fromMap(m)).toList();
  }

  /// Closes database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
