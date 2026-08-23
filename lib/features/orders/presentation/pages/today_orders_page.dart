import 'package:ai_order_assistant/shared/widgets/feature_placeholder.dart';
import 'package:flutter/material.dart';

class TodayOrdersPage extends StatelessWidget {
  const TodayOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hôm nay')),
      body: const FeaturePlaceholder(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có đơn hôm nay',
        description:
            'Danh sách đơn sẽ được kết nối với Orders API sau khi hoàn thành '
            'danh mục sản phẩm và luồng xác nhận đơn.',
      ),
    );
  }
}
