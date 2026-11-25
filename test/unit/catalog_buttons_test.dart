import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/category_model.dart';
import 'package:metapos/data/models/partner_model.dart';
import 'package:metapos/data/models/product_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_catalog_service.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/presentation/screens/catalog/catalog_master_screen.dart';
import 'package:metapos/presentation/widgets/barcode_scanner_sheet.dart';
import 'package:metapos/presentation/widgets/printer_status_bottom_sheet.dart';
import 'package:metapos/providers/auth_provider.dart';
import 'package:metapos/providers/cart_provider.dart';
import 'package:metapos/providers/catalog_provider.dart';
import 'package:metapos/providers/printer_provider.dart';
import 'package:metapos/providers/session_provider.dart';
import 'package:metapos/providers/sync_queue_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Fakes for Widget Tests (Avoiding FFI Isolate deadlocks in FakeAsync)
// ---------------------------------------------------------------------------
class FakeDatabaseHelper implements DatabaseHelper {
  final List<ProductModel> _products = [];
  final List<CategoryModel> _categories = [];
  final List<PartnerModel> _partners = [];

  FakeDatabaseHelper({List<ProductModel>? initialProducts}) {
    if (initialProducts != null) _products.addAll(initialProducts);
  }

  @override
  String? get customDbPath => 'fake';

  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<List<ProductModel>> getCachedProducts() async => List.of(_products);

  @override
  Future<List<CategoryModel>> getCachedCategories() async => List.of(_categories);

  @override
  Future<void> cacheProducts(List<ProductModel> products) async {
    _products.clear();
    _products.addAll(products);
  }

  @override
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    _categories.clear();
    _categories.addAll(categories);
  }

  @override
  Future<void> clearProducts() async => _products.clear();

  @override
  Future<void> cachePartners(List<PartnerModel> partners) async {
    _partners.clear();
    _partners.addAll(partners);
  }

  @override
  Future<List<PartnerModel>> getCachedPartners({String? search}) async => List.of(_partners);

  @override
  Future<void> close() async {}
}

class MockSyncQueueNotifier extends SyncQueueNotifier {
  MockSyncQueueNotifier({
    required super.queueRepo,
    required super.orderService,
    required super.sessionService,
  });

  @override
  Future<void> refreshCounts() async {}

  @override
  Future<void> syncPendingOrders({bool reverseNetTax = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late OfflineQueueRepository queueRepo;

  setUp(() async {
    dbHelper = DatabaseHelper(customDbPath: inMemoryDatabasePath);
    queueRepo = OfflineQueueRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  // Sample test products
  const sampleProducts = [
    ProductModel(
      id: 62,
      name: 'ব্ল্যাকবার্ড ক্লাসিক',
      displayName: 'ব্ল্যাকবার্ড ক্লাসিক',
      listPrice: 100.0,
      barcode: '5556666',
      isbn: '5556666',
      bookQtyOnHand: 79,
      bookAuthorsDisplay: 'Blackbrid Classic',
      isBook: true,
    ),
    ProductModel(
      id: 249,
      name: 'এ লাইফ ইন ফিফটি বুকস',
      displayName: 'এ লাইফ ইন ফিফটি বুকস',
      listPrice: 1500.0,
      barcode: '978984950001',
      isbn: '978984950001',
      bookQtyOnHand: 9,
      bookAuthorsDisplay: 'খন্দকার হিমেল হাসান',
      isBook: true,
    ),
    ProductModel(
      id: 251,
      name: 'সায়েন্স ফিকশন অমনিবাস',
      displayName: 'সায়েন্স ফিকশন অমনিবাস',
      listPrice: 850.0,
      barcode: '978984950003',
      isbn: '978984950003',
      bookQtyOnHand: 0,
      bookAuthorsDisplay: 'জাফর ইকবাল',
      isBook: true,
    ),
  ];

  // ---------------------------------------------------------------------------
  // 1. PrinterProvider Tests
  // ---------------------------------------------------------------------------
  group('PrinterProvider Unit Tests', () {
    test('Initial state: disconnected by default, 58mm paper width, 0 devices', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(printerProvider);
      expect(state.isConnected, isFalse);
      expect(state.selectedDevice, isNull);
      expect(state.paperWidth, PrinterPaperWidth.mm58);
      expect(state.availableDevices.length, 0);
      expect(state.isPrinting, isFalse);
      expect(state.lastPrintedAt, isNull);
    });

    test('Connection toggling and explicit connect/disconnect', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerProvider.notifier);

      notifier.toggleConnection();
      expect(container.read(printerProvider).isConnected, isTrue);

      notifier.toggleConnection();
      expect(container.read(printerProvider).isConnected, isFalse);

      notifier.connect();
      expect(container.read(printerProvider).isConnected, isTrue);

      notifier.disconnect();
      expect(container.read(printerProvider).isConnected, isFalse);
    });

    test('Paper width switching between 58mm and 80mm', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerProvider.notifier);

      notifier.setPaperWidth(PrinterPaperWidth.mm80);
      expect(container.read(printerProvider).paperWidth, PrinterPaperWidth.mm80);
      expect(container.read(printerProvider).paperWidth.columns, 48);

      notifier.setPaperWidth(PrinterPaperWidth.mm58);
      expect(container.read(printerProvider).paperWidth, PrinterPaperWidth.mm58);
      expect(container.read(printerProvider).paperWidth.columns, 32);
    });

    test('Device selection updates selectedDevice and auto-connects', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerProvider.notifier);
      notifier.disconnect();
      expect(container.read(printerProvider).isConnected, isFalse);

      const newDevice = BluetoothPrinterDevice(
        name: 'MPT-II Thermal',
        address: '00:11:22:33:44:55',
      );
      notifier.selectDevice(newDevice);

      final state = container.read(printerProvider);
      expect(state.selectedDevice?.name, 'MPT-II Thermal');
      expect(state.selectedDevice?.address, '00:11:22:33:44:55');
      expect(state.isConnected, isTrue);
    });

    test('printTestReceipt: when connected, formats ESC/POS layout and timestamps', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerProvider.notifier);
      notifier.selectDevice(const BluetoothPrinterDevice(
        name: 'POS-58BT',
        address: '66:32:B1:8A:22:90',
      ));

      final success = await notifier.printTestReceipt(Duration.zero);
      expect(success, isTrue);

      final state = container.read(printerProvider);
      expect(state.isPrinting, isFalse);
      expect(state.lastPrintedAt, isNotNull);
      expect(state.lastPrintReceiptText, contains('TEST RECEIPT'));
      expect(state.lastPrintReceiptText, contains('POS-58BT'));
      expect(state.lastPrintReceiptText, contains('58mm (32 Columns)'));
      expect(state.lastPrintReceiptText, contains('CONNECTED & READY'));
    });

    test('printTestReceipt: when disconnected, returns false without printing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerProvider.notifier);
      notifier.disconnect();

      final success = await notifier.printTestReceipt(Duration.zero);
      expect(success, isFalse);
      expect(container.read(printerProvider).lastPrintedAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. CatalogProvider & CatalogSyncResult Tests
  // ---------------------------------------------------------------------------
  group('CatalogProvider & CatalogSyncResult Unit Tests', () {
    test('loadCatalog returns CatalogSyncResult with cache data when offline', () async {
      // Pre-populate SQLite with cached products
      await dbHelper.cacheProducts(sampleProducts);
      await dbHelper.cacheCategories([
        const CategoryModel(id: 1, name: 'উপন্যাস'),
      ]);

      final mockClient = MockClient((_) async => http.Response('{}', 200));
      final jsonClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          databaseHelperProvider.overrideWithValue(dbHelper),
          catalogServiceProvider.overrideWithValue(OdooCatalogService(client: jsonClient)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(catalogProvider.notifier)
          .loadCatalog(isOffline: true);

      expect(result.success, isTrue);
      expect(result.isFromCache, isTrue);
      expect(result.productsCount, 3);
      expect(result.categoriesCount, 1);
      expect(result.errorMessage, isNull);

      final catalogState = container.read(catalogProvider);
      expect(catalogState.products.length, 3);
      expect(catalogState.categories.length, 1);
    });

    test('loadCatalog returns CatalogSyncResult on successful online sync', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final method = body['params']['method'] as String;

        if (method == 'search_read') {
          final model = body['params']['model'] as String;
          if (model == 'product.product') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'result': [
                  {
                    'id': 62,
                    'name': 'Blackbrid Classic',
                    'display_name': 'ব্ল্যাকবার্ড ক্লাসিক',
                    'list_price': 100.0,
                    'barcode': '5556666',
                    'is_book': true,
                    'book_qty_on_hand': 79,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (model == 'pos.category') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'result': [
                  {'id': 1, 'name': 'উপন্যাস'},
                  {'id': 2, 'name': 'কবিতা'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('{"jsonrpc":"2.0","result":[]}', 200);
      });

      final jsonClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          databaseHelperProvider.overrideWithValue(dbHelper),
          catalogServiceProvider.overrideWithValue(OdooCatalogService(client: jsonClient)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(catalogProvider.notifier)
          .loadCatalog(forceRefresh: true);

      expect(result.success, isTrue);
      expect(result.isFromCache, isFalse);
      expect(result.productsCount, 1);
      expect(result.categoriesCount, 2);
      expect(result.errorMessage, isNull);
    });

    test('loadCatalog captures network errors in CatalogSyncResult gracefully', () async {
      final mockClient = MockClient((_) async {
        throw Exception('Connection timed out to Odoo server');
      });

      final jsonClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          databaseHelperProvider.overrideWithValue(dbHelper),
          catalogServiceProvider.overrideWithValue(OdooCatalogService(client: jsonClient)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(catalogProvider.notifier)
          .loadCatalog(forceRefresh: true);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('ইন্টারনেট সংযোগে সমস্যা হচ্ছে'));
      expect(container.read(catalogProvider).errorMessage, contains('ইন্টারনেট সংযোগে সমস্যা হচ্ছে'));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. BarcodeScannerSheet Widget Tests
  // ---------------------------------------------------------------------------
  group('BarcodeScannerSheet Widget Tests', () {
    testWidgets('Renders viewfinder, status badge, presets, and manual input',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BarcodeScannerSheet(
                products: sampleProducts,
                onProductScanned: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('বারকোড / কিউআর স্ক্যানার'), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Entering barcode 5556666 calls onProductScanned with matched product',
        (tester) async {
      ProductModel? scannedProduct;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BarcodeScannerSheet(
                products: sampleProducts,
                onProductScanned: (p) => scannedProduct = p,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '5556666');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(scannedProduct, isNotNull);
      expect(scannedProduct?.id, 62);
      expect(scannedProduct?.name, 'ব্ল্যাকবার্ড ক্লাসিক');
    });

    testWidgets('Entering out-of-stock barcode calls onOutOfStock handler',
        (tester) async {
      ProductModel? oosProduct;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BarcodeScannerSheet(
                products: sampleProducts,
                onProductScanned: (_) {},
                onOutOfStock: (p) => oosProduct = p,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '978984950003');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(oosProduct, isNotNull);
      expect(oosProduct?.id, 251);
      expect(oosProduct?.bookQtyOnHand, 0);
    });

    testWidgets('Manual input of unknown barcode triggers onNotFound and displays error',
        (tester) async {
      String? notFoundCode;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BarcodeScannerSheet(
                products: sampleProducts,
                onProductScanned: (_) {},
                onNotFound: (code) => notFoundCode = code,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'UNKNOWN_CODE_999');
      await tester.ensureVisible(find.byTooltip('Submit / Scan'));
      await tester.tap(find.byTooltip('Submit / Scan'));
      await tester.pumpAndSettle();

      expect(notFoundCode, 'UNKNOWN_CODE_999');
      expect(find.textContaining('কোনো বই পাওয়া যায়নি'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. PrinterStatusBottomSheet Widget Tests
  // ---------------------------------------------------------------------------
  group('PrinterStatusBottomSheet Widget Tests', () {
    testWidgets('Renders device details, 58mm/80mm toggle, and test print button',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(printerProvider.notifier).selectDevice(const BluetoothPrinterDevice(
        name: 'POS-58BT',
        address: '66:32:B1:8A:22:90',
        isDefault: true,
      ));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PrinterStatusBottomSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Bluetooth Thermal Printer'), findsOneWidget);
      expect(find.text('সংযুক্ত'), findsOneWidget);
      expect(find.text('POS-58BT'), findsWidgets);
      expect(find.text('58mm Roll'), findsOneWidget);
      expect(find.text('80mm Roll'), findsOneWidget);
      expect(find.text('টেস্ট রসিদ প্রিন্ট'), findsOneWidget);
    });

    testWidgets('Tapping 80mm Roll updates paper width state',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PrinterStatusBottomSheet(),
            ),
          ),
        ),
      );

      expect(container.read(printerProvider).paperWidth, PrinterPaperWidth.mm58);

      await tester.tap(find.text('80mm Roll'));
      await tester.pumpAndSettle();

      expect(container.read(printerProvider).paperWidth, PrinterPaperWidth.mm80);
    });

    testWidgets('Tapping Disconnect toggles status to Disconnected',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(printerProvider.notifier).selectDevice(const BluetoothPrinterDevice(
        name: 'POS-58BT',
        address: '66:32:B1:8A:22:90',
      ));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PrinterStatusBottomSheet(),
            ),
          ),
        ),
      );

      expect(container.read(printerProvider).isConnected, isTrue);

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(container.read(printerProvider).isConnected, isFalse);
      expect(find.text('বিচ্ছিন্ন'), findsOneWidget);
    });

    testWidgets('Tapping Print Test Receipt initiates print simulation and shows SnackBar',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          printerProvider.overrideWith((ref) {
            final n = PrinterNotifier();
            n.selectDevice(const BluetoothPrinterDevice(
              name: 'POS-58BT',
              address: '66:32:B1:8A:22:90',
            ));
            return n;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PrinterStatusBottomSheet(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('টেস্ট রসিদ প্রিন্ট'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('টেস্ট রসিদ সফলভাবে প্রিন্ট হয়েছে!'), findsOneWidget);
      expect(container.read(printerProvider).lastPrintedAt, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. CatalogMasterScreen Buttons Integration Tests
  // ---------------------------------------------------------------------------
  group('CatalogMasterScreen Buttons Integration Tests', () {
    ProviderContainer createScreenContainer({List<ProductModel>? initialProducts}) {
      final fakeDb = FakeDatabaseHelper(initialProducts: initialProducts ?? sampleProducts);
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'result': [
              {
                'id': 62,
                'name': 'Blackbrid Classic',
                'display_name': 'ব্ল্যাকবার্ড ক্লাসিক',
                'list_price': 100.0,
                'barcode': '5556666',
                'is_book': true,
                'book_qty_on_hand': 79,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final jsonClient = OdooJsonRpcClient(
        baseUrl: 'https://demostore.metaposbd.com',
        httpClient: mockClient,
      );

      return ProviderContainer(
        overrides: [
          databaseHelperProvider.overrideWithValue(fakeDb),
          offlineQueueRepositoryProvider.overrideWithValue(queueRepo),
          jsonRpcClientProvider.overrideWithValue(jsonClient),
          orderServiceProvider.overrideWithValue(OdooOrderService(client: jsonClient)),
          sessionServiceProvider.overrideWithValue(OdooSessionService(client: jsonClient)),
          catalogServiceProvider.overrideWithValue(OdooCatalogService(client: jsonClient)),
          syncQueueProvider.overrideWith((ref) => MockSyncQueueNotifier(
                queueRepo: queueRepo,
                orderService: OdooOrderService(client: jsonClient),
                sessionService: OdooSessionService(client: jsonClient),
              )),
          printerProvider.overrideWith((ref) => PrinterNotifier(
                simulationDelay: Duration.zero,
              )),
        ],
      );
    }

    testWidgets('Action buttons exist with appropriate icons and tooltips (Printer button scrapped)',
        (tester) async {
      final container = createScreenContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CatalogMasterScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Fake Printer button has been scrapped
      expect(find.byIcon(Icons.print_rounded), findsNothing);
      expect(find.byIcon(Icons.print_outlined), findsNothing);

      // 2. Sync Master Data button in AppBar
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(find.byTooltip('মাস্টার ডাটা সিঙ্ক'), findsOneWidget);

      // 3. Barcode / QR scanner button in search bar
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
      expect(find.byTooltip('বারকোড বা ISBN স্ক্যান'), findsOneWidget);
    });

    testWidgets('PrinterStatusBottomSheet renders device controls when shown',
        (tester) async {
      final container = createScreenContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PrinterStatusBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom sheet should be visible
      expect(find.byType(PrinterStatusBottomSheet), findsOneWidget);
      expect(find.text('Bluetooth Thermal Printer'), findsOneWidget);
    });

    testWidgets('Tapping QR Scanner button opens BarcodeScannerSheet and scanning preset adds to cart',
        (tester) async {
      final container = createScreenContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CatalogMasterScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initial cart state
      expect(container.read(cartProvider).totalItemsCount, 0);

      // Open Barcode Scanner
      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BarcodeScannerSheet), findsOneWidget);

      // Enter barcode 5556666 (Blackbird Classic, ৳100) into manual input
      final sheetTextField = find.descendant(
        of: find.byType(BarcodeScannerSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetTextField, '5556666');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet should be dismissed
      expect(find.byType(BarcodeScannerSheet), findsNothing);

      // Cart state should now have 1 item
      expect(container.read(cartProvider).totalItemsCount, 1);
      expect(container.read(cartProvider).grandTotal, 100.0);

      // Floating SnackBar should be displayed with "View Cart" action
      expect(find.textContaining('কার্টে যোগ করা হয়েছে'), findsOneWidget);
      expect(find.text('কার্ট দেখুন'), findsNWidgets(2));

      // Sticky mini-cart dock reflects the updated count in Bangla default
      expect(find.text('মোট 1 টি বই'), findsOneWidget);
    });

    testWidgets('Tapping Sync button initiates sync and displays feedback SnackBar',
        (tester) async {
      final container = createScreenContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CatalogMasterScreen(),
          ),
        ),
      );
      // Wait for initial loadCatalog to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap sync button
      await tester.tap(find.byIcon(Icons.sync_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar feedback should appear
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('মাস্টার ডাটা সিঙ্ক সম্পন্ন'), findsOneWidget);
    });
  });
}
