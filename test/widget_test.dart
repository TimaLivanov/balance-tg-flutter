import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/app.dart';

void main() {
  testWidgets('smoke', (tester) async {
    await tester.pumpWidget(const BalanceApp());
  });
}
