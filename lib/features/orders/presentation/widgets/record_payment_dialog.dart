import 'dart:math';

import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/core/theme/app_spacing.dart';
import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/orders/di/orders_providers.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mo hop thoai ghi nhan thanh toan cho mot don hang.
/// Tra ve `true` neu da ghi nhan thanh cong (nguoi goi nen tai lai du lieu),
/// `false` hoac `null` neu nguoi dung huy.
Future<bool> showRecordPaymentDialog(
  BuildContext context, {
  required String orderId,
  required String orderCode,
  required int remaining,
}) async {
  final recorded = await showDialog<bool>(
    context: context,
    builder: (context) => RecordPaymentDialog(
      orderId: orderId,
      orderCode: orderCode,
      remaining: remaining,
    ),
  );
  return recorded == true;
}

/// Nhan vao du lieu don o dang nguyen thuy (id/ma/so con no) thay vi ca doi
/// tuong Order, de dung chung duoc cho ca man "Don hom nay" lan man "Cong no"
/// - hai man lay du lieu tu hai API khac nhau.
class RecordPaymentDialog extends ConsumerStatefulWidget {
  const RecordPaymentDialog({
    required this.orderId,
    required this.orderCode,
    required this.remaining,
    super.key,
  });

  final String orderId;
  final String orderCode;
  final int remaining;

  @override
  ConsumerState<RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
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
      text: widget.remaining.toString(),
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
    if (amount > widget.remaining) {
      setState(
        () => _errorMessage =
            'Số tiền vượt quá số còn nợ (${formatVnd(widget.remaining)})',
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
            orderId: widget.orderId,
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
              'Đơn ${widget.orderCode} · Còn nợ ${formatVnd(widget.remaining)}',
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
