import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/theme/app_theme.dart';
import 'package:metapos/data/models/dashboard_model.dart';
import 'package:metapos/data/remote/json_rpc_client.dart';
import 'package:metapos/data/remote/odoo_dashboard_service.dart';
import 'package:metapos/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:metapos/providers/dashboard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockOdooDashboardJson = {
    'period': {'from': '2026-11-22', 'to': '2026-11-22', 'days': 1},
    'kpis': {
      'orders': 1,
      'revenue': 9000.0,
      'revenue_untaxed': 8181.82,
      'refunds': 0.0,
      'customers': 1,
      'copies': 2.0,
      'book_copies': 2.0,
      'titles': 2,
      'discounts': 826.45,
      'avg_basket': 9000.0,
      'books_per_order': 2.0,
    },
    'previous': {
      'orders': 343,
      'revenue': 116630.89,
      'revenue_untaxed': 106260.3,
      'refunds': 2810.0,
      'customers': 7,
      'copies': 382.0,
      'book_copies': 60.0,
      'titles': 12,
      'discounts': 5819.71,
      'avg_basket': 340.03,
      'books_per_order': 0.17,
    },
    'open_sessions': 1,
    'catalogue': {'books': 32},
    'daily': [],
    'hourly': [
      {'hour': 14, 'orders': 1, 'revenue': 9000.0}
    ],
    'top_titles': [
      {
        'id': 260,
        'name': 'An Anthology of Contemporary Bengali Plays by Bratya Basu',
        'isbn': '9793224729918',
        'authors': 'শুভংকর ঘোষ',
        'qty': 1.0,
        'revenue': 4500.0,
      },
      {
        'id': 269,
        'name': 'Animals',
        'isbn': '9798537787600',
        'authors': 'সুব্রত মুখোপাধ্যায়',
        'qty': 1.0,
        'revenue': 4500.0,
      }
    ],
    'genres': [
      {
        'id': 131,
        'name': 'থ্রিলার, রহস্য ও গোয়েন্দা কাহিনী',
        'qty': 1.0,
        'revenue': 4500.0,
      },
      {
        'id': 141,
        'name': 'রান্না, স্বাস্থ্য ও লাইফস্টাইল',
        'qty': 1.0,
        'revenue': 4500.0,
      }
    ],
    'payments': [
      {
        'id': 1,
        'name': 'Cash',
        'orders': 1,
        'amount': 9000.0,
      }
    ],
    'sessions': [
      {
        'id': 23,
        'name': 'Book Fair/00014',
        'config': 'Book Fair',
        'user': 'Administrator',
        'state': 'opened',
        'state_label': 'In Progress',
        'start_at': '2026-11-21 02:18',
        'stop_at': '',
        'orders': 347,
        'revenue': 125520.89,
        'cash_difference': 0.0,
      }
    ],
    'currency': 'BDT',
  };

  group('Dashboard Functional Model Tests', () {
    test('DashboardModel.fromJson correctly deserializes rich Odoo 19 telemetry', () {
      final model = DashboardModel.fromJson(mockOdooDashboardJson);

      expect(model.revenue, 9000.0);
      expect(model.revenueUntaxed, 8181.82);
      expect(model.orders, 1);
      expect(model.bookCopies, 2);
      expect(model.titles, 2);
      expect(model.avgBasket, 9000.0);
      expect(model.discounts, 826.45);
      expect(model.customers, 1);
      expect(model.booksPerOrder, 2.0);

      // Previous session telemetry
      expect(model.previousOrders, 343);
      expect(model.previousRevenue, 116630.89);
      expect(model.previousAvgBasket, 340.03);

      // Payments breakdown
      expect(model.payments.length, 1);
      expect(model.payments.first.name, 'Cash');
      expect(model.payments.first.amount, 9000.0);

      // Top titles
      expect(model.topTitles.length, 2);
      expect(model.topTitles.first.name,
          'An Anthology of Contemporary Bengali Plays by Bratya Basu');
      expect(model.topTitles.first.authors, 'শুভংকর ঘোষ');
      expect(model.topTitles.first.revenue, 4500.0);

      // Genres
      expect(model.genres.length, 2);
      expect(model.genres.first.name, 'থ্রিলার, রহস্য ও গোয়েন্দা কাহিনী');

      // Sessions
      expect(model.sessions.length, 1);
      expect(model.sessions.first.name, 'Book Fair/00014');
      expect(model.sessions.first.user, 'Administrator');
      expect(model.sessions.first.revenue, 125520.89);
    });
  });

  group('Dashboard Functional Screen Tests', () {
    testWidgets('DashboardScreen displays live session details and tapping KPI cards opens drill-downs',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);

      final model = DashboardModel.fromJson(mockOdooDashboardJson);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(
              (ref) => DashboardNotifierMock(model),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Hero banner displays live session name and user from Odoo
      expect(find.textContaining('Book Fair (Book Fair/00014)'), findsOneWidget);
      expect(find.textContaining('Administrator'), findsOneWidget);

      // 2. 8 KPI cards are rendered
      expect(find.text('দৈনিক আয়'), findsOneWidget);
      expect(find.text('মোট অর্ডার'), findsOneWidget);
      expect(find.text('মোট বই বিক্রি'), findsOneWidget);
      expect(find.text('বিক্রিত শিরোনাম'), findsOneWidget);

      // 3. Tap "দৈনিক আয়" card opens bottom sheet with payment breakdown
      await tester.tap(find.text('দৈনিক আয়'));
      await tester.pumpAndSettle();

      expect(find.text('বিক্রয় ও পেমেন্ট বিবরণী'), findsOneWidget);
      expect(find.text('কর ব্যতীত বিক্রয়'), findsOneWidget);
      expect(find.text('Cash (1 orders)'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // 4. Tap "মোট বই বিক্রি" card opens top selling books sheet
      await tester.tap(find.text('মোট বই বিক্রি'));
      await tester.pumpAndSettle();

      expect(find.text('শীর্ষ বিক্রিত বইসমূহ'), findsOneWidget);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('সুব্রত মুখোপাধ্যায়'), findsOneWidget);
    });
  });
}

class DashboardNotifierMock extends DashboardNotifier {
  final DashboardModel initialData;
  DashboardNotifierMock(this.initialData)
      : super(
          dashboardService: OdooDashboardService(
            client: OdooJsonRpcClient(baseUrl: 'https://demostore.metaposbd.com'),
          ),
        );

  @override
  DashboardState get state => DashboardState(data: initialData);

  @override
  Future<void> fetchDashboard({bool forceRefresh = false}) async {}
}
