import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/models/app_state.dart';
import 'package:balance_tg_flutter/utils/work_stats.dart';

void main() {
  test(
    'выходными считаются только дни с записью, а не все 90 календарных дней',
    () {
      final now = DateTime(2026, 11, 27);
      final s = AppState.empty();

      Entry day(DateTime d, double income) => Entry(
        id: 'd-${dateKey(d)}',
        type: 'day',
        date: dateKey(d),
        income: income,
        expenses: const {},
        debtPays: const {},
        savings: const {},
        savSpend: const {},
        autoItems: const [],
        autoMk: const [],
      );

      // 27 дней истории: 26 с доходом и 1 без дохода.
      for (var i = 1; i <= 27; i++) {
        s.history.add(day(now.subtract(Duration(days: i)), i == 5 ? 0 : 1000));
      }
      // Сегодняшний день ещё не закончился и в статистику не попадает.
      s.history.add(day(now, 0));

      final r = workStats(s, now: now);
      expect(r['work'], 26);
      expect(r['off'], 1);
      expect((r['offByDow'] as List<int>).fold<int>(0, (a, b) => a + b), 1);
    },
  );
}
