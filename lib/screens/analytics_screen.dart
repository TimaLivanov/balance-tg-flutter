import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/balance_chart.dart';
import '../widgets/ui.dart';

class AnalyticsScreen extends StatefulWidget {
  final AppController controller;
  const AnalyticsScreen({super.key, required this.controller});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _Totals {
  double inc = 0;
  double exp = 0;
  double paid = 0;
  int days = 0;
  final Map<String, double> expBy = {};
  final Map<String, double> incBy = {};
}

class _HeatItem {
  final String name;
  final double amount;
  final double? pct;
  final double? prev;
  _HeatItem(this.name, this.amount, this.pct, this.prev);
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _period = 30;
  late String _anTf;
  bool _anCandle = true;
  bool _ma = true;
  double _zoom = 1;
  bool _expModeIncome = false;
  late DateTime _plusDate;
  final _question = TextEditingController();
  final _memory = TextEditingController();
  final _chat = <Map<String, String>>[];
  bool _aiLoading = false;
  String _memoryStatus = '';
  String _tip = '';

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _anTf = 'week';
    _plusDate = DateTime.now().add(const Duration(days: 90));
    _tip = _tipOfDay();
    _loadMemory();
    _loadHistory();
  }

  @override
  void dispose() {
    _question.dispose();
    _memory.dispose();
    super.dispose();
  }

  Future<void> _loadMemory() async {
    final text = await c.loadAiMemory();
    if (!mounted) return;
    setState(() {
      _memory.text = text;
      _memoryStatus = text.isEmpty ? 'Память пуста' : 'Память загружена';
    });
  }

  Future<void> _loadHistory() async {
    final items = await c.loadAiHistory();
    if (!mounted) return;
    setState(() {
      _chat.clear();
      _chat.addAll(items);
    });
  }

  Future<void> _ask() async {
    final q = _question.text.trim();
    if (q.isEmpty) {
      _toast('Напиши вопрос');
      return;
    }
    setState(() {
      _chat.add({'role': 'user', 'content': q});
      _question.clear();
      _aiLoading = true;
    });
    final answer = await c.askAi(q, c.buildAiContext());
    if (!mounted) return;
    setState(() {
      _chat.add({'role': 'assistant', 'content': answer});
      _aiLoading = false;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _tipOfDay() {
    const tips = [
      'Проверьте обязательные траты: их доля не должна превышать 50% дохода.',
      'Подушка безопасности снижает стресс. Добавьте хотя бы небольшую сумму.',
      'Раз в неделю пересчитывайте остатки по долгам.',
      'Маленькие регулярные накопления работают лучше больших, но редких.',
      'Сравните траты за месяц с прошлым — это покажет тренд.',
      'Если остаток после трат отрицательный, ищите статьи, которые можно урезать.',
    ];
    final index = DateTime.now().day % tips.length;
    return tips[index];
  }

  _Totals _calcTotals() {
    final now = DateTime.now();
    final from = _period == 9999
        ? DateTime(2000)
        : now.subtract(Duration(days: _period - 1));
    final t = _Totals();
    for (final h in c.state.history) {
      if (h.type != 'day') continue;
      final d = DateTime.tryParse(h.date);
      if (d == null || d.isBefore(from)) continue;
      t.days++;
      t.inc += h.income;
      t.exp += h.expenses.values.fold(0, (a, b) => a + b);
      t.paid += h.debtPays.values.fold(0, (a, b) => a + b);
      h.expenses.forEach((id, v) {
        final name = c.state.cats.where((x) => x.id == id).map((x) => x.name).firstOrNull ?? 'Прочее';
        t.expBy[name] = (t.expBy[name] ?? 0) + v;
      });
      if (h.income > 0) {
        final id = h.incomeCat ?? '1';
        final name = c.state.incomeCats
                .where((x) => x.id == id)
                .map((x) => x.name)
                .firstOrNull ??
            'Работа';
        t.incBy[name] = (t.incBy[name] ?? 0) + h.income;
      }
    }
    return t;
  }

  List<_HeatItem> _heatItems() {
    final needIds = c.state.cats
        .where((x) => x.need && !x.archived)
        .map((x) => x.id)
        .toList();
    final byCat = <String, List<Map<String, dynamic>>>{for (final id in needIds) id: []};
    final entries = List<Entry>.from(c.state.history)..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0);
      });
    for (final h in entries) {
      if (h.type == 'debt' || h.type == 'goal_spend' || h.type == 'invest_close') continue;
      for (final id in needIds) {
        final v = h.expenses[id] ?? 0;
        if (v > 0.004) byCat[id]!.add({'amount': v, 'date': h.date});
      }
    }
    final items = <_HeatItem>[];
    for (final id in needIds) {
      final arr = byCat[id]!;
      if (arr.isEmpty) continue;
      final last = arr.last['amount'] as double;
      final prev = arr.length > 1 ? arr[arr.length - 2]['amount'] as double : null;
      final pct = prev != null && prev > 0.004 ? (last - prev) / prev * 100 : null;
      final name = c.state.cats.where((x) => x.id == id).map((x) => x.name).firstOrNull ?? id;
      items.add(_HeatItem(name, last, pct, prev));
    }
    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  Map<String, dynamic> _workStats() {
    final now = DateTime.now();
    final incomeByDate = <String, double>{};
    for (final h in c.state.history) {
      if (h.type == 'debt' || h.type == 'goal_spend' || h.type == 'invest_close') continue;
      incomeByDate[h.date] = (incomeByDate[h.date] ?? 0) + h.income;
    }
    final offByDow = List<int>.filled(7, 0);
    int work = 0;
    int off = 0;
    for (var i = 89; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if (d.isAfter(DateTime(now.year, now.month, now.day))) continue;
      final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (key == '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}') continue;
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
        final d = DateTime(now.year, now.month, now.day).add(Duration(days: k));
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

  List<String> _plusIdeas(double netDay, double avgInc, double daysCount) {
    final ideas = <Map<String, dynamic>>[];
    final nD = daysCount < 1 ? 1 : daysCount;
    for (final h in _calcTotals().expBy.entries) {
      final cat = c.state.cats.where((x) => x.name == h.key).firstOrNull;
      if (cat == null || cat.need || cat.archived) continue;
      final dayAmt = h.value / nD;
      if (dayAmt < 1) continue;
      for (final pct in [0.1, 0.2, 0.5]) {
        final cut = dayAmt * pct;
        final gain = netDay > 0 && c.calc.debtTotal > 0
            ? c.calc.debtTotal / netDay - c.calc.debtTotal / (netDay + cut)
            : 0.0;
        ideas.add({
          'score': cut,
          'text': '«${cat.name}»: −${(pct * 100).round()}% (−${fmtMoney(cut)} ₽/день)'
              '${gain > 1 ? ' → долги на ≈ ${gain.round()} дн. раньше' : ' → в подушку/долг'}',
        });
      }
      if (cat.rare) {
        ideas.add({
          'score': dayAmt * 0.3,
          'text': 'Редкая «${cat.name}»: урезать на 30% (−${fmtMoney(dayAmt * 0.3)} ₽/день)',
        });
      }
    }
    if (avgInc > 0) {
      ideas.add({'score': avgInc * 0.05, 'text': 'Плюс 5% к доходу (+${fmtMoney(avgInc * 0.05)} ₽/день) — подработка, смена ставки'});
      ideas.add({'score': avgInc * 0.1, 'text': 'Плюс 10% к доходу (+${fmtMoney(avgInc * 0.1)} ₽/день)'});
    }
    if (c.calc.cushion > 100) {
      ideas.add({'score': 50, 'text': 'Не снимать с подушки без крайней нужды — иначе снова кассовый разрыв'});
    }
    ideas.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return ideas.take(8).map((e) => e['text'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = _calcTotals();
    final inc = t.inc;
    final exp = t.exp;
    final net = inc - exp - t.paid;
    final days = t.days;
    final netDay = days == 0 ? 0.0 : net / days;
    final avgInc = days == 0 ? 0.0 : inc / days;
    final bars = buildBars(c.calc.points, _anTf);
    final expBy = t.expBy.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final incBy = t.incBy.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxExp = expBy.isEmpty ? 1 : expBy.first.value;
    final maxInc = incBy.isEmpty ? 1 : incBy.first.value;
    final health = c.state.health;
    final heat = _heatItems();
    final work = _workStats();
    final daysLeft = DateTime(_plusDate.year, _plusDate.month, _plusDate.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    final dLeft = daysLeft < 1 ? 1 : daysLeft;
    final needPerDay = c.calc.debtTotal > 0 ? c.calc.debtTotal / dLeft : 0.0;
    final gap = needPerDay - (netDay > 0 ? netDay : 0);
    final ideas = _plusIdeas(netDay, avgInc, days.toDouble());

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              eyebrow: 'Аналитика',
              title: 'Цифры и тренды',
              subtitle: 'Здоровье денег, графики и прогнозы',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Период', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _period,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 дней')),
                    DropdownMenuItem(value: 30, child: Text('30 дней')),
                    DropdownMenuItem(value: 90, child: Text('90 дней')),
                    DropdownMenuItem(value: 365, child: Text('Год')),
                    DropdownMenuItem(value: 9999, child: Text('Всё время')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? 30),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _bigMetric('Доход', inc, AppTheme.success)),
                const SizedBox(width: 8),
                Expanded(child: _bigMetric('Траты', exp, AppTheme.danger)),
                const SizedBox(width: 8),
                Expanded(child: _bigMetric('Итог', net, net >= 0 ? AppTheme.success : AppTheme.danger)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Дней с записями: $days · на долги ушло ${fmtMoney(t.paid)} ₽',
                style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Здоровье денег',
              subtitle: 'Пороги из настроек',
              child: Column(
                children: [
                  _healthRow('Обязательные расходы',
                      inc > 0 ? '${(exp / inc * 100).toStringAsFixed(0)}% · не выше ${health.needsMax}%' : 'нет данных',
                      inc > 0 && exp / inc * 100 <= health.needsMax),
                  _healthRow('Остаток после трат',
                      inc > 0 ? '${(net / inc * 100).toStringAsFixed(0)}% · не ниже ${health.saveMin}%' : 'нет данных',
                      inc > 0 && net / inc * 100 >= health.saveMin),
                  _healthRow('Запас прочности',
                      exp > 0 ? '${((c.calc.cash + c.calc.cushion) / (exp / (days == 0 ? 1 : days))).toStringAsFixed(0)} дн. · не меньше ${health.runwayMin}' : 'нет данных',
                      exp > 0 && (c.calc.cash + c.calc.cushion) / (exp / (days == 0 ? 1 : days)) >= health.runwayMin),
                  _healthRow('Долги',
                      '${fmtMoney(c.calc.debtTotal)} ₽ · закрыть за ${health.debtMonths} мес.',
                      c.calc.debtTotal <= 0),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'График баланса',
              subtitle: 'MA 7/25 — скользящие средние по закрытию',
              action: TextButton(
                onPressed: () => setState(() => _ma = !_ma),
                child: Text('MA', style: TextStyle(color: _ma ? AppTheme.warning : AppTheme.mutedLight)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final label in ['День', 'Нед', 'Мес', 'Год'])
                        _pill(label, _anTf == _anTfKey(label), () => setState(() => _anTf = _anTfKey(label))),
                      _pill('Свечи', _anCandle, () => setState(() => _anCandle = true)),
                      _pill('Линия', !_anCandle, () => setState(() => _anCandle = false)),
                      _pill('＋', false, () => setState(() => _zoom = (_zoom + .25).clamp(0.5, 2.5))),
                      _pill('－', false, () => setState(() => _zoom = (_zoom - .25).clamp(0.5, 2.5))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (bars.isEmpty)
                    const SizedBox(
                      height: 180,
                      child: Center(child: Text('Проведите день, чтобы увидеть график',
                          style: TextStyle(color: AppTheme.mutedLight))),
                    )
                  else
                    BalanceChart(bars: bars, candle: _anCandle, ma: _ma, zoom: _zoom),
                  if (bars.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ohlc('Откр.', bars.first.open),
                        _ohlc('Макс.', bars.map((b) => b.high).reduce((a, b) => a > b ? a : b)),
                        _ohlc('Мин.', bars.map((b) => b.low).reduce((a, b) => a < b ? a : b)),
                        _ohlc('Закр.', bars.last.close),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Тепловая карта · обязательные',
              subtitle: 'Последнее пополнение к предыдущему: красный — рост, зелёный — спад',
              child: heat.isEmpty
                  ? const _NoData()
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: heat.map((h) => _heatTile(h, heat.first.amount)).toList(),
                    ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Главное',
              subtitle: 'Краткие выводы по цифрам',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _insight('Баланс', '${fmtMoney(c.calc.balance)} ₽'),
                  _insight('Доход в день', '${fmtMoney(avgInc)} ₽'),
                  _insight('Траты в день', '${fmtMoney(days == 0 ? 0 : exp / days)} ₽'),
                  _insight('Остаток до долгов', '${fmtMoney(net)} ₽'),
                  if (c.calc.debtTotal > 0 && netDay > 0)
                    _insight('Долги закроются через', '${(c.calc.debtTotal / netDay).round()} дн. '
                        '(≈ ${(c.calc.debtTotal / netDay / 30).round()} мес.)'),
                  if (expBy.isNotEmpty)
                    _insight('Больше всего уходит на', '${expBy.first.key}: ${fmtMoney(expBy.first.value)} ₽ '
                        '(${exp > 0 ? (expBy.first.value / exp * 100).round() : 0}% трат)'),
                  _insight('Прогноз на 30 дней',
                      '${fmtMoney(c.calc.balance + netDay * 30)} ₽'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Совет дня',
              child: Text(_tip, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'AI-советник',
              subtitle: 'Задай вопрос о своих финансах',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _question,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Например: что урезать в первую очередь?',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _aiLoading ? null : _ask,
                      icon: _aiLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Спросить'),
                    ),
                  ),
                  if (_chat.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ..._chat.map((m) => _chatBubble(m)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Память ИИ',
              subtitle: 'Персональные заметки для ИИ',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _memory,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Например: коплю на машину, цель 500000 ₽ к декабрю.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final r = await c.saveAiMemory(_memory.text);
                          if (!mounted) return;
                          setState(() => _memoryStatus = r);
                        },
                        child: const Text('Сохранить память'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final r = await c.clearAiMemory();
                          if (!mounted) return;
                          setState(() {
                            _memory.text = '';
                            _memoryStatus = r;
                          });
                        },
                        child: const Text('Очистить'),
                      ),
                      TextButton(onPressed: _loadHistory, child: const Text('Обновить историю')),
                    ],
                  ),
                  if (_memoryStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_memoryStatus,
                        style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Рабочие и выходные',
              subtitle: 'Рабочий день — с доходом, выходной — прошедший день без дохода',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _smallStat('Рабочих / 90 дн.', '${work['work']}', AppTheme.success)),
                      const SizedBox(width: 8),
                      Expanded(child: _smallStat('Выходных / 90 дн.', '${work['off']}', AppTheme.primary)),
                      const SizedBox(width: 8),
                      Expanded(child: _smallStat('Ср. раб. в мес.', '~${((work['work'] as int) / 3).round()}', AppTheme.textLight)),
                      const SizedBox(width: 8),
                      Expanded(child: _smallStat('Ср. вых. в мес.', '~${((work['off'] as int) / 3).round()}', AppTheme.textLight)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Выходные по дням недели (за 90 дн.)',
                      style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final active = i == work['maxI'] && (work['maxOff'] as int) > 0;
                      final names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.warning.withValues(alpha: .14) : AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${names[i]}: ${(work['offByDow'] as List<int>)[i]}',
                            style: TextStyle(
                                fontSize: 11,
                                color: active ? AppTheme.warning : AppTheme.mutedLight)),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  if ((work['maxOff'] as int) > 0)
                    Text(
                      'Чаще всего выходной: ${['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'][work['maxI'] as int]} '
                      '(${work['maxOff']} раз).'
                      '${work['next'] != null ? ' Ближайший такой день: ${_dateRu(work['next'] as DateTime)}.' : ''}',
                      style: const TextStyle(fontSize: 12),
                    )
                  else
                    const Text('Мало данных для прогноза выходного.',
                        style: TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Как выйти в плюс',
              subtitle: 'План по долгам к выбранной дате',
              action: TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _plusDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _plusDate = picked);
                },
                icon: const Icon(Icons.event, size: 16),
                label: Text(_dateRu(_plusDate)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Цель: к ${_dateRu(_plusDate)} ($dLeft дн.)',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  if (c.calc.debtTotal <= 0)
                    const Text('✅ Долгов нет. Укрепите подушку и накопления.',
                        style: TextStyle(fontSize: 12, color: AppTheme.success))
                  else ...[
                    Text('Нужно направлять на долги ≈ ${fmtMoney(needPerDay)} ₽/день, '
                        'сейчас поток ≈ ${fmtMoney(netDay)} ₽/день.',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      gap > 0.004
                          ? 'Не хватает ≈ ${fmtMoney(gap)} ₽/день до плана.'
                          : 'Текущего потока хватает, если держать темп.',
                      style: TextStyle(
                          fontSize: 12,
                          color: gap > 0.004 ? AppTheme.warning : AppTheme.success),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text('Что сделать (обязательные не трогаем):',
                      style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
                  const SizedBox(height: 4),
                  if (ideas.isEmpty)
                    const Text('Пока мало необязательных трат — заведите учёт «хотелок» отдельно.',
                        style: TextStyle(fontSize: 12, color: AppTheme.mutedLight))
                  else
                    ...ideas.map((x) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $x', style: const TextStyle(fontSize: 12)),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Расходы по категориям',
              subtitle: exp > 0 ? 'Всего ${fmtMoney(exp)} ₽ · $modeLabel' : 'нет данных',
              action: TextButton(
                onPressed: () => setState(() => _expModeIncome = !_expModeIncome),
                child: Text(_expModeIncome ? 'доля от дохода' : 'доля от трат',
                    style: const TextStyle(fontSize: 11)),
              ),
              child: expBy.isEmpty
                  ? const _NoData()
                  : Column(
                      children: expBy.take(10).map((e) {
                        final base = _expModeIncome ? inc : exp;
                        final pct = base > 0 ? e.value / base : 0.0;
                        return _barRow(e.key, e.value, pct, e.value / maxExp);
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Доходы по категориям',
              subtitle: inc > 0 ? 'Всего ${fmtMoney(inc)} ₽' : 'нет данных',
              child: incBy.isEmpty
                  ? const _NoData()
                  : Column(
                      children: incBy.map((e) {
                        final pct = inc > 0 ? e.value / inc : 0.0;
                        return _barRow(e.key, e.value, pct, e.value / maxInc, green: true);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String get modeLabel => _expModeIncome ? 'доля от дохода' : 'доля от трат';

  String _dateRu(DateTime d) =>
      '${d.day} ${const ['', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'][d.month]} ${d.year}';

  Widget _heatTile(_HeatItem h, double max) {
    Color color;
    if (h.pct == null) {
      color = AppTheme.mutedLight;
    } else if (h.pct! > 0.05) {
      color = AppTheme.danger.withValues(alpha: (0.35 + (h.pct!.clamp(0, 40) / 40) * 0.55).clamp(0, 1));
    } else if (h.pct! < -0.05) {
      color = AppTheme.success.withValues(alpha: (0.35 + ((-h.pct!).clamp(0, 40) / 40) * 0.55).clamp(0, 1));
    } else {
      color = AppTheme.mutedLight;
    }
    final weight = max > 0 ? (h.amount / max * 100).clamp(22.0, 100.0) : 22.0;
    return SizedBox(
      width: weight + 90,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text(
              h.pct == null
                  ? '—'
                  : '${h.pct! >= 0 ? '↑' : '↓'} ${h.pct!.abs().toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              '${fmtMoney(h.amount)} ₽${h.prev != null ? ' ← ${fmtMoney(h.prev!)} ₽' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barRow(String label, double value, double pct, double widthCoeff, {bool green = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
              Text('${fmtMoney(value)} ₽ · ${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: widthCoeff.clamp(0, 1),
              color: green
                  ? AppTheme.success
                  : HSLColor.fromAHSL(1, 120 * (1 - pct), .7, .5).toColor(),
              backgroundColor: AppTheme.bgLight,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ohlc(String label, double value) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.mutedLight)),
          FittedBox(
            child: Text(fmtMoney(value),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      );

  Widget _smallStat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppTheme.mutedLight)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );

  Widget _bigMetric(String label, double v, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${fmtMoney(v)} ₽',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      );

  Widget _healthRow(String label, String value, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.warning_amber,
                size: 16, color: ok ? AppTheme.success : AppTheme.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(value, style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
          ],
        ),
      );

  Widget _insight(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Flexible(child: Text(value, textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      );

  Widget _chatBubble(Map<String, String> m) {
    final user = m['role'] == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        decoration: BoxDecoration(
          color: user ? AppTheme.primary : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          m['content'] ?? '',
          style: TextStyle(fontSize: 12, color: user ? Colors.white : AppTheme.textLight),
        ),
      ),
    );
  }

  String _anTfKey(String label) => const {
        'День': 'day',
        'Нед': 'week',
        'Мес': 'month',
        'Год': 'year',
      }[label] ?? 'week';

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.borderLight),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active ? Colors.white : AppTheme.mutedLight,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Нет данных за период', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
      );
}
