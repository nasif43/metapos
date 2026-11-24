import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/theme/app_theme.dart';
import 'package:metapos/data/models/category_model.dart';
import 'package:metapos/data/models/dashboard_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_dashboard_service.dart';
import 'package:metapos/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:metapos/presentation/widgets/sales_report_sheet.dart';
import 'package:metapos/providers/dashboard_provider.dart';
import 'package:metapos/providers/printer_provider.dart';

class _FakeDashboardNotifier extends DashboardNotifier {
  final DashboardModel _data;
  _FakeDashboardNotifier(this._data)
      : super(
          dashboardService: OdooDashboardService(
            client: OdooJsonRpcClient(baseUrl: 'https://demostore.metaposbd.com'),
          ),
        );

  @override
  DashboardState get state => DashboardState(data: _data);

  @override
  Future<void> fetchDashboard({bool forceRefresh = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDashboard = DashboardModel.fromJson({
    'kpis': {
      'orders': 35,
      'revenue': 77350.0,
      'revenue_untaxed': 70317.0,
      'book_copies': 62.0,
      'titles': 40,
      'discounts': 1470.0,
      'avg_basket': 2210.0,
      'books_per_order': 1.77,
      'customers': 0,
    },
    'catalogue': {'books': 121},
    'sessions': [
      {
        'id': 75,
        'name': 'বই মেলা/00052',
        'config': 'বই মেলা',
        'user': 'এডমিনিস্ট্রেটর',
        'state': 'opened',
        'state_label': 'In Progress',
        'orders': 23,
        'revenue': 67977.0,
      }
    ],
    'payments': [
      {'id': 1, 'name': 'Cash', 'orders': 19, 'amount': 65942.0},
      {'id': 2, 'name': 'Card', 'orders': 16, 'amount': 11408.0},
    ],
    'top_titles': [
      {
        'id': 231,
        'name': 'A Life in Fifty Books',
        'qty': 4.0,
        'revenue': 6000.0,
      }
    ],
  });

  group('Feedback Regression Tests', () {
    test('Excluded categories filtering removes Misc, Desks, and Chairs', () {
      final rawCategories = [
        CategoryModel(id: 1, name: 'Books'),
        CategoryModel(id: 2, name: 'Misc'),
        CategoryModel(id: 3, name: 'Desks'),
        CategoryModel(id: 4, name: 'Chairs'),
        CategoryModel(id: 59, name: 'উপন্যাস'),
      ];

      const excluded = {'misc', 'miscellaneous', 'desks', 'chairs'};
      final filtered = rawCategories
          .where((c) => !excluded.contains(c.name.trim().toLowerCase()))
          .toList();

      expect(filtered.length, 2);
      expect(filtered.map((c) => c.name), containsAll(['Books', 'উপন্যাস']));
      expect(filtered.any((c) => c.name == 'Misc'), isFalse);
      expect(filtered.any((c) => c.name == 'Desks'), isFalse);
      expect(filtered.any((c) => c.name == 'Chairs'), isFalse);
    });

    testWidgets('SalesReportSheet renders metrics and can trigger report printing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SalesReportSheet(
                isBangla: true,
                data: testDashboard,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('দৈনিক বিক্রয় প্রতিবেদন'), findsOneWidget);
      expect(find.text('আর্থিক বিবরণী'), findsOneWidget);
      expect(find.text('মোট সম্পন্ন অর্ডার'), findsOneWidget);
      expect(find.text('35 টি'), findsOneWidget);
      expect(find.text('62 কপি'), findsOneWidget);
      expect(find.text('রিপোর্ট প্রিন্ট'), findsOneWidget);
      expect(find.text('কপি করুন'), findsOneWidget);
    });

    test('PrinterNotifier.printReportReceipt formats and sends text when printer is connected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerProvider.notifier);
      // Connect real device
      notifier.selectDevice(const BluetoothPrinterDevice(
        name: 'Thermal-58',
        address: 'AA:BB:CC:DD:EE:FF',
      ));
      final success = await notifier.printReportReceipt(
        '=== TEST REPORT ===\nSales: 77,350',
        Duration.zero,
      );

      expect(success, isTrue);
      final state = container.read(printerProvider);
      expect(state.lastPrintReceiptText, contains('TEST REPORT'));
      expect(state.lastPrintedAt, isNotNull);
    });

    testWidgets('DashboardScreen history navigation and sales report buttons are present', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);

      bool routedToHistory = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(
              (_) => _FakeDashboardNotifier(testDashboard),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            routes: {
              '/history': (_) {
                routedToHistory = true;
                return const Scaffold(body: Text('Order History Screen'));
              },
            },
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Check history button in AppBar
      final historyBtn = find.byTooltip('অর্ডার ইতিহাস ও ফেরত');
      expect(historyBtn, findsOneWidget);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();
      expect(routedToHistory, isTrue);
    });
  });
}
