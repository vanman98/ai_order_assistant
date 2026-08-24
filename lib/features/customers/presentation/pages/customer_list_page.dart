import 'dart:async';

import 'package:ai_order_assistant/core/errors/failure.dart';
import 'package:ai_order_assistant/features/customers/domain/entities/customer.dart';
import 'package:ai_order_assistant/features/customers/presentation/notifier/customer_list_notifier.dart';
import 'package:ai_order_assistant/features/customers/presentation/widgets/customer_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng'),
        actions: [
          IconButton(
            onPressed: () => ref.read(customerListProvider.notifier).refresh(),
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
                  hintText: 'Tìm tên hoặc số điện thoại',
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
              child: customersState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                error: (error, _) => _CustomerErrorView(
                  message: error is Failure
                      ? error.message
                      : 'Không thể tải danh sách khách hàng.',
                  onRetry: () =>
                      ref.read(customerListProvider.notifier).refresh(),
                ),
                data: (customers) => customers.isEmpty
                    ? const _EmptyCustomersView()
                    : _CustomerTable(
                        customers: customers,
                        onRefresh: () =>
                            ref.read(customerListProvider.notifier).refresh(),
                        onEdit: _openCustomerForm,
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
          child: FilledButton.icon(
            onPressed: () => _openCustomerForm(),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('THÊM KHÁCH HÀNG'),
          ),
        ),
      ),
    );
  }

  void _search(String query) {
    ref.read(customerListProvider.notifier).search(query);
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

  Future<void> _openCustomerForm([Customer? customer]) async {
    final value = await showDialog<CustomerFormValue>(
      context: context,
      builder: (context) => CustomerFormDialog(customer: customer),
    );
    if (value == null) return;

    final notifier = ref.read(customerListProvider.notifier);
    if (customer == null) {
      await notifier.createCustomer(
        name: value.name,
        phone: value.phone,
        note: value.note,
      );
    } else {
      await notifier.updateCustomer(
        id: customer.id,
        name: value.name,
        phone: value.phone,
        note: value.note,
      );
    }
  }

  Future<void> _confirmDelete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khách hàng?'),
        content: Text(
          '${customer.name} sẽ bị xóa khỏi danh sách khách hàng. '
          'Các đơn hàng cũ vẫn được giữ nguyên. '
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
      await ref.read(customerListProvider.notifier).deleteCustomer(
        customer.id,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

const _customerColumnWidths = <int, TableColumnWidth>{
  0: FlexColumnWidth(1.9),
  1: FlexColumnWidth(1.3),
  2: FlexColumnWidth(1.9),
  3: FlexColumnWidth(1.42),
};

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({
    required this.customers,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Customer> customers;
  final Future<void> Function() onRefresh;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDelete;

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
          const _CustomerTableHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return _CustomerTableRow(
                    customer: customer,
                    onEdit: () => onEdit(customer),
                    onDelete: () => onDelete(customer),
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

class _CustomerTableHeader extends StatelessWidget {
  const _CustomerTableHeader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEAF6EF),
      child: Table(
        columnWidths: _customerColumnWidths,
        children: const [
          TableRow(
            children: [
              _CustomerHeaderCell('Tên khách hàng'),
              _CustomerHeaderCell('SĐT'),
              _CustomerHeaderCell('Ghi chú'),
              _CustomerHeaderCell('Thao tác', centered: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerHeaderCell extends StatelessWidget {
  const _CustomerHeaderCell(this.label, {this.centered = false});

  final String label;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      child: Text(
        label,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          color: Color(0xFF155E38),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CustomerTableRow extends StatelessWidget {
  const _CustomerTableRow({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E6E4))),
      ),
      child: Table(
        columnWidths: _customerColumnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _CustomerCell(
                child: Text(
                  customer.name,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _CustomerCell(
                child: Text(
                  (customer.phone == null || customer.phone!.isEmpty)
                      ? '—'
                      : customer.phone!,
                  softWrap: true,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              _CustomerCell(
                child: Text(
                  (customer.note == null || customer.note!.isEmpty)
                      ? '—'
                      : customer.note!,
                  softWrap: true,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              _CustomerCell(
                centered: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      style: _customerActionStyle(),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('SỬA'),
                    ),
                    const SizedBox(height: 5),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      style: _customerActionStyle(),
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

class _CustomerCell extends StatelessWidget {
  const _CustomerCell({required this.child, this.centered = false});

  final Widget child;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 82),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

ButtonStyle _customerActionStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(76, 32),
  padding: const EdgeInsets.symmetric(horizontal: 7),
  textStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
);

class _EmptyCustomersView extends StatelessWidget {
  const _EmptyCustomersView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có khách hàng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Bấm THÊM KHÁCH HÀNG để tạo khách hàng đầu tiên.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerErrorView extends StatelessWidget {
  const _CustomerErrorView({required this.message, required this.onRetry});

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
