import 'dart:io';
import 'dart:math';

import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/presentation/notifier/order_intake_notifier.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:ai_order_assistant/features/orders/di/orders_providers.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart' as orders_domain;
import 'package:ai_order_assistant/features/orders/presentation/pages/invoice_page.dart';
import 'package:ai_order_assistant/features/products/di/product_providers.dart';
import 'package:ai_order_assistant/features/products/domain/entities/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrderIntakePage extends ConsumerStatefulWidget {
  const OrderIntakePage({required this.source, super.key});

  final OrderImageSource source;

  @override
  ConsumerState<OrderIntakePage> createState() => _OrderIntakePageState();
}

class _OrderIntakePageState extends ConsumerState<OrderIntakePage> {
  final String _clientRequestId = _generateClientRequestId();
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(orderIntakeProvider).imagePath == null) {
        ref.read(orderIntakeProvider.notifier).selectImage(widget.source);
      }
    });
  }

  Future<void> _editItem(int index, ExtractedOrderItem item) async {
    final edit = await showDialog<_CatalogItemEdit>(
      context: context,
      builder: (context) => _CatalogItemDialog(item: item),
    );
    if (edit == null || !mounted) return;
    await ref
        .read(orderIntakeProvider.notifier)
        .saveCatalogItem(
          itemIndex: index,
          name: edit.name,
          quantity: edit.quantity,
          unit: edit.unit,
          price: edit.price,
        );
  }

  Future<void> _chooseFromCatalog(int index) async {
    try {
      final products = await ref.read(productRepositoryProvider).getProducts();
      if (!mounted) return;
      final selected = await showDialog<Product>(
        context: context,
        builder: (context) => _CatalogPickerDialog(products: products),
      );
      if (selected == null || !mounted) return;
      await ref
          .read(orderIntakeProvider.notifier)
          .selectCandidate(
            itemIndex: index,
            candidate: CatalogProductCandidate(
              id: selected.id,
              name: selected.name,
              unit: selected.unit,
              price: selected.price,
              score: 1,
            ),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải danh mục. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _confirmAndOpenInvoice(OrderExtraction result) async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      final items = result.items
          .map(
            (item) => orders_domain.ConfirmOrderItemInput(
              productId: item.selectedProductId!,
              quantity: item.quantity!,
              rawText: item.rawText,
            ),
          )
          .toList(growable: false);
      final order = await ref
          .read(ordersRepositoryProvider)
          .confirmOrder(clientRequestId: _clientRequestId, items: items);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => InvoicePage(
            result: result,
            createdAt: order.createdAt,
            orderCode: order.code,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderIntakeProvider);
    final notifier = ref.read(orderIntakeProvider.notifier);
    final useCamera = widget.source == OrderImageSource.camera;

    final result = state.result;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          result == null
              ? (useCamera ? 'Chụp đơn' : 'Chọn ảnh')
              : 'Kiểm tra đơn hàng',
        ),
      ),
      bottomNavigationBar: result == null
          ? null
          : _OrderSummaryBar(result: result),
      body: SafeArea(
        child: state.isPreparing
            ? const _PreparingView()
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  if (result == null) ...[
                    if (state.imagePath == null)
                      _EmptyImageView(
                        source: widget.source,
                        onPick: () => notifier.selectImage(widget.source),
                      )
                    else ...[
                      _ImagePreview(path: state.imagePath!),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: state.isUploading
                            ? null
                            : () => notifier.selectImage(widget.source),
                        icon: const Icon(Icons.refresh),
                        label: Text(useCamera ? 'CHỤP LẠI' : 'CHỌN ẢNH KHÁC'),
                      ),
                      const SizedBox(height: 16),
                      if (state.isUploading)
                        _UploadProgressView(
                          progress: state.uploadProgress,
                          onCancel: notifier.cancelUpload,
                        )
                      else
                        FilledButton.icon(
                          onPressed: notifier.analyze,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('ĐỌC NỘI DUNG ẢNH'),
                        ),
                    ],
                  ],
                  if (state.failure case final failure?) ...[
                    const SizedBox(height: 20),
                    _ErrorView(
                      message: failure.message,
                      canRetry: state.canRetry,
                      onRetry: notifier.retry,
                    ),
                  ],
                  if (result != null) ...[
                    _OrderReviewOverview(
                      result: result,
                      sourceLabel: useCamera ? 'Ảnh chụp' : 'Thư viện',
                      isConfirming: _isConfirming,
                      onConfirm: result.allMatched && !_isConfirming
                          ? () => _confirmAndOpenInvoice(result)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _ExtractionResultView(
                      result: result,
                      isUpdating: state.isUpdatingCatalog,
                      updatingItemIndex: state.updatingItemIndex,
                      onEdit: _editItem,
                      onChooseFromCatalog: _chooseFromCatalog,
                      onCandidateSelected: (index, candidate) =>
                          notifier.selectCandidate(
                            itemIndex: index,
                            candidate: candidate,
                          ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 4),
          SizedBox(height: 16),
          Text('Đang chuẩn bị và nén ảnh…'),
        ],
      ),
    );
  }
}

class _EmptyImageView extends StatelessWidget {
  const _EmptyImageView({required this.source, required this.onPick});

  final OrderImageSource source;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final useCamera = source == OrderImageSource.camera;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            useCamera
                ? Icons.photo_camera_outlined
                : Icons.photo_library_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có ảnh đơn hàng',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPick,
            icon: Icon(useCamera ? Icons.camera_alt : Icons.photo_library),
            label: Text(useCamera ? 'MỞ CAMERA' : 'CHỌN ẢNH'),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const ColoredBox(
            color: Color(0xFFE9ECEF),
            child: Center(child: Text('Không thể hiển thị ảnh xem trước.')),
          ),
        ),
      ),
    );
  }
}

class _UploadProgressView extends StatelessWidget {
  const _UploadProgressView({required this.progress, required this.onCancel});

  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          progress < 1 ? 'Đang tải ảnh: $percent%' : 'AI đang đọc ảnh…',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress < 1 ? progress : null),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          label: const Text('HỦY'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (canRetry) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('THỬ LẠI'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _brandGreen = Color(0xFF087A3D);
const _softGreen = Color(0xFFEAF6EF);
const _reviewOrange = Color(0xFFE88900);
const _softOrange = Color(0xFFFFF8E9);
const _missingRed = Color(0xFFD9252A);
const _softRed = Color(0xFFFFEFF0);

class _OrderReviewOverview extends StatelessWidget {
  const _OrderReviewOverview({
    required this.result,
    required this.sourceLabel,
    required this.onConfirm,
    this.isConfirming = false,
  });

  final OrderExtraction result;
  final String sourceLabel;
  final VoidCallback? onConfirm;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9E0DC)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            children: [
              Expanded(
                child: _OverviewDetail(
                  icon: Icons.receipt_long_outlined,
                  label: 'Mặt hàng',
                  value: '${result.items.length} dòng',
                ),
              ),
              const SizedBox(height: 42, child: VerticalDivider(width: 14)),
              Expanded(
                child: _OverviewDetail(
                  icon: Icons.image_outlined,
                  label: 'Ảnh đã chọn',
                  value: '1 ảnh · $sourceLabel',
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: _brandGreen,
              minimumSize: const Size(118, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: isConfirming
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 19),
            label: Text(isConfirming ? 'ĐANG LƯU...' : 'XÁC NHẬN'),
          );

          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                details,
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _OverviewDetail extends StatelessWidget {
  const _OverviewDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _brandGreen, size: 22),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _brandGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExtractionResultView extends StatelessWidget {
  const _ExtractionResultView({
    required this.result,
    required this.isUpdating,
    required this.updatingItemIndex,
    required this.onEdit,
    required this.onChooseFromCatalog,
    required this.onCandidateSelected,
  });

  final OrderExtraction result;
  final bool isUpdating;
  final int? updatingItemIndex;
  final void Function(int index, ExtractedOrderItem item) onEdit;
  final ValueChanged<int> onChooseFromCatalog;
  final void Function(int index, CatalogProductCandidate candidate)
  onCandidateSelected;

  @override
  Widget build(BuildContext context) {
    if (result.items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Không tìm thấy dòng hàng hóa nào trong ảnh.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.generalNote case final note?) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Ghi chú từ ảnh: $note'),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD9E0DC)),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const _OrderTableHeader(),
              for (var index = 0; index < result.items.length; index++)
                _OrderTableRow(
                  item: result.items[index],
                  isUpdating: isUpdating && updatingItemIndex == index,
                  interactionsEnabled: !isUpdating,
                  onEdit: () => onEdit(index, result.items[index]),
                  onChooseFromCatalog: () => onChooseFromCatalog(index),
                  onCandidateSelected: (candidate) =>
                      onCandidateSelected(index, candidate),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

const _tableColumnWidths = <int, TableColumnWidth>{
  0: FlexColumnWidth(2.25),
  1: FlexColumnWidth(0.48),
  2: FlexColumnWidth(0.76),
  3: FlexColumnWidth(1.05),
  4: FlexColumnWidth(1.18),
  5: FlexColumnWidth(1.25),
};

class _OrderTableHeader extends StatelessWidget {
  const _OrderTableHeader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _softGreen,
      child: Table(
        columnWidths: _tableColumnWidths,
        children: const [
          TableRow(
            children: [
              _HeaderCell('Mặt hàng'),
              _HeaderCell('SL', centered: true),
              _HeaderCell('Đơn vị'),
              _HeaderCell('Giá', alignRight: true),
              _HeaderCell('Thành tiền', alignRight: true),
              _HeaderCell('Trạng thái', centered: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.label, {
    this.alignRight = false,
    this.centered = false,
  });

  final String label;
  final bool alignRight;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Text(
        label,
        textAlign: centered
            ? TextAlign.center
            : alignRight
            ? TextAlign.right
            : TextAlign.left,
        style: const TextStyle(
          color: Color(0xFF155E38),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrderTableRow extends StatelessWidget {
  const _OrderTableRow({
    required this.item,
    required this.isUpdating,
    required this.interactionsEnabled,
    required this.onEdit,
    required this.onChooseFromCatalog,
    required this.onCandidateSelected,
  });

  final ExtractedOrderItem item;
  final bool isUpdating;
  final bool interactionsEnabled;
  final VoidCallback onEdit;
  final VoidCallback onChooseFromCatalog;
  final ValueChanged<CatalogProductCandidate> onCandidateSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE1E5E3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: interactionsEnabled ? onEdit : null,
            child: Table(
              columnWidths: _tableColumnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _OrderCell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName.isEmpty
                                ? 'Chưa rõ tên hàng'
                                : item.displayName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _itemStatusDescription(item),
                            style: TextStyle(
                              color: _statusColor(item.matchStatus),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _OrderCell(
                      centered: true,
                      child: Text(
                        _formatQuantity(item.quantity),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _OrderCell(
                      child: Text(
                        item.displayUnit ?? '—',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    _OrderCell(
                      alignRight: true,
                      child: Text(
                        item.unitPrice == null
                            ? '—'
                            : formatVnd(item.unitPrice!),
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                    _OrderCell(
                      alignRight: true,
                      child: isUpdating
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              item.lineTotal == null
                                  ? '—'
                                  : formatVnd(item.lineTotal!),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    _OrderCell(
                      centered: true,
                      child: _StatusBadge(status: item.matchStatus),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (item.matchStatus == CatalogMatchStatus.review &&
              item.candidates.isNotEmpty)
            _SuggestionPanel(
              candidates: item.candidates,
              enabled: interactionsEnabled,
              onCandidateSelected: onCandidateSelected,
              onAddNew: onEdit,
            ),
          if (item.matchStatus == CatalogMatchStatus.missing ||
              (item.matchStatus == CatalogMatchStatus.review &&
                  item.candidates.isEmpty))
            _MissingItemActions(
              enabled: interactionsEnabled,
              onChooseFromCatalog: onChooseFromCatalog,
              onAddNew: onEdit,
              onEdit: onEdit,
            ),
          if (item.uncertaintyReason case final reason?)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                'AI chưa chắc: $reason',
                style: const TextStyle(
                  color: _reviewOrange,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCell extends StatelessWidget {
  const _OrderCell({
    required this.child,
    this.alignRight = false,
    this.centered = false,
  });

  final Widget child;
  final bool alignRight;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        child: Align(
          alignment: centered
              ? Alignment.center
              : alignRight
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CatalogMatchStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      CatalogMatchStatus.matched => Icons.check_circle,
      CatalogMatchStatus.review => Icons.error,
      CatalogMatchStatus.missing => Icons.cancel,
    };
    final text = switch (status) {
      CatalogMatchStatus.matched => 'Đã khớp',
      CatalogMatchStatus.review => 'Cần xác nhận',
      CatalogMatchStatus.missing => 'Chưa có',
    };
    final foreground = _statusColor(status);
    final background = switch (status) {
      CatalogMatchStatus.matched => _softGreen,
      CatalogMatchStatus.review => _softOrange,
      CatalogMatchStatus.missing => _softRed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 14),
          const SizedBox(height: 2),
          Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 8.5,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.candidates,
    required this.enabled,
    required this.onCandidateSelected,
    required this.onAddNew,
  });

  final List<CatalogProductCandidate> candidates;
  final bool enabled;
  final ValueChanged<CatalogProductCandidate> onCandidateSelected;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _softOrange,
        border: Border.all(color: const Color(0xFFF3C267)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: _reviewOrange, size: 19),
              SizedBox(width: 6),
              Text(
                'Gợi ý sản phẩm phù hợp',
                style: TextStyle(
                  color: Color(0xFFA75C00),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final candidate in candidates)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFD9DEDB)),
                  left: BorderSide(color: Color(0xFFD9DEDB)),
                  right: BorderSide(color: Color(0xFFD9DEDB)),
                  bottom: BorderSide(color: Color(0xFFD9DEDB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${candidate.unit} · ${formatVnd(candidate.price)}',
                          style: const TextStyle(
                            color: _brandGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: enabled
                        ? () => onCandidateSelected(candidate)
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(62, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('CHỌN'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Expanded(child: Divider()),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Không thấy sản phẩm phù hợp?',
                  style: TextStyle(fontSize: 10),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: enabled ? onAddNew : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('THÊM SẢN PHẨM MỚI'),
          ),
        ],
      ),
    );
  }
}

class _MissingItemActions extends StatelessWidget {
  const _MissingItemActions({
    required this.enabled,
    required this.onChooseFromCatalog,
    required this.onAddNew,
    required this.onEdit,
  });

  final bool enabled;
  final VoidCallback onChooseFromCatalog;
  final VoidCallback onAddNew;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        border: Border.all(color: const Color(0xFFE0E5E2)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onChooseFromCatalog : null,
              style: _compactActionStyle(),
              icon: const Icon(Icons.list_alt, size: 17),
              label: const Text('DANH MỤC'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onAddNew : null,
              style: _compactActionStyle(),
              icon: const Icon(Icons.add_circle_outline, size: 17),
              label: const Text('THÊM MỚI'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onEdit : null,
              style: _compactActionStyle(),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('SỬA TAY'),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _compactActionStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 38),
  padding: const EdgeInsets.symmetric(horizontal: 4),
  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
);

class _OrderSummaryBar extends StatelessWidget {
  const _OrderSummaryBar({required this.result});

  final OrderExtraction result;

  @override
  Widget build(BuildContext context) {
    final matchedItems = result.items
        .where((item) => item.matchStatus == CatalogMatchStatus.matched)
        .toList(growable: false);
    final matchedTotal = matchedItems.fold<int>(
      0,
      (total, item) => total + (item.lineTotal ?? 0),
    );
    final reviewCount = result.items
        .where((item) => item.matchStatus == CatalogMatchStatus.review)
        .length;
    final missingCount = result.items
        .where((item) => item.matchStatus == CatalogMatchStatus.missing)
        .length;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _softGreen,
          border: Border.all(color: const Color(0xFFD6E5DC)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tạm tính (${matchedItems.length} mặt hàng)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatVnd(matchedTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44, child: VerticalDivider(width: 16)),
            _SummaryCount(
              label: 'Cần xác nhận',
              count: reviewCount,
              color: _reviewOrange,
            ),
            const SizedBox(width: 10),
            _SummaryCount(
              label: 'Chưa có',
              count: missingCount,
              color: _missingRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 3),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

Color _statusColor(CatalogMatchStatus status) => switch (status) {
  CatalogMatchStatus.matched => _brandGreen,
  CatalogMatchStatus.review => _reviewOrange,
  CatalogMatchStatus.missing => _missingRed,
};

String _itemStatusDescription(ExtractedOrderItem item) =>
    switch (item.matchStatus) {
      CatalogMatchStatus.matched => 'Đã khớp với danh mục',
      CatalogMatchStatus.review => 'Cần xác nhận sản phẩm',
      CatalogMatchStatus.missing => 'Chưa có trong danh mục',
    };

String _formatQuantity(num? value) {
  if (value == null) return '?';
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}

class _CatalogPickerDialog extends StatefulWidget {
  const _CatalogPickerDialog({required this.products});

  final List<Product> products;

  @override
  State<_CatalogPickerDialog> createState() => _CatalogPickerDialogState();
}

class _CatalogPickerDialogState extends State<_CatalogPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final products = widget.products
        .where(
          (product) =>
              normalizedQuery.isEmpty ||
              product.name.toLowerCase().contains(normalizedQuery) ||
              product.unit.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Chọn từ danh mục'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên hoặc đơn vị',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy sản phẩm phù hợp.'),
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Đơn vị: ${product.unit}'),
                          trailing: Text(
                            formatVnd(product.price),
                            style: const TextStyle(
                              color: _brandGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ĐÓNG'),
        ),
      ],
    );
  }
}

class _CatalogItemEdit {
  const _CatalogItemEdit({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  final String name;
  final num quantity;
  final String unit;
  final int price;
}

class _CatalogItemDialog extends StatefulWidget {
  const _CatalogItemDialog({required this.item});

  final ExtractedOrderItem item;

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item.displayName);
    _quantityController = TextEditingController(
      text: item.quantity == null ? '' : _formatQuantity(item.quantity),
    );
    _unitController = TextEditingController(text: item.displayUnit ?? '');
    _priceController = TextEditingController(
      text: (item.unitPrice ?? item.extractedUnitPrice)?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = widget.item.matchedProduct != null;
    return AlertDialog(
      title: Text(isExisting ? 'Sửa dòng hàng' : 'Thêm vào danh mục'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isExisting) ...[
                const Text(
                  'Tên, đơn vị và giá thay đổi ở đây cũng sẽ cập nhật danh mục hàng.',
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tên hàng',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Số lượng',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final quantity = num.tryParse(
                          (value ?? '').replaceAll(',', '.'),
                        );
                        return quantity == null || quantity <= 0
                            ? 'Phải > 0'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị',
                        hintText: 'gói, lon…',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Đơn giá (₫)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final price = int.tryParse(value ?? '');
                  return price == null || price <= 0
                      ? 'Giá phải lớn hơn 0'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('HỦY'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isExisting ? 'LƯU' : 'THÊM & TÍNH TIỀN'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Không được để trống' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _CatalogItemEdit(
        name: _nameController.text.trim(),
        quantity: num.parse(_quantityController.text.replaceAll(',', '.')),
        unit: _unitController.text.trim(),
        price: int.parse(_priceController.text),
      ),
    );
  }
}

String _generateClientRequestId() {
  final random = Random();
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final randomPart = List.generate(
    8,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return 'req-$timestamp-$randomPart';
}
