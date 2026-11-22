import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/routing/app_router.dart';
import 'package:metapos/presentation/screens/cart/cart_order_screen.dart';
import 'package:metapos/presentation/screens/catalog/catalog_master_screen.dart';
import 'package:metapos/presentation/screens/checkout/checkout_payment_screen.dart';
import 'package:metapos/presentation/screens/customer/customer_selector_screen.dart';
import 'package:metapos/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:metapos/presentation/screens/login/session_login_screen.dart';
import 'package:metapos/presentation/screens/receipt/order_success_receipt_screen.dart';

void main() {
  group('AppRoutes Contract', () {
    test('defines all core screen routes with correct paths including root', () {
      expect(AppRoutes.root, equals('/'));
      expect(AppRoutes.dashboard, equals('/dashboard'));
      expect(AppRoutes.login, equals('/login'));
      expect(AppRoutes.catalog, equals('/catalog'));
      expect(AppRoutes.cart, equals('/cart'));
      expect(AppRoutes.customer, equals('/customer'));
      expect(AppRoutes.checkout, equals('/checkout'));
      expect(AppRoutes.receipt, equals('/receipt'));
      expect(AppRoutes.orders, equals('/orders'));
      expect(AppRoutes.history, equals('/history'));
      expect(AppRoutes.orderDetail, equals('/orders/detail'));
    });

    test('allRoutes list includes root and all defined routes', () {
      expect(AppRoutes.allRoutes.length, equals(11));
      expect(AppRoutes.allRoutes, containsAll([
        '/',
        '/dashboard',
        '/login',
        '/catalog',
        '/cart',
        '/customer',
        '/checkout',
        '/receipt',
        '/orders',
        '/history',
        '/orders/detail',
      ]));
    });
  });

  group('AppRouter - Route Generation', () {
    test('generates SessionLoginScreen for AppRoutes.root ("/") as entrypoint', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.root));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<SessionLoginScreen>());
    });

    test('generates DashboardScreen for AppRoutes.dashboard', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.dashboard));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<DashboardScreen>());
    });

    test('generates SessionLoginScreen for AppRoutes.login', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.login));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<SessionLoginScreen>());
    });

    test('generates CatalogMasterScreen for AppRoutes.catalog', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.catalog));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<CatalogMasterScreen>());
    });

    test('generates CartOrderScreen for AppRoutes.cart', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.cart));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<CartOrderScreen>());
    });

    test('generates CustomerSelectorScreen for AppRoutes.customer', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.customer));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<CustomerSelectorScreen>());
    });

    test('generates CheckoutPaymentScreen for AppRoutes.checkout', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.checkout));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<CheckoutPaymentScreen>());
    });

    test('generates OrderSuccessReceiptScreen for AppRoutes.receipt', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.receipt));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<OrderSuccessReceiptScreen>());
    });

    test('generates 404 Scaffold for unknown route names', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: '/unknown_xyz'));
      expect(route, isA<MaterialPageRoute>());

      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(_MockBuildContext());
      expect(widget, isA<Scaffold>());
    });
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
