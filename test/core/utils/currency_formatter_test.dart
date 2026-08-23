import 'package:ai_order_assistant/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats integer VND with dot separators', () {
    expect(formatVnd(525000), '525.000 ₫');
    expect(formatVnd(1050000), '1.050.000 ₫');
  });
}
