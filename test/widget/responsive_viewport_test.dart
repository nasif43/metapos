import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metapos/data/local/database_helper.dart';
import 'package:metapos/data/local/offline_queue_repository.dart';
import 'package:metapos/data/models/category_model.dart';
import 'package:metapos/data/models/dashboard_model.dart';
import 'package:metapos/data/models/order_model.dart';
import 'package:metapos/data/models/partner_model.dart';
import 'package:metapos/data/models/pos_config_model.dart';
import 'package:metapos/data/models/product_model.dart';
import 'package:metapos/data/models/session_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_catalog_service.dart';
import 'package:metapos/data/remote/odoo_dashboard_service.dart';
import 'package:metapos/data/remote/odoo_order_service.dart';
import 'package:metapos/data/remote/odoo_partner_service.dart';
import 'package:metapos/data/remote/odoo_session_service.dart';
import 'package:metapos/presentation/screens/cart/cart_order_screen.dart';
import 'package:metapos/presentation/screens/catalog/catalog_master_screen.dart';
import 'package:metapos/presentation/screens/checkout/checkout_payment_screen.dart';
import 'package:metapos/presentation/screens/customer/customer_selector_screen.dart';
import 'package:metapos/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:metapos/presentation/screens/login/session_login_screen.dart';
import 'package:metapos/presentation/screens/receipt/order_success_receipt_screen.dart';
import 'package:metapos/presentation/widgets/barcode_scanner_sheet.dart';
import 'package:metapos/presentation/widgets/printer_status_bottom_sheet.dart';
import 'package:metapos/providers/auth_provider.dart';
import 'package:metapos/providers/cart_provider.dart';
import 'package:metapos/providers/catalog_provider.dart';
import 'package:metapos/providers/connectivity_provider.dart';
import 'package:metapos/providers/customer_provider.dart';
import 'package:metapos/providers/dashboard_provider.dart';
import 'package:metapos/providers/order_provider.dart';
import 'package:metapos/providers/printer_provider.dart';
import 'package:metapos/providers/session_provider.dart';
import 'package:metapos/providers/sync_queue_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Test Fakes & Mock Providers
// ---------------------------------------------------------------------------
class FakeDatabaseHelper implements DatabaseHelper {
  final List<ProductModel> _products = [];
  final List<CategoryModel> _categories = [];
  final List<PartnerModel> _partners = [];

  FakeDatabaseHelper({
    List<ProductModel>? initialProducts,
    List<CategoryModel>? initialCategories,
    List<PartnerModel>? initialPartners,
  }) {
    if (initialProducts != null) _products.addAll(initialProducts);
    if (initialCategories != null) _categories.addAll(initialCategories);
    if (initialPartners != null) _partners.addAll(initialPartners);
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

class FakeDashboardNotifier extends DashboardNotifier {
  FakeDashboardNotifier({required super.dashboardService, required DashboardModel initialData}) {
    state = state.copyWith(data: initialData, isLoading: false);
  }

  @override
  Future<void> fetchDashboard({bool forceRefresh = false}) async {}
}

class FakeCustomerNotifier extends CustomerNotifier {
  FakeCustomerNotifier({
    required super.partnerService,
    required super.dbHelper,
    required List<PartnerModel> initialCustomers,
  }) {
    state = state.copyWith(customers: initialCustomers, isLoading: false);
  }

  @override
  Future<void> searchCustomers(String query, {bool isOffline = false}) async {}
}

class FakeSessionNotifier extends PosSessionNotifier {
  FakeSessionNotifier({
    required super.sessionService,
    required List<PosConfigModel> configs,
    required SessionModel session,
  }) {
    state = state.copyWith(
      configs: configs,
      selectedConfig: configs.isNotEmpty ? configs.first : null,
      activeSession: session,
      isLoading: false,
    );
  }

  @override
  Future<void> loadConfigs() async {}
}

class MockConnectivityService implements NetworkConnectivityService {
  @override
  Future<bool> isConnected() async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
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

// ---------------------------------------------------------------------------
// Sample Test Data
// ---------------------------------------------------------------------------
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
    id: 242,
    name: 'ক্রিসমাস অ্যাট হগওয়ার্টস',
    displayName: 'ক্রিসমাস অ্যাট হগওয়ার্টস - জে. কে. রাউলিং',
    listPrice: 750.0,
    barcode: '978984950002',
    isbn: '978984950002',
    bookQtyOnHand: 25,
    bookAuthorsDisplay: 'জে. কে. রাউলিং',
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
    id: 237,
    name: 'আ প্যাসেজ টু ইন্ডিয়া',
    displayName: 'আ প্যাসেজ টু ইন্ডিয়া',
    listPrice: 12500.0,
    barcode: '978984950005',
    isbn: '978984950005',
    bookQtyOnHand: 14,
    bookAuthorsDisplay: 'ই. এম. ফরস্টার',
    isBook: true,
  ),
];

const sampleCategories = [
  CategoryModel(id: 1, name: 'উপন্যাস'),
  CategoryModel(id: 2, name: 'কবিতা'),
  CategoryModel(id: 3, name: 'সায়েন্স ফিকশন'),
];

const sampleCustomers = [
  PartnerModel(
    id: 101,
    name: 'তানভীর আহমেদ',
    phone: '01711000001',
    email: 'tanveer@example.com',
  ),
  PartnerModel(
    id: 102,
    name: 'ফারহানা রহমান',
    phone: '01811000002',
    email: 'farhana@example.com',
  ),
  PartnerModel(
    id: 103,
    name: 'বইমেলা দর্শনার্থী - ওয়াক-ইন গেস্ট',
    phone: '01911000003',
  ),
];

const sampleDashboard = DashboardModel(
  revenue: 125000.0,
  orders: 45,
  bookCopies: 120,
  titles: 35,
  avgBasket: 2777.78,
  discounts: 12500.0,
  customers: 38,
  booksPerOrder: 2.67,
  hourly: [
    HourlyStat(hour: 10, orders: 5, revenue: 15000.0),
    HourlyStat(hour: 11, orders: 8, revenue: 25000.0),
    HourlyStat(hour: 12, orders: 12, revenue: 35000.0),
    HourlyStat(hour: 13, orders: 7, revenue: 20000.0),
    HourlyStat(hour: 14, orders: 13, revenue: 30000.0),
  ],
  daily: [
    DailyStat(day: '2026-11-20', orders: 40, revenue: 110000.0),
    DailyStat(day: '2026-11-21', orders: 45, revenue: 125000.0),
  ],
  openSessions: 1,
  totalCatalogBooks: 50,
);

const sampleConfig = PosConfigModel(
  id: 1,
  name: 'Book Fair Stall #1',
  bookFairMode: true,
  currentSessionId: 23,
  currentSessionState: 'opened',
  paymentMethodIds: [1, 2, 3],
);

const sampleSession = SessionModel(
  id: 23,
  name: 'Book Fair/00014',
  state: 'opened',
  configId: 1,
  cashRegisterBalanceStart: 5000.0,
);

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

  // ---------------------------------------------------------------------------
  // Viewport Specifications
  // ---------------------------------------------------------------------------
  final viewports = [
    (name: 'Small Mobile (360x800)', size: const Size(360, 800)),
    (name: 'Mid Mobile (390x844)', size: const Size(390, 844)),
    (name: 'Large Mobile (412x915)', size: const Size(412, 915)),
  ];

  ProviderContainer createContainer({
    bool populateCart = false,
    bool attachCustomer = false,
  }) {
    final fakeDb = FakeDatabaseHelper(
      initialProducts: sampleProducts,
      initialCategories: sampleCategories,
      initialPartners: sampleCustomers,
    );

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'result': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final jsonClient = OdooJsonRpcClient(
      baseUrl: 'https://demostore.metaposbd.com',
      httpClient: mockClient,
    );

    final container = ProviderContainer(
      overrides: [
        databaseHelperProvider.overrideWithValue(fakeDb),
        offlineQueueRepositoryProvider.overrideWithValue(queueRepo),
        jsonRpcClientProvider.overrideWithValue(jsonClient),
        orderServiceProvider.overrideWithValue(OdooOrderService(client: jsonClient)),
        sessionServiceProvider.overrideWithValue(OdooSessionService(client: jsonClient)),
        catalogServiceProvider.overrideWithValue(OdooCatalogService(client: jsonClient)),
        connectivityServiceProvider.overrideWithValue(MockConnectivityService()),
        connectivityProvider.overrideWith(
          (ref) => ConnectivityNotifier(
            service: MockConnectivityService(),
            ref: ref,
            initialOnline: true,
          ),
        ),
        orderSyncStatusProvider.overrideWith((ref, uuid) async => 'synced'),
        dashboardProvider.overrideWith(
          (ref) => FakeDashboardNotifier(
            dashboardService: OdooDashboardService(client: jsonClient),
            initialData: sampleDashboard,
          ),
        ),
        customerProvider.overrideWith(
          (ref) => FakeCustomerNotifier(
            partnerService: OdooPartnerService(client: jsonClient),
            dbHelper: fakeDb,
            initialCustomers: sampleCustomers,
          ),
        ),
        sessionProvider.overrideWith(
          (ref) => FakeSessionNotifier(
            sessionService: OdooSessionService(client: jsonClient),
            configs: [sampleConfig],
            session: sampleSession,
          ),
        ),
        syncQueueProvider.overrideWith(
          (ref) => MockSyncQueueNotifier(
            queueRepo: queueRepo,
            orderService: OdooOrderService(client: jsonClient),
            sessionService: OdooSessionService(client: jsonClient),
          ),
        ),
        printerProvider.overrideWith(
          (ref) => PrinterNotifier(simulationDelay: Duration.zero),
        ),
      ],
    );

    if (populateCart) {
      final cartNotifier = container.read(cartProvider.notifier);
      cartNotifier.addItem(sampleProducts[0]);
      cartNotifier.addItem(sampleProducts[1]);
      if (attachCustomer) {
        cartNotifier.setCustomer(sampleCustomers[0]);
      }
    }

    return container;
  }

  Widget buildApp(Widget home, ProviderContainer container, Size size) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
      ),
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: home,
          routes: {
            '/dashboard': (c) => const DashboardScreen(),
            '/catalog': (c) => const CatalogMasterScreen(),
            '/cart': (c) => const CartOrderScreen(),
            '/customer': (c) => const CustomerSelectorScreen(),
            '/checkout': (c) => const CheckoutPaymentScreen(),
            '/receipt': (c) => const OrderSuccessReceiptScreen(),
            '/login': (c) => const SessionLoginScreen(),
          },
        ),
      ),
    );
  }

  OrderModel createCompletedSampleOrder() {
    final line1 = OrderLineModel.create(
      productId: 62,
      productName: 'ব্ল্যাকবার্ড ক্লাসিক',
      qty: 2.0,
      priceUnit: 100.0,
      isTaxInclusive: true,
    );
    final line2 = OrderLineModel.create(
      productId: 242,
      productName: 'ক্রিসমাস অ্যাট হগওয়ার্টস',
      qty: 1.0,
      priceUnit: 750.0,
      isTaxInclusive: true,
    );
    final payment = PaymentLineModel.create(
      paymentMethodId: 1,
      paymentMethodName: 'নগদ (Cash)',
      amount: 950.0,
      sessionId: 23,
    );
    return OrderModel.create(
      sessionId: 23,
      configId: 1,
      lines: [line1, line2],
      payments: [payment],
      isSynced: true,
    );
  }

  group('Multi-Viewport Responsive & Zero Overflow Suite (Requirement R3)', () {
    for (final vp in viewports) {
      group('Viewport: ${vp.name}', () {
        testWidgets('1. DashboardScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(buildApp(const DashboardScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'DashboardScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(DashboardScreen), findsOneWidget);
        });

        testWidgets('2. CatalogMasterScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(buildApp(const CatalogMasterScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'CatalogMasterScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(CatalogMasterScreen), findsOneWidget);
        });

        testWidgets('3. CartOrderScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer(populateCart: true, attachCustomer: true);
          addTearDown(container.dispose);

          await tester.pumpWidget(buildApp(const CartOrderScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'CartOrderScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(CartOrderScreen), findsOneWidget);
        });

        testWidgets('4. CustomerSelectorScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(buildApp(const CustomerSelectorScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'CustomerSelectorScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(CustomerSelectorScreen), findsOneWidget);
        });

        testWidgets('5. CheckoutPaymentScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer(populateCart: true);
          addTearDown(container.dispose);

          await tester.pumpWidget(buildApp(const CheckoutPaymentScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'CheckoutPaymentScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(CheckoutPaymentScreen), findsOneWidget);
        });

        testWidgets('6. OrderSuccessReceiptScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);
          final order = createCompletedSampleOrder();
          container.read(lastCompletedOrderProvider.notifier).state = order;

          await tester.pumpWidget(buildApp(const OrderSuccessReceiptScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'OrderSuccessReceiptScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(OrderSuccessReceiptScreen), findsOneWidget);
        });

        testWidgets('7. SessionLoginScreen renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(buildApp(const SessionLoginScreen(), container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'SessionLoginScreen must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(SessionLoginScreen), findsOneWidget);
        });

        testWidgets('8. BarcodeScannerSheet renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);

          final sheet = Scaffold(
            body: BarcodeScannerSheet(
              products: sampleProducts,
              onProductScanned: (_) {},
            ),
          );

          await tester.pumpWidget(buildApp(sheet, container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'BarcodeScannerSheet must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(BarcodeScannerSheet), findsOneWidget);
        });

        testWidgets('9. PrinterStatusBottomSheet renders cleanly without RenderFlex overflows',
            (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final container = createContainer();
          addTearDown(container.dispose);

          const sheet = Scaffold(
            body: PrinterStatusBottomSheet(),
          );

          await tester.pumpWidget(buildApp(sheet, container, vp.size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull,
              reason: 'PrinterStatusBottomSheet must not throw RenderFlex overflow on ${vp.name}');
          expect(find.byType(PrinterStatusBottomSheet), findsOneWidget);
        });
      });
    }
  });
}
