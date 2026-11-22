import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../presentation/screens/cart/cart_order_screen.dart';
import '../../presentation/screens/catalog/catalog_master_screen.dart';
import '../../presentation/screens/checkout/checkout_payment_screen.dart';
import '../../presentation/screens/customer/customer_selector_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/login/session_login_screen.dart';
import '../../presentation/screens/orders/order_detail_screen.dart';
import '../../presentation/screens/orders/order_history_screen.dart';
import '../../presentation/screens/receipt/order_success_receipt_screen.dart';

/// Central route names for MetaPOS.
abstract final class AppRoutes {
  static const String root = '/';
  static const String dashboard = '/dashboard';
  static const String login = '/login';
  static const String catalog = '/catalog';
  static const String cart = '/cart';
  static const String customer = '/customer';
  static const String checkout = '/checkout';
  static const String receipt = '/receipt';
  static const String orders = '/orders';
  static const String history = '/history';
  static const String orderDetail = '/orders/detail';

  static const List<String> allRoutes = [
    root,
    dashboard,
    login,
    catalog,
    cart,
    customer,
    checkout,
    receipt,
    orders,
    history,
    orderDetail,
  ];
}

/// Route generator for declarative named routing.
abstract final class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SessionLoginScreen(),
        );

      case AppRoutes.dashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DashboardScreen(),
        );

      case AppRoutes.catalog:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CatalogMasterScreen(),
        );

      case AppRoutes.cart:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CartOrderScreen(),
        );

      case AppRoutes.customer:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => const CustomerSelectorScreen(),
        );

      case AppRoutes.checkout:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CheckoutPaymentScreen(),
        );

      case AppRoutes.receipt:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OrderSuccessReceiptScreen(),
        );

      case AppRoutes.orders:
      case AppRoutes.history:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OrderHistoryScreen(),
        );

      case AppRoutes.orderDetail:
        final order = settings.arguments as OrderModel;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => OrderDetailScreen(order: order),
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Route Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
