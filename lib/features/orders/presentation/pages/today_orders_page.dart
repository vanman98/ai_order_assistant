import 'dart:math';

import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/core/theme/app_spacing.dart';
import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/orders/di/orders_providers.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';
import 'package:ai_order_assistant/features/orders/presentation/notifier/today_orders_notifier.dart';
import 'package:ai_order_assistant/shared/widgets/feature_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final outstanding = orders.fold<int>(
      0,
      (sum, order) => sum + order.remaining,
    );

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
            outstanding: outstanding,
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
    required this.outstanding,
  });

  final int orderCount;
  final int totalRevenue;
  final int outstanding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            if (outstanding > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Còn nợ: ${formatVnd(outstanding)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFullyPaid = order.isFullyPaid;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: isFullyPaid
                      ? Text(
                          'Đã thanh toán đủ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                        )
                      : Text(
                          'Đã thu ${formatVnd(order.paidTotal)} · Còn nợ ${formatVnd(order.remaining)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                ),
                Text(
                  formatVnd(order.total),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (!isFullyPaid) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _showRecordPaymentDialog(context, ref, order),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('GHI NHẬN THANH TOÁN'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showRecordPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final recorded = await showDialog<bool>(
    context: context,
    builder: (context) => _RecordPaymentDialog(order: order),
  );
  if (recorded == true) {
    await ref.read(todayOrdersProvider.notifier).refresh();
  }
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({required this.order});

  final Order order;

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  final String _clientRequestId = _generatePaymentClientRequestId();
  PaymentMethod _method = PaymentMethod.cash;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.order.remaining.toString(),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Số tiền không hợp lệ');
      return;
    }
    if (amount > widget.order.remaining) {
      setState(
        () => _errorMessage =
            'Số tiền vượt quá số còn nợ (${formatVnd(widget.order.remaining)})',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(ordersRepositoryProvider)
          .createPayment(
            orderId: widget.order.id,
            clientRequestId: _clientRequestId,
            amount: amount,
            method: _method,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = ErrorHandler.from(error).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ghi nhận thanh toán'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đơn ${widget.order.code} · Còn nợ ${formatVnd(widget.order.remaining)}',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Số tiền thanh toán (đ)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Hình thức'),
              items: const [
                DropdownMenuItem(
                  value: PaymentMethod.cash,
                  child: Text('Tiền mặt'),
                ),
                DropdownMenuItem(
                  value: PaymentMethod.bankTransfer,
                  child: Text('Chuyển khoản'),
                ),
                DropdownMenuItem(
                  value: PaymentMethod.other,
                  child: Text('Khác'),
                ),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _method = value);
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('HỦY'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('XÁC NHẬN'),
        ),
      ],
    );
  }
}

String _generatePaymentClientRequestId() {
  final random = Random();
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final randomPart = List.generate(
    8,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return 'pay-$timestamp-$randomPart';
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
