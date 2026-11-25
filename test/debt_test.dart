import 'package:flutter_test/flutter_test.dart';

import 'package:balance_tg_flutter/models/app_state.dart';
import 'package:balance_tg_flutter/state/app_controller.dart';
import 'package:balance_tg_flutter/widgets/ui.dart';

void main() {
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  test('остаток долга уменьшается только на реально погашенную сумму', () {
    final s = AppState.empty();
    s.debts.add(Debt(id: 'a', name: 'Долг А', amount: 10000));
    s.history.add(Entry(
      id: 'p1',
      type: 'day',
      date: key(DateTime.now()),
      income: 5000,
      expenses: {},
      debtPays: {'a': 3000},
      savings: {},
      savSpend: {},
      autoItems: [],
      autoMk: [],
    ));

    final c = recalc(s);
    expect(c.debtRemain['a'], closeTo(7000, 0.01));
    expect(c.debtTotal, closeTo(7000, 0.01));
    expect(c.debtPaid, closeTo(3000, 0.01));
  });

  test('платёж больше остатка не уводит долг в минус', () {
    final s = AppState.empty();
    s.debts.add(Debt(id: 'b', name: 'Долг Б', amount: 1000));
    s.history.add(Entry(
      id: 'p2',
      type: 'day',
      date: key(DateTime.now()),
      income: 5000,
      expenses: {},
      debtPays: {'b': 5000},
      savings: {},
      savSpend: {},
      autoItems: [],
      autoMk: [],
    ));
    final c = recalc(s);
    expect(c.debtRemain['b'], 0);
    expect(c.debtTotal, 0);
  });

  test('рек. платёж = остаток ÷ дни до срока, просрочка — весь остаток', () {
    final s = AppState.empty();
    final today = DateTime.now();
    final due = today.add(const Duration(days: 9));
    s.debts.add(Debt(id: 'c', name: 'Долг В', amount: 10000, due: key(due)));
    final calc = recalc(s);
    final rec = debtRec(s, calc, s.debts.first);
    expect(rec.daysLeft, 10);
    expect(rec.perDay, closeTo(1000, 0.01));
    expect(fmtRec(rec.perDay!), '1 000');

    s.debts[0] = Debt(
      id: 'c', name: 'Долг В', amount: 10000,
      due: key(today.subtract(const Duration(days: 3))),
    );
    final overdue = debtRec(s, calc, s.debts.first);
    expect(overdue.overdue, isTrue);
    expect(overdue.daysLeft, 1);
    expect(overdue.perDay, closeTo(10000, 0.01));
  });

  test('долг с галочкой «деньги получил» остаётся в остатке', () {
    final s = AppState.empty();
    s.debts.add(Debt(id: 'd', name: 'Долг Г', amount: 5000));
    s.history.add(Entry(
      id: 'ev',
      type: 'debt',
      date: key(DateTime.now()),
      income: 0,
      expenses: {},
      debtPays: {},
      savings: {},
      savSpend: {},
      debtId: 'd',
      debtAmt: 5000,
      creditCash: true,
      autoItems: [],
      autoMk: [],
    ));
    final c = recalc(s);
    expect(c.debtRemain['d'], closeTo(5000, 0.01));
    expect(c.cash, closeTo(5000, 0.01));
  });
}
