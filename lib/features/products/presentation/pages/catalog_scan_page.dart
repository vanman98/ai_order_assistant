import 'dart:io';

import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/presentation/notifier/order_intake_notifier.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:ai_order_assistant/features/products/di/product_providers.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';
import 'package:ai_order_assistant/features/products/presentation/notifier/product_list_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogScanPage extends ConsumerStatefulWidget {
  const CatalogScanPage({required this.source, super.key});

  final OrderImageSource source;

  @override
  ConsumerState<CatalogScanPage> createState() => _CatalogScanPageState();
}

class _CatalogScanPageState extends ConsumerState<CatalogScanPage> {
  final _formKey = GlobalKey<FormState>();
  OrderExtraction? _draftSource;
  List<_CatalogDraft> _drafts = const [];
  bool _isSaving = false;

  bool get _useCamera => widget.source == OrderImageSource.camera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(orderIntakeProvider.notifier).selectImage(widget.source);
      }
    });
  }

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _syncDrafts(OrderExtraction result) {
    if (identical(_draftSource, result)) return;
    _disposeDrafts();
    _draftSource = result;
    final keys = <String>{};
    _drafts = result.items
        .where((item) => item.matchStatus != CatalogMatchStatus.matched)
        .where((item) {
          final key = _draftKey(item.rawProductName, item.unit ?? '');
          return keys.add(key);
        })
        .map(_CatalogDraft.new)
        .toList(growable: false);
  }

  void _disposeDrafts() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts = const [];
  }

  Future<void> _saveProducts() async {
    final unresolved = _drafts.where(
      (draft) =>
          draft.item.matchStatus == CatalogMatchStatus.review &&
          !draft.reviewConfirmed,
    );
    if (unresolved.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hãy xác nhận các dòng gần giống là hàng đã có hay sản phẩm mới.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final selected = _drafts.where((draft) => draft.shouldAdd).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa chọn sản phẩm mới để thêm.')),
      );
      return;
    }

    final products = selected
        .map(
          (draft) => NewProductInput(
            name: draft.name.text.trim(),
            unit: draft.unit.text.trim(),
            price: _parsePrice(draft.price.text)!,
          ),
        )
        .toList(growable: false);
    final keys = <String>{};
    for (final product in products) {
      if (!keys.add(_draftKey(product.name, product.unit))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${product.name} (${product.unit}) đang bị lặp trong danh sách.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(productRepositoryProvider).createProducts(products);
      ref.invalidate(productListProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF087A3D)),
          title: const Text('Đã thêm vào danh mục'),
          content: Text(
            '${products.length} sản phẩm mới đã được thêm thành công.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('XONG'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.from(error).message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderIntakeProvider);
    final notifier = ref.read(orderIntakeProvider.notifier);
    final result = state.result;
    if (result != null) _syncDrafts(result);

    return Scaffold(
      appBar: AppBar(title: const Text('Quét hàng từ đơn')),
      bottomNavigationBar: result == null || _drafts.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProducts,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.playlist_add),
                  label: Text(
                    'THÊM ${_drafts.where((item) => item.shouldAdd).length} SẢN PHẨM',
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: state.isPreparing
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                children: [
                  if (result == null) ...[
                    if (state.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.file(
                            File(state.imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFFE9ECEF),
                              child: Center(
                                child: Text('Không thể hiển thị ảnh.'),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      _NoImageView(
                        useCamera: _useCamera,
                        onPick: () => notifier.selectImage(widget.source),
                      ),
                    if (state.imagePath != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: state.isUploading
                            ? null
                            : () => notifier.selectImage(widget.source),
                        icon: const Icon(Icons.refresh),
                        label: Text(_useCamera ? 'CHỤP LẠI' : 'CHỌN ẢNH KHÁC'),
                      ),
                      const SizedBox(height: 12),
                      if (state.isUploading)
                        _ScanProgress(
                          progress: state.uploadProgress,
                          onCancel: notifier.cancelUpload,
                        )
                      else
                        FilledButton.icon(
                          onPressed: notifier.analyze,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('AI QUÉT DANH MỤC'),
                        ),
                    ],
                  ],
                  if (state.failure case final failure?) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(failure.message, textAlign: TextAlign.center),
                            if (state.canRetry) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: notifier.retry,
                                icon: const Icon(Icons.refresh),
                                label: const Text('THỬ LẠI'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (result != null) ...[
                    _ScanSummary(result: result, newCount: _drafts.length),
                    const SizedBox(height: 12),
                    if (_drafts.isEmpty)
                      _EverythingExistsView(
                        hasExtractedItems: result.items.isNotEmpty,
                      )
                    else
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            for (final draft in _drafts) ...[
                              _CatalogDraftCard(
                                draft: draft,
                                enabled: !_isSaving,
                                onChanged: () => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => notifier.selectImage(widget.source),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('QUÉT ẢNH KHÁC'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CatalogDraft {
  _CatalogDraft(this.item)
    : name = TextEditingController(text: item.rawProductName),
      unit = TextEditingController(text: item.unit ?? ''),
      price = TextEditingController(
        text: item.extractedUnitPrice?.toString() ?? '',
      ),
      shouldAdd = item.matchStatus == CatalogMatchStatus.missing,
      reviewConfirmed = item.matchStatus == CatalogMatchStatus.missing;

  final ExtractedOrderItem item;
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController price;
  bool shouldAdd;
  bool reviewConfirmed;
  CatalogProductCandidate? existingCandidate;

  void dispose() {
    name.dispose();
    unit.dispose();
    price.dispose();
  }
}

class _CatalogDraftCard extends StatelessWidget {
  const _CatalogDraftCard({
    required this.draft,
    required this.enabled,
    required this.onChanged,
  });

  final _CatalogDraft draft;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isReview = draft.item.matchStatus == CatalogMatchStatus.review;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReview ? const Color(0xFFE7A62B) : const Color(0xFFD9E0DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isReview ? 'Cần xác nhận tránh trùng' : 'Sản phẩm chưa có',
                  style: TextStyle(
                    color: isReview
                        ? const Color(0xFFB56800)
                        : const Color(0xFFD9252A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isReview)
                Checkbox(
                  value: draft.shouldAdd,
                  onChanged: enabled
                      ? (value) {
                          draft.shouldAdd = value ?? false;
                          onChanged();
                        }
                      : null,
                ),
            ],
          ),
          if (isReview && draft.item.candidates.isNotEmpty) ...[
            const Text('Có thể là sản phẩm đã có:'),
            const SizedBox(height: 6),
            for (final candidate in draft.item.candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton.icon(
                  onPressed: enabled
                      ? () {
                          draft.existingCandidate = candidate;
                          draft.shouldAdd = false;
                          draft.reviewConfirmed = true;
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: Text(
                    '${candidate.name} · ${candidate.unit} · ${formatVnd(candidate.price)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: enabled
                  ? () {
                      draft.existingCandidate = null;
                      draft.shouldAdd = true;
                      draft.reviewConfirmed = true;
                      onChanged();
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('ĐÂY LÀ SẢN PHẨM MỚI'),
            ),
            if (draft.existingCandidate case final candidate?)
              Text(
                'Sẽ bỏ qua vì đã chọn: ${candidate.name}',
                style: const TextStyle(
                  color: Color(0xFF087A3D),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.name,
            enabled: enabled && draft.shouldAdd,
            decoration: const InputDecoration(
              labelText: 'Tên sản phẩm',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                draft.shouldAdd && (value ?? '').trim().isEmpty
                ? 'Vui lòng nhập tên sản phẩm'
                : null,
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.unit,
                  enabled: enabled && draft.shouldAdd,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    hintText: 'lon, thùng…',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      draft.shouldAdd && (value ?? '').trim().isEmpty
                      ? 'Còn thiếu'
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: draft.price,
                  enabled: enabled && draft.shouldAdd,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Giá bán',
                    suffixText: '₫',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!draft.shouldAdd) return null;
                    final price = _parsePrice(value ?? '');
                    return price == null || price <= 0 ? 'Nhập giá > 0' : null;
                  },
                ),
              ),
            ],
          ),
          if (draft.item.uncertaintyReason case final reason?) ...[
            const SizedBox(height: 7),
            Text(
              'AI chưa chắc: $reason',
              style: const TextStyle(color: Color(0xFFB56800), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  const _ScanSummary({required this.result, required this.newCount});

  final OrderExtraction result;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    final existing = result.items
        .where((item) => item.matchStatus == CatalogMatchStatus.matched)
        .length;
    final review = result.items
        .where((item) => item.matchStatus == CatalogMatchStatus.review)
        .length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryNumber(label: 'Đã có', value: existing),
          ),
          Expanded(
            child: _SummaryNumber(label: 'Cần xem', value: review),
          ),
          Expanded(
            child: _SummaryNumber(label: 'Cần xử lý', value: newCount),
          ),
        ],
      ),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  const _SummaryNumber({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.progress, required this.onCancel});

  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          progress < 1
              ? 'Đang tải ảnh ${(progress * 100).round()}%'
              : 'AI đang đọc và đối chiếu danh mục…',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress < 1 ? progress : null),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          label: const Text('HỦY'),
        ),
      ],
    );
  }
}

class _NoImageView extends StatelessWidget {
  const _NoImageView({required this.useCamera, required this.onPick});

  final bool useCamera;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            useCamera
                ? Icons.photo_camera_outlined
                : Icons.photo_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Chưa có ảnh đơn hàng'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onPick,
            child: Text(useCamera ? 'MỞ CAMERA' : 'CHỌN ẢNH'),
          ),
        ],
      ),
    );
  }
}

class _EverythingExistsView extends StatelessWidget {
  const _EverythingExistsView({required this.hasExtractedItems});

  final bool hasExtractedItems;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF087A3D), size: 44),
            const SizedBox(height: 8),
            Text(
              hasExtractedItems
                  ? 'Tất cả sản phẩm đọc được đã có trong danh mục.'
                  : 'AI không tìm thấy dòng sản phẩm trong ảnh. Hãy chụp rõ hơn.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _draftKey(String name, String unit) =>
    '${name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9à-ỹ]+'), ' ')}|'
    '${unit.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9à-ỹ]+'), ' ')}';

int? _parsePrice(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}
