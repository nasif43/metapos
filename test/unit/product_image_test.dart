import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/models/product_model.dart';
import 'package:metapos/presentation/widgets/book_cover_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // 1x1 transparent PNG base64 string for valid image bytes testing
  const valid1x1PngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  // ---------------------------------------------------------------------------
  // 1. ProductModel Image Parsing & Extreme Inputs (Requirement R6)
  // ---------------------------------------------------------------------------
  group('ProductModel Image Parsing & Extreme Inputs (Requirement R6)', () {
    test('fromJson correctly parses valid base64 image_128 string', () {
      final json = {
        'id': 62,
        'name': 'ব্ল্যাকবার্ড ক্লাসিক',
        'display_name': 'ব্ল্যাকবার্ড ক্লাসিক',
        'list_price': 100.0,
        'image_128': valid1x1PngBase64,
      };

      final product = ProductModel.fromJson(json);
      expect(product.image128, isNotNull);
      expect(product.image128, valid1x1PngBase64);
    });

    test('fromJson converts Odoo boolean false to null for image_128', () {
      // Odoo 19 returns boolean false when binary image field has no data
      final json = {
        'id': 63,
        'name': 'কভারহীন বই',
        'display_name': 'কভারহীন বই',
        'list_price': 150.0,
        'image_128': false,
      };

      final product = ProductModel.fromJson(json);
      expect(product.image128, isNull,
          reason: 'Odoo boolean false must be safely converted to null');
    });

    test('fromJson converts empty string to null for image_128', () {
      final json = {
        'id': 64,
        'name': 'বই',
        'list_price': 200.0,
        'image_128': '',
      };

      final product = ProductModel.fromJson(json);
      expect(product.image128, isNull);
    });

    test('fromJson handles omitted or null image_128 gracefully', () {
      final json1 = {
        'id': 65,
        'name': 'বই',
        'list_price': 250.0,
      };
      final json2 = {
        'id': 66,
        'name': 'বই',
        'list_price': 250.0,
        'image_128': null,
      };

      expect(ProductModel.fromJson(json1).image128, isNull);
      expect(ProductModel.fromJson(json2).image128, isNull);
    });

    test('SQLite toMap and fromMap serialization preserves image_128', () {
      const productWithImage = ProductModel(
        id: 242,
        name: 'ক্রিসমাস অ্যাট হগওয়ার্টস',
        displayName: 'ক্রিসমাস অ্যাট হগওয়ার্টস',
        listPrice: 750.0,
        image128: valid1x1PngBase64,
      );

      final map = productWithImage.toMap();
      expect(map['image_128'], valid1x1PngBase64);

      final restored = ProductModel.fromMap(map);
      expect(restored.image128, valid1x1PngBase64);
      expect(restored.id, productWithImage.id);
      expect(restored.name, productWithImage.name);
    });

    test('Large base64 payload (1MB+) survives model serialization without distortion', () {
      final chunk = valid1x1PngBase64;
      final repeats = (1024 * 1024) ~/ chunk.length;
      final largeBase64 = chunk * repeats;

      final product = ProductModel(
        id: 999,
        name: 'Large Cover Book',
        displayName: 'Large Cover Book',
        listPrice: 1200.0,
        image128: largeBase64,
      );

      final map = product.toMap();
      expect((map['image_128'] as String).length, largeBase64.length);

      final restored = ProductModel.fromMap(map);
      expect(restored.image128?.length, largeBase64.length);
      expect(restored.image128, largeBase64);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. DatabaseHelper Schema Migration Lifecycle (Requirement R6)
  // ---------------------------------------------------------------------------
  group('DatabaseHelper Schema Migration Lifecycle (Requirement R6)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('metapos_db_migration_test_');
      dbPath = join(tempDir.path, 'migration_lifecycle.db');
      await DatabaseHelper().close();
    });

    tearDown(() async {
      await DatabaseHelper().close();
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test(
        'DatabaseHelper._onUpgrade seamlessly upgrades schema from v2 to v3, adding image_128 and preserving existing records',
        () async {
      // 1. Initialize an on-disk SQLite database explicitly at version 2 (simulating pre-existing v2 install)
      final v2Db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          // Schema at v2: 26 columns, WITHOUT image_128
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
              updated_at TEXT NOT NULL
            )
          ''');

          // Seed pre-existing products into v2 database
          await db.insert('cached_products', {
            'id': 101,
            'name': 'হিমুর মধ্যদুপুর',
            'display_name': 'হিমুর মধ্যদুপুর',
            'list_price': 300.0,
            'price': 300.0,
            'is_book': 1,
            'book_qty_on_hand': 15,
            'stock_qty': 15,
            'book_edition': '১ম প্রকাশ',
            'book_format': 'হার্ডকভার',
            'book_publication_year': 2024,
            'publisher_id': 5,
            'updated_at': DateTime.now().toIso8601String(),
          });
        },
      );

      // Verify v2 baseline state
      expect(await v2Db.getVersion(), 2);
      var columns = await v2Db.rawQuery('PRAGMA table_info(cached_products)');
      var columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('image_128'), isFalse,
          reason: 'Version 2 schema must not contain image_128');
      expect(columnNames.contains('book_edition'), isTrue);

      // Close the raw v2 connection so DatabaseHelper can open it
      await v2Db.close();

      // 2. Open the existing v2 database through DatabaseHelper targeting version 3
      // This MUST trigger DatabaseHelper._onUpgrade(db, 2, 3)
      final helper = DatabaseHelper(customDbPath: dbPath);
      final upgradedDb = await helper.database;

      // 3. Verify DatabaseHelper._onUpgrade actually executed:
      // A. PRAGMA user_version is now >= 3 (currently 4)
      final newVersion = await upgradedDb.getVersion();
      expect(newVersion, greaterThanOrEqualTo(3),
          reason: 'DatabaseHelper must upgrade user_version to 3 or higher');

      // B. image_128 column now exists in cached_products
      columns = await upgradedDb.rawQuery('PRAGMA table_info(cached_products)');
      columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('image_128'), isTrue,
          reason: 'DatabaseHelper._onUpgrade must add image_128 column to cached_products');

      // 4. Verify existing pre-migration records are completely preserved
      final cachedProducts = await helper.getCachedProducts();
      expect(cachedProducts.length, 1);
      final existingProduct = cachedProducts.firstWhere((p) => p.id == 101);
      expect(existingProduct.name, 'হিমুর মধ্যদুপুর');
      expect(existingProduct.listPrice, 300.0);
      expect(existingProduct.bookEdition, '১ম প্রকাশ');
      expect(existingProduct.bookPublicationYear, 2024);
      expect(existingProduct.publisherId, 5);
      expect(existingProduct.image128, isNull,
          reason: 'Pre-existing records should have null image_128 after migration');

      // 5. Verify new products with image_128 can be inserted and queried through DatabaseHelper
      const newProductWithImage = ProductModel(
        id: 202,
        name: 'জোছনা ও জননীর গল্প',
        displayName: 'জোছনা ও জননীর গল্প',
        listPrice: 850.0,
        isBook: true,
        bookQtyOnHand: 10,
        image128: valid1x1PngBase64,
      );
      await helper.cacheProducts([newProductWithImage]);

      final updatedCache = await helper.getCachedProducts();
      expect(updatedCache.length, 2);

      final retrievedNewProduct = updatedCache.firstWhere((p) => p.id == 202);
      expect(retrievedNewProduct.name, 'জোছনা ও জননীর গল্প');
      expect(retrievedNewProduct.image128, valid1x1PngBase64);

      // Clean up helper connection
      await helper.close();
    });

    test('DatabaseHelper multi-version leap migration from v1 to v3 executes all upgrade steps',
        () async {
      // Initialize an on-disk database at version 1 (lacking book_edition AND image_128)
      final v1Db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cached_products (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              display_name TEXT,
              list_price REAL NOT NULL,
              price REAL NOT NULL,
              is_book INTEGER NOT NULL DEFAULT 1,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.insert('cached_products', {
            'id': 50,
            'name': 'Legacy V1 Book',
            'list_price': 120.0,
            'price': 120.0,
            'is_book': 1,
            'updated_at': DateTime.now().toIso8601String(),
          });
        },
      );
      expect(await v1Db.getVersion(), 1);
      await v1Db.close();

      // Open via DatabaseHelper to trigger both v1->v2 and v2->v3 migrations
      final helper = DatabaseHelper(customDbPath: dbPath);
      final upgradedDb = await helper.database;

      expect(await upgradedDb.getVersion(), greaterThanOrEqualTo(3));
      final columns = await upgradedDb.rawQuery('PRAGMA table_info(cached_products)');
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames.contains('book_edition'), isTrue);
      expect(columnNames.contains('image_128'), isTrue);

      final cached = await helper.getCachedProducts();
      expect(cached.length, 1);
      expect(cached.first.name, 'Legacy V1 Book');
      expect(cached.first.image128, isNull);

      await helper.close();
    });
  });

  // ---------------------------------------------------------------------------
  // 3. BookCoverImage Widget Rendering & Edge Cases (Requirement R6)
  // ---------------------------------------------------------------------------
  group('BookCoverImage Widget Rendering & Edge Cases (Requirement R6)', () {
    testWidgets('Renders Image.memory when valid base64 image data is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: valid1x1PngBase64,
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<MemoryImage>());
    });

    testWidgets('Renders fallback placeholder when imageBase64 is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: null,
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Renders fallback placeholder when imageBase64 is empty or whitespace', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: '   \t\n\r  ',
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Gracefully handles corrupt base64 string without crashing and renders fallback',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: '@@@corrupt_not_valid_base64_data!!!###',
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Gracefully handles truncated base64 padding without crashing and renders fallback',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: 'iVBORw0KGgoAAA',
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Strips Data URI scheme prefix and successfully renders valid base64 payload',
        (tester) async {
      const dataUriImage = 'data:image/png;base64,$valid1x1PngBase64';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: dataUriImage,
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<MemoryImage>());
    });

    testWidgets('Strips embedded newlines and MIME whitespace and renders image', (tester) async {
      final mimeBase64 = '\n  $valid1x1PngBase64\n  \r\n';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: mimeBase64,
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Renders custom fallback widget when provided and image is null or invalid',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: null,
                fallback: Text('Custom Book Cover Fallback'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Custom Book Cover Fallback'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    });

    testWidgets('Handles valid base64 non-image bytes via errorBuilder without crashing',
        (tester) async {
      final nonImageBase64 = base64Encode(utf8.encode('Not An Image'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverImage(
                imageBase64: nonImageBase64,
                width: 100,
                height: 140,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
