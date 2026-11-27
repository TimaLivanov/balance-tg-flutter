import '../models/app_state.dart';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Рабочий день — день с записью и доходом, выходной — прошедший день
/// с записью, но без дохода. Дни, о которых нет данных, не учитываются:
/// иначе 27 дней истории превращаются в 90 «выходных».
Map<String, dynamic> workStats(AppState state, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);
  final incomeByDate = <String, double>{};
  final daysWithData = <String>{};

  for (final h in state.history) {
    if (h.type == 'debt' ||
        h.type == 'goal_spend' ||
        h.type == 'invest_close') {
      continue;
    }
    if (h.date.isEmpty) continue;
    daysWithData.add(h.date);
    incomeByDate[h.date] = (incomeByDate[h.date] ?? 0) + h.income;
  }

  final offByDow = List<int>.filled(7, 0);
  var work = 0;
  var off = 0;

  for (var i = 89; i >= 1; i--) {
    final d = today.subtract(Duration(days: i));
    final key = dateKey(d);
    // Сегодня ещё может не быть записи, а дни без данных не считаем.
    if (!daysWithData.contains(key)) continue;
    final dow = (d.weekday - 1) % 7;
    if ((incomeByDate[key] ?? 0) > 0.004) {
      work++;
    } else {
      off++;
      offByDow[dow]++;
    }
  }

  var maxOff = -1;
  var maxI = 0;
  for (var i = 0; i < 7; i++) {
    if (offByDow[i] > maxOff) {
      maxOff = offByDow[i];
      maxI = i;
    }
  }

  DateTime? nextGuess;
  if (maxOff > 0) {
    for (var k = 1; k <= 14; k++) {
      final d = today.add(Duration(days: k));
      if ((d.weekday - 1) % 7 == maxI) {
        nextGuess = d;
        break;
      }
    }
  }

  return {
    'work': work,
    'off': off,
    'offByDow': offByDow,
    'maxI': maxI,
    'maxOff': maxOff,
    'next': nextGuess,
  };
}
