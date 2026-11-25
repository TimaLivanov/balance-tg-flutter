import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/screens/home_screen.dart';
import 'package:balance_tg_flutter/state/app_controller.dart';
import 'package:balance_tg_flutter/theme/app_theme.dart';

void main() {
  testWidgets('все вкладки рендерятся без переполнения', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    for (final label in ['Деньги', 'Аналитика', 'История', 'Отчёт', 'Настройки', 'Главная']) {
      final nav = find.text(label);
      expect(nav, findsOneWidget, reason: 'нет вкладки $label');
      await tester.tap(nav);
      await tester.pumpAndSettle();
      final err = tester.takeException();
      expect(err, isNull, reason: 'ошибка на вкладке $label: $err');
    }
    controller.dispose();
  });
}
