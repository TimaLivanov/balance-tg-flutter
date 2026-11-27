import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/models/app_state.dart';
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

    for (final label in ['Деньги', 'История', 'Настройки', 'Главная']) {
      final nav = find.text(label).first;
      expect(nav, findsOneWidget, reason: 'нет вкладки $label');
      await tester.tap(nav);
      await tester.pumpAndSettle();
      final err = tester.takeException();
      expect(err, isNull, reason: 'ошибка на вкладке $label: $err');
    }

    // Аналитика внутри «Денег», отчёт внутри «Истории», «+» по центру.
    await tester.tap(find.text('Деньги').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аналитика').first);
    await tester.pumpAndSettle();
    expect(find.text('Цифры и тренды'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('История').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отчёт').first);
    await tester.pumpAndSettle();
    expect(find.text('Выгрузка для консультанта'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Провести день'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('кнопка редактирования открывает полную запись', (tester) async {
    final controller = AppController();
    final today = DateTime.now();
    final key =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    controller.state.cats.add(Category(id: 'food', name: 'Продукты'));
    controller.state.history.add(
      Entry(
        id: 'edit-1',
        type: 'day',
        date: key,
        income: 1000,
        expenses: {'food': 300},
        debtPays: {},
        savings: {},
        savSpend: {},
        autoItems: [],
        autoMk: [],
      ),
    );
    controller.commit();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('История').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Редактирование операции'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);

    // Доход 1000 предзаполнен точным числом и не должен обнулиться
    // после добавления расхода.
    final incomeField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '1000',
    );
    expect(incomeField, findsOneWidget);
    final expenseField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '300',
    );
    expect(expenseField, findsOneWidget);
    await tester.enterText(expenseField, '500');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final saved = controller.state.history.singleWhere((e) => e.id == 'edit-1');
    expect(saved.income, 1000);
    expect(saved.expenses['food'], 500);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
