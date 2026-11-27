import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/screens/home_screen.dart';
import 'package:balance_tg_flutter/state/app_controller.dart';
import 'package:balance_tg_flutter/theme/app_theme.dart';

void main() {
  testWidgets('все вкладки рендерятся без переполнения', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Деньги',
      'Аналитика',
      'История',
      'Настройки',
      'Главная',
    ]) {
      final nav = find.text(label);
      expect(nav, findsOneWidget, reason: 'нет вкладки $label');
      await tester.tap(nav);
      await tester.pumpAndSettle();
      final err = tester.takeException();
      expect(err, isNull, reason: 'ошибка на вкладке $label: $err');
    }

    // Отчёт теперь внутри истории, а полная запись открывается кнопкой «+».
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    final reportTab = find.text('Отчёт');
    expect(reportTab, findsOneWidget);
    await tester.tap(reportTab);
    await tester.pumpAndSettle();
    expect(find.text('Выгрузка для консультанта'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Провести день'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });
}
