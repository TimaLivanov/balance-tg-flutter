import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/models/app_state.dart';
import 'package:balance_tg_flutter/state/app_controller.dart';
import 'package:balance_tg_flutter/widgets/balance_chart.dart';

void main() {
  test('свечи строятся из настоящих OHLC, а не из плоских закрытий', () {
    final state = AppState.empty();
    state.startCash = 100000;
    final today = DateTime.now();
    String key(int back) {
      final d = today.subtract(Duration(days: back));
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    Entry day(String id, int back, double income, double expense) => Entry(
      id: id,
      type: 'day',
      date: key(back),
      income: income,
      expenses: {'food': expense},
      debtPays: {},
      savings: {},
      savSpend: {},
      autoItems: [],
      autoMk: [],
    );

    state.history.addAll([
      day('1', 3, 50000, 10000),
      day('2', 2, 0, 7000),
      day('3', 1, 20000, 3000),
    ]);

    final calc = recalc(state);
    final bars = buildBars(calc.points, 'day');
    expect(bars.length, 4);
    expect(
      bars.any((b) => b.high > b.low),
      isTrue,
      reason: 'все свечи плоские — OHLC не попал в график',
    );
    expect(bars.last.close, closeTo(calc.balance, 0.01));
    expect(bars.first.open, closeTo(100000, 0.01));
  });

  testWidgets('масштаб графика меняется кнопками даже на коротком окне', (
    tester,
  ) async {
    final key = GlobalKey<BalanceChartState>();
    final bars = List.generate(
      14,
      (i) => Bar(
        date: '2026-01-01',
        label: '$i',
        open: 100 + i.toDouble(),
        high: 101 + i.toDouble(),
        low: 99 + i.toDouble(),
        close: 100 + i.toDouble(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BalanceChart(key: key, bars: bars, height: 200),
              TextButton(
                onPressed: () => key.currentState!.zoomIn(),
                child: const Text('Приблизить'),
              ),
              TextButton(
                onPressed: () => key.currentState!.zoomOut(),
                child: const Text('Отдалить'),
              ),
            ],
          ),
        ),
      ),
    );

    final start = key.currentState!.zoomFactor;
    final startVisible = key.currentState!.visibleCount;
    expect(startVisible, 14);

    await tester.tap(find.text('Приблизить'));
    await tester.pump();
    expect(key.currentState!.zoomFactor, greaterThan(start));
    expect(key.currentState!.visibleCount, lessThan(startVisible));

    final zoomed = key.currentState!.zoomFactor;
    final zoomedVisible = key.currentState!.visibleCount;
    await tester.tap(find.text('Отдалить'));
    await tester.pump();
    expect(key.currentState!.zoomFactor, lessThan(zoomed));
    expect(key.currentState!.visibleCount, greaterThan(zoomedVisible));
  });
}
