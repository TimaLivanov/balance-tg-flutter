import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/models/app_state.dart';
import 'package:balance_tg_flutter/screens/home_screen.dart';
import 'package:balance_tg_flutter/state/app_controller.dart';
import 'package:balance_tg_flutter/theme/app_theme.dart';

void main() {
  testWidgets('история обновляется сразу после добавлении операции', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    expect(find.text('Пока нет операций'), findsOneWidget);

    // Добавляем запись напрямую в состояние и уведомляем слушателей,
    // как это делает форма Recording дня.
    controller.state.history.add(Entry(
      id: 'test-1',
      type: 'day',
      date: DateTime.now().toIso8601String().substring(0, 10),
      income: 1000,
      expenses: const {},
      debtPays: const {},
      savings: const {},
      savSpend: const {},
      autoItems: const [],
      autoMk: const [],
    ));
    controller.commit();
    await tester.pumpAndSettle();

    expect(find.text('Пока нет операций'), findsNothing);
    expect(find.textContaining('Доход'), findsWidgets);

    controller.dispose();
  });
}
