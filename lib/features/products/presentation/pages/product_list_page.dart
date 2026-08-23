import 'dart:async';

import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:ai_order_assistant/core/errors/failure.dart';
import 'package:ai_order_assistant/features/products/domain/entities/product.dart';
import 'package:ai_order_assistant/features/products/presentation/notifier/product_list_notifier.dart';
import 'package:ai_order_assistant/features/products/presentation/pages/catalog_scan_page.dart';
import 'package:ai_order_assistant/features/products/presentation/widgets/product_form_dialog.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục hàng'),
        actions: [
          IconButton(
            onPressed: () => ref.read(productListProvider.notifier).refresh(),
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh, size: 24),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Tìm tên sản phẩm',
                  prefixIcon: const Icon(Icons.search, size: 24),
                  suffixIcon: IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _scheduleSearch,
              ),
            ),
            Expanded(
              child: productsState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                error: (error, _) => _ProductErrorView(
                  message: error is Failure
                      ? error.message
                      : 'Không thể tải danh mục hàng.',
                  onRetry: () =>
                      ref.read(productListProvider.notifier).refresh(),
                ),
                data: (products) => products.isEmpty
                    ? const _EmptyProductsView()
                    : _ProductTable(
                        products: products,
                        onRefresh: () =>
                            ref.read(productListProvider.notifier).refresh(),
                        onEdit: _openProductForm,
                        onDelete: _confirmDelete,
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openCatalogScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('QUÉT ĐƠN AI'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openProductForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('THÊM HÀNG'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _search(String query) {
    ref.read(productListProvider.notifier).search(query);
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query),
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _search('');
  }

  Future<void> _openCatalogScan() async {
    final source = await showModalBottomSheet<OrderImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh đơn hàng'),
              onTap: () => Navigator.pop(context, OrderImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ máy'),
              onTap: () => Navigator.pop(context, OrderImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CatalogScanPage(source: source)),
    );
  }

  Future<void> _openProductForm([Product? product]) async {
    final value = await showDialog<ProductFormValue>(
      context: context,
      builder: (context) => ProductFormDialog(product: product),
    );
    if (value == null) return;

    final notifier = ref.read(productListProvider.notifier);
    if (product == null) {
      await notifier.createProduct(
        name: value.name,
        unit: value.unit,
        price: value.price,
      );
    } else {
      await notifier.updateProduct(
        id: product.id,
        name: value.name,
        unit: value.unit,
        price: value.price,
      );
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sản phẩm?'),
        content: Text(
          '${product.name} sẽ bị xóa khỏi danh mục. '
          'Bạn không thể hoàn tác thao tác này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(productListProvider.notifier).deleteProduct(product.id);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

const _productColumnWidths = <int, TableColumnWidth>{
  0: FlexColumnWidth(2.35),
  1: FlexColumnWidth(0.78),
  2: FlexColumnWidth(1.18),
  3: FlexColumnWidth(1.42),
};

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final Future<void> Function() onRefresh;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9E0DC)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _ProductTableHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductTableRow(
                    product: product,
                    onEdit: () => onEdit(product),
                    onDelete: () => onDelete(product),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  const _ProductTableHeader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEAF6EF),
      child: Table(
        columnWidths: _productColumnWidths,
        children: const [
          TableRow(
            children: [
              _ProductHeaderCell('Tên hàng'),
              _ProductHeaderCell('Đơn vị'),
              _ProductHeaderCell('Giá bán', alignRight: true),
              _ProductHeaderCell('Thao tác', centered: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductHeaderCell extends StatelessWidget {
  const _ProductHeaderCell(
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      child: Text(
        label,
        textAlign: centered
            ? TextAlign.center
            : alignRight
            ? TextAlign.right
            : TextAlign.left,
        style: const TextStyle(
          color: Color(0xFF155E38),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E6E4))),
      ),
      child: Table(
        columnWidths: _productColumnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _ProductCell(
                child: Text(
                  product.name,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ProductCell(
                child: Text(
                  product.unit,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ProductCell(
                alignRight: true,
                child: Text(
                  formatVnd(product.price),
                  softWrap: true,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF087A3D),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ProductCell(
                centered: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      style: _productActionStyle(),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('SỬA'),
                    ),
                    const SizedBox(height: 5),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      style: _productActionStyle(),
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('XÓA'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCell extends StatelessWidget {
  const _ProductCell({
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
      constraints: const BoxConstraints(minHeight: 82),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
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

ButtonStyle _productActionStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(76, 32),
  padding: const EdgeInsets.symmetric(horizontal: 7),
  textStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
);

class _EmptyProductsView extends StatelessWidget {
  const _EmptyProductsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có sản phẩm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Bấm THÊM HÀNG để tạo sản phẩm đầu tiên.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductErrorView extends StatelessWidget {
  const _ProductErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('THỬ LẠI'),
            ),
          ],
        ),
      ),
    );
  }
}
