import 'package:ai_order_assistant/core/theme/app_spacing.dart';
import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/debts/domain/entities/customer_debt.dart';
import 'package:ai_order_assistant/features/debts/presentation/notifier/customer_debts_notifier.dart';
import 'package:ai_order_assistant/features/orders/presentation/widgets/record_payment_dialog.dart';
import 'package:ai_order_assistant/shared/widgets/feature_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerDebtsPage extends ConsumerWidget {
  const CustomerDebtsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsState = ref.watch(customerDebtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công nợ'),
        actions: [
          IconButton(
            onPressed: () => ref.read(customerDebtsProvider.notifier).refresh(),
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh, size: 24),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(customerDebtsProvider.notifier).refresh(),
          child: debtsState.when(
            data: (debts) => _DebtsList(debts: debts),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _DebtsError(
              message: debtsState.failureMessage ?? 'Không thể tải công nợ.',
              onRetry: () =>
                  ref.read(customerDebtsProvider.notifier).refresh(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtsList extends StatelessWidget {
  const _DebtsList({required this.debts});

  final List<CustomerDebt> debts;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return const _EmptyDebts();
    }

    final grandTotal = debts.fold<int>(
      0,
      (sum, debt) => sum + debt.totalDebt,
    );

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: debts.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DebtsSummaryCard(
            customerCount: debts.length,
            grandTotal: grandTotal,
          );
        }
        return _CustomerDebtCard(debt: debts[index - 1]);
      },
    );
  }
}

class _DebtsSummaryCard extends StatelessWidget {
  const _DebtsSummaryCard({
    required this.customerCount,
    required this.grandTotal,
  });

  final int customerCount;
  final int grandTotal;

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
                '$customerCount khách còn nợ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              formatVnd(grandTotal),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDebtCard extends ConsumerWidget {
  const _CustomerDebtCard({required this.debt});

  final CustomerDebt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final phone = debt.phone;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          debt.customerName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (phone != null && phone.isNotEmpty) phone,
            '${debt.unpaidOrderCount} đơn chưa trả hết',
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          formatVnd(debt.totalDebt),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: colorScheme.error,
          ),
        ),
        children: debt.orders
            .map(
              (order) => _DebtOrderRow(
                order: order,
                onRecordPayment: () async {
                  final recorded = await showRecordPaymentDialog(
                    context,
                    orderId: order.id,
                    orderCode: order.code,
                    remaining: order.remaining,
                  );
                  if (recorded) {
                    await ref
                        .read(customerDebtsProvider.notifier)
                        .refresh();
                  }
                },
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DebtOrderRow extends StatelessWidget {
  const _DebtOrderRow({required this.order, required this.onRecordPayment});

  final DebtOrder order;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatDate(order.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tổng ${formatVnd(order.total)} · Đã thu ${formatVnd(order.paidTotal)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Còn nợ ${formatVnd(order.remaining)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRecordPayment,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('THU TIỀN'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const FeaturePlaceholder(
              icon: Icons.check_circle_outline,
              title: 'Không có công nợ',
              description:
                  'Đơn hàng có gắn khách hàng và chưa trả hết sẽ hiện ở đây.',
            ),
          ),
        );
      },
    );
  }
}

class _DebtsError extends StatelessWidget {
  const _DebtsError({required this.message, required this.onRetry});

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

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}
