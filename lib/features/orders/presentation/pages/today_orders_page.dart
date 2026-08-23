import 'package:ai_order_assistant/core/theme/app_spacing.dart';
import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';
import 'package:ai_order_assistant/features/orders/presentation/notifier/today_orders_notifier.dart';
import 'package:ai_order_assistant/shared/widgets/feature_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayOrdersPage extends ConsumerWidget {
  const TodayOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(todayOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hôm nay')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(todayOrdersProvider.notifier).refresh(),
          child: ordersState.when(
            data: (orders) => _TodayOrdersList(orders: orders),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _TodayOrdersError(
              message: ordersState.failureMessage ?? 'Không thể tải đơn hôm nay.',
              onRetry: () => ref.read(todayOrdersProvider.notifier).refresh(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayOrdersList extends StatelessWidget {
  const _TodayOrdersList({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyTodayOrders();
    }

    final total = orders.fold<int>(0, (sum, order) => sum + order.total);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: orders.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _TodaySummaryCard(
            orderCount: orders.length,
            totalRevenue: total,
          );
        }
        return _OrderCard(order: orders[index - 1]);
      },
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.orderCount,
    required this.totalRevenue,
  });

  final int orderCount;
  final int totalRevenue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$orderCount đơn hôm nay',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              formatVnd(totalRevenue),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(_formatTime(order.createdAt)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${order.customerNameSnapshot} · ${order.items.length} mặt hàng',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatVnd(order.total),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTodayOrders extends StatelessWidget {
  const _EmptyTodayOrders();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const FeaturePlaceholder(
              icon: Icons.receipt_long_outlined,
              title: 'Chưa có đơn hôm nay',
              description: 'Đơn hàng đã xác nhận trong ngày sẽ hiện ở đây.',
            ),
          ),
        );
      },
    );
  }
}

class _TodayOrdersError extends StatelessWidget {
  const _TodayOrdersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('THỬ LẠI'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}
