import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/screens/home_screen.dart';
import 'package:balance_tg_flutter/state/app_controller.dart';
import 'package:balance_tg_flutter/theme/app_theme.dart';

void main() {
  testWidgets('добавление времени уведомления видно сразу', (tester) async {
    final c = AppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final before = c.state.tgNotifyTimes.length;
    await tester.ensureVisible(find.text('Добавить время'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить время'));
    await tester.pumpAndSettle();

    expect(c.state.tgNotifyTimes.length, before + 1);
    expect(find.text('Отправка ${before + 1}'), findsOneWidget);
    c.dispose();
  });

  testWidgets('переключатель «Не исчезать» работает сразу', (tester) async {
    final c = AppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final switcher = find.byKey(const Key('toast-sticky-switch'));
    await tester.ensureVisible(switcher);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(c.state.toastSticky, isTrue);

    c.dispose();
  });
}
