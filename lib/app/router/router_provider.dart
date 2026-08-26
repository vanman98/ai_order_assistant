import 'package:ai_order_assistant/app/router/app_routes.dart';
import 'package:ai_order_assistant/features/customers/presentation/pages/customer_list_page.dart';
import 'package:ai_order_assistant/features/debts/presentation/pages/customer_debts_page.dart';
import 'package:ai_order_assistant/features/home/presentation/home_page.dart';
import 'package:ai_order_assistant/features/order_intake/presentation/pages/order_intake_page.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:ai_order_assistant/features/orders/presentation/pages/today_orders_page.dart';
import 'package:ai_order_assistant/features/products/presentation/pages/product_list_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.captureOrder,
        builder: (context, state) =>
            const OrderIntakePage(source: OrderImageSource.camera),
      ),
      GoRoute(
        path: AppRoutes.chooseOrderImage,
        builder: (context, state) =>
            const OrderIntakePage(source: OrderImageSource.gallery),
      ),
      GoRoute(
        path: AppRoutes.todayOrders,
        builder: (context, state) => const TodayOrdersPage(),
      ),
      GoRoute(
        path: AppRoutes.products,
        builder: (context, state) => const ProductListPage(),
      ),
      GoRoute(
        path: AppRoutes.customers,
        builder: (context, state) => const CustomerListPage(),
      ),
      GoRoute(
        path: AppRoutes.debts,
        builder: (context, state) => const CustomerDebtsPage(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
