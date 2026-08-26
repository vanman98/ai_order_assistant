import 'package:ai_order_assistant/app/router/app_routes.dart';
import 'package:ai_order_assistant/core/theme/app_spacing.dart';
import 'package:ai_order_assistant/shared/widgets/large_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Order Assistant')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Xử lý đơn hàng',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Chụp ảnh, kiểm tra sản phẩm và tính tiền nhanh chóng.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            LargeActionButton(
              icon: Icons.photo_camera_outlined,
              label: 'CHỤP ĐƠN',
              isPrimary: true,
              onPressed: () => context.push(AppRoutes.captureOrder),
            ),
            const SizedBox(height: AppSpacing.md),
            LargeActionButton(
              icon: Icons.photo_library_outlined,
              label: 'CHỌN ẢNH TỪ MÁY',
              onPressed: () => context.push(AppRoutes.chooseOrderImage),
            ),
            const SizedBox(height: AppSpacing.md),
            LargeActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'ĐƠN HÔM NAY',
              onPressed: () => context.push(AppRoutes.todayOrders),
            ),
            const SizedBox(height: AppSpacing.md),
            LargeActionButton(
              icon: Icons.inventory_2_outlined,
              label: 'DANH MỤC HÀNG',
              onPressed: () => context.push(AppRoutes.products),
            ),
            const SizedBox(height: AppSpacing.md),
            LargeActionButton(
              icon: Icons.people_outline,
              label: 'KHÁCH HÀNG',
              onPressed: () => context.push(AppRoutes.customers),
            ),
            const SizedBox(height: AppSpacing.md),
            LargeActionButton(
              icon: Icons.account_balance_wallet_outlined,
              label: 'CÔNG NỢ',
              onPressed: () => context.push(AppRoutes.debts),
            ),
          ],
        ),
      ),
    );
  }
}
