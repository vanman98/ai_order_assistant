import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class InvoicePage extends StatefulWidget {
  InvoicePage({required this.result, DateTime? createdAt, super.key})
    : createdAt = createdAt ?? DateTime.now();

  final OrderExtraction result;
  final DateTime createdAt;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _receiptKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _copyInvoice() async {
    await Clipboard.setData(ClipboardData(text: _invoiceText(widget.result)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung hóa đơn.')),
    );
  }

  Future<void> _shareInvoiceImage(BuildContext shareButtonContext) async {
    if (_isExporting) return;
    final renderBox = shareButtonContext.findRenderObject() as RenderBox?;
    final origin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    setState(() => _isExporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _receiptKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Không tìm thấy nội dung hóa đơn.');
      }

      final ratio = math.min(3.0, math.max(1.0, 4096 / boundary.size.height));
      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('Không thể tạo ảnh hóa đơn.');

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/hoa-don-${widget.createdAt.millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'Hóa đơn bán hàng',
          title: 'Chia sẻ hóa đơn',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xuất ảnh hóa đơn. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn khách hàng')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            KeyedSubtree(
              key: const Key('invoice-receipt'),
              child: RepaintBoundary(
                key: _receiptKey,
                child: _InvoiceReceipt(
                  result: widget.result,
                  createdAt: widget.createdAt,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hóa đơn dùng giá và tổng tiền do backend đã đối chiếu, tính toán.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5D6963), fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _copyInvoice,
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('SAO CHÉP'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      onPressed: _isExporting
                          ? null
                          : () => _shareInvoiceImage(buttonContext),
                      icon: _isExporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share_outlined),
                      label: const Text('CHIA SẺ ẢNH'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceReceipt extends StatelessWidget {
  const _InvoiceReceipt({required this.result, required this.createdAt});

  final OrderExtraction result;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD5DDD8)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFF087A3D),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: const Column(
                  children: [
                    Text(
                      'HÓA ĐƠN BÁN HÀNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Cảm ơn quý khách đã mua hàng',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Khách hàng: Khách lẻ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _formatDateTime(createdAt),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const _InvoiceHeader(),
              for (var index = 0; index < result.items.length; index++)
                _InvoiceRow(index: index, item: result.items[index]),
              Container(
                color: const Color(0xFFEAF6EF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TỔNG CỘNG (${result.items.length} mặt hàng)',
                        style: const TextStyle(
                          color: Color(0xFF155E38),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      formatVnd(result.invoiceTotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF087A3D),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _invoiceColumnWidths = <int, TableColumnWidth>{
  0: FlexColumnWidth(0.35),
  1: FlexColumnWidth(2.15),
  2: FlexColumnWidth(0.9),
  3: FlexColumnWidth(1.25),
  4: FlexColumnWidth(1.35),
};

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F6F3),
      child: Table(
        columnWidths: _invoiceColumnWidths,
        children: const [
          TableRow(
            children: [
              _InvoiceCell('#', isHeader: true, centered: true),
              _InvoiceCell('Mặt hàng', isHeader: true),
              _InvoiceCell('SL/ĐV', isHeader: true, centered: true),
              _InvoiceCell('Đơn giá', isHeader: true, alignRight: true),
              _InvoiceCell('Thành tiền', isHeader: true, alignRight: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.index, required this.item});

  final int index;
  final ExtractedOrderItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE1E5E3))),
      ),
      child: Table(
        columnWidths: _invoiceColumnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _InvoiceCell('${index + 1}', centered: true),
              _InvoiceCell(item.displayName, emphasized: true),
              _InvoiceCell(
                '${_formatQuantity(item.quantity)}\n${item.displayUnit ?? ''}',
                centered: true,
              ),
              _InvoiceCell(
                item.unitPrice == null ? '—' : formatVnd(item.unitPrice!),
                alignRight: true,
              ),
              _InvoiceCell(
                item.lineTotal == null ? '—' : formatVnd(item.lineTotal!),
                alignRight: true,
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceCell extends StatelessWidget {
  const _InvoiceCell(
    this.text, {
    this.isHeader = false,
    this.centered = false,
    this.alignRight = false,
    this.emphasized = false,
  });

  final String text;
  final bool isHeader;
  final bool centered;
  final bool alignRight;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isHeader ? 4 : 5,
        vertical: isHeader ? 9 : 10,
      ),
      child: Text(
        text,
        softWrap: true,
        textAlign: centered
            ? TextAlign.center
            : alignRight
            ? TextAlign.right
            : TextAlign.left,
        style: TextStyle(
          color: isHeader ? const Color(0xFF155E38) : Colors.black87,
          fontSize: isHeader ? 9 : 10.5,
          height: 1.25,
          fontWeight: isHeader || emphasized
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
    );
  }
}

String _invoiceText(OrderExtraction result) {
  final lines = <String>['HÓA ĐƠN BÁN HÀNG'];
  for (var index = 0; index < result.items.length; index++) {
    final item = result.items[index];
    lines.add(
      '${index + 1}. ${item.displayName} — '
      '${_formatQuantity(item.quantity)} ${item.displayUnit ?? ''} × '
      '${item.unitPrice == null ? '—' : formatVnd(item.unitPrice!)} = '
      '${item.lineTotal == null ? '—' : formatVnd(item.lineTotal!)}',
    );
  }
  lines.add('TỔNG CỘNG: ${formatVnd(result.invoiceTotal)}');
  lines.add('Cảm ơn quý khách!');
  return lines.join('\n');
}

String _formatQuantity(num? quantity) {
  if (quantity == null) return '—';
  return quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} '
      '${two(value.day)}/${two(value.month)}/${value.year}';
}
