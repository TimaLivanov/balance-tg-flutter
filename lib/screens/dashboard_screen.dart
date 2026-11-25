import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/balance_chart.dart';
import '../widgets/ui.dart';

class DashboardScreen extends StatefulWidget {
  final AppController controller;
  const DashboardScreen({super.key, required this.controller});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String _tf;
  late bool _candle;
  bool _ma = false;
  double _zoom = 1;
  bool _formExpanded = false;

  final _quickIncome = TextEditingController();
  final _quickExpense = TextEditingController();
  final _quickNote = TextEditingController();
  String? _quickIncomeCat;
  String? _quickExpCat;
  int _quickOffset = 0;

  final _income = TextEditingController();
  final _cushIn = TextEditingController();
  final _cushOut = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _exp = {};
  final Map<String, TextEditingController> _debts = {};
  final Map<String, TextEditingController> _savings = {};
  DateTime _entryDate = DateTime.now();

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _tf = c.state.tf;
    _candle = c.state.chartMode == 'candle';
  }

  @override
  void dispose() {
    _quickIncome.dispose();
    _quickExpense.dispose();
    _quickNote.dispose();
    _income.dispose();
    _cushIn.dispose();
    _cushOut.dispose();
    _note.dispose();
    for (final v in _exp.values) {
      v.dispose();
    }
    for (final v in _debts.values) {
      v.dispose();
    }
    for (final v in _savings.values) {
      v.dispose();
    }
    super.dispose();
  }

  String get _today => _dateStr(DateTime.now().add(Duration(days: _quickOffset)));

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _num(TextEditingController ctrl) => double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;

  String _shown(double v, {String suffix = ' ₽'}) =>
      c.state.hideBal ? '••••' : '${fmtMoney(v)}$suffix';

  void _setTf(String tf) {
    setState(() => _tf = tf);
    c.updateSetting((s) => s.tf = tf);
  }

  void _setMode(bool candle) {
    setState(() => _candle = candle);
    c.updateSetting((s) => s.chartMode = candle ? 'candle' : 'line');
  }

  void _quickDo(String kind) {
    final date = _today;
    if (kind == 'inc') {
      final amt = _num(_quickIncome);
      if (amt <= 0) return _toast('Введите сумму дохода');
      _quickIncomeCat ??= c.state.incomeCats.isNotEmpty ? c.state.incomeCats.first.id : '1';
      c.saveDayEntry(
        date: date,
        income: amt,
        expenses: {},
        debtPays: {},
        savings: {},
        note: _quickNote.text.trim().isEmpty ? 'быстрая запись' : _quickNote.text.trim(),
      );
      _quickIncome.clear();
      _quickNote.clear();
      _toast('Доход записан');
      return;
    }
    final amt = _num(_quickExpense);
    if (amt <= 0) return _toast('Введите сумму расхода');
    final sel = _quickExpCat ?? '';
    final expenses = <String, double>{};
    final pays = <String, double>{};
    double cushIn = 0;
    if (sel == 'cush') {
      cushIn = amt;
    } else if (sel.startsWith('d:')) {
      pays[sel.substring(2)] = amt;
    } else if (sel.startsWith('c:')) {
      expenses[sel.substring(2)] = amt;
    } else {
      return _toast('Выберите категорию');
    }
    c.saveDayEntry(
      date: date,
      income: 0,
      expenses: expenses,
      debtPays: pays,
      savings: {},
      cushIn: cushIn,
      note: _quickNote.text.trim().isEmpty ? 'быстрая запись' : _quickNote.text.trim(),
    );
    _quickExpense.clear();
    _quickNote.clear();
    _toast('Расход записан');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _submitFull() {
    final exp = <String, double>{};
    _exp.forEach((k, v) {
      final val = _num(v);
      if (val > 0) exp[k] = val;
    });
    final pays = <String, double>{};
    _debts.forEach((k, v) {
      final val = _num(v);
      if (val > 0) pays[k] = val;
    });
    final sav = <String, double>{};
    _savings.forEach((k, v) {
      final val = _num(v);
      if (val > 0) sav[k] = val;
    });
    final income = _num(_income);
    final ci = _num(_cushIn);
    final co = _num(_cushOut);
    if (income <= 0 && exp.isEmpty && pays.isEmpty && sav.isEmpty && ci <= 0 && co <= 0) {
      _toast('Введите хотя бы одну сумму');
      return;
    }
    c.saveDayEntry(
      date: _dateStr(_entryDate),
      income: income,
      expenses: exp,
      debtPays: pays,
      savings: sav,
      cushIn: ci,
      cushOut: co,
      note: _note.text.trim(),
    );
    _income.clear();
    _cushIn.clear();
    _cushOut.clear();
    _note.clear();
    for (final v in [..._exp.values, ..._debts.values, ..._savings.values]) {
      v.clear();
    }
    _toast('День проведён');
  }

  @override
  Widget build(BuildContext context) {
    final calc = c.calc;
    final bars = buildBars(calc.points, _tf);
    final change = bars.isNotEmpty ? bars.last.close - bars.first.open : 0.0;
    final changePct = bars.isNotEmpty && bars.first.open != 0
        ? change / bars.first.open.abs() * 100
        : 0.0;
    final activeCats = c.state.cats.where((x) => !x.archived).toList();
    final openDebts = c.state.debts.where((x) => !x.archived).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BitBalance',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary)),
                        Text('Финансовый пульт',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Скрыть суммы',
                    onPressed: () => c.updateSetting((s) => s.hideBal = !s.hideBal),
                    icon: Icon(c.state.hideBal ? Icons.visibility_off : Icons.visibility),
                  ),
                  if (c.guest)
                    const Chip(
                      label: Text('Гость', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Hero
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Текущий баланс',
                          style: TextStyle(fontSize: 13, color: AppTheme.mutedLight)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _shown(calc.balance),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: calc.balance >= 0 ? AppTheme.textLight : AppTheme.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (change >= 0 ? AppTheme.success : AppTheme.danger)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${change >= 0 ? '+' : ''}${_shown(change)} · ${changePct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: change >= 0 ? AppTheme.success : AppTheme.danger,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('за период',
                              style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _metric('Копилка', _shown(calc.cash + calc.savingsTotal),
                                'своб. ${_shown(calc.cash)}', AppTheme.primary),
                          ),
                          Expanded(
                            child: _metric('Долги', _shown(calc.debtTotal), 'активные', AppTheme.danger),
                          ),
                          Expanded(
                            child: _metric('Подушка', _shown(calc.cushion), 'безопасность', AppTheme.success),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Подушка безопасности',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const Spacer(),
                          Text(
                            '${calc.cushionPct.toStringAsFixed(0)}% · ${c.state.cushionMonths} мес.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressLine(value: calc.cushionPct / 100, color: AppTheme.success),
                      const SizedBox(height: 6),
                      Text(
                        'Цель ${_shown(calc.cushionGoal)} · осталось ${_shown(calc.cushionRemaining)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // График
              SectionCard(
                title: 'Динамика баланса',
                subtitle: 'Свечи, линия и скользящие средние',
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
                        for (final t in ['День', 'Нед', 'Мес', 'Год'])
                          _pill(t, _tf == _tfKey(t), () => _setTf(_tfKey(t))),
                        _pill('Свечи', _candle, () => _setMode(true)),
                        _pill('Линия', !_candle, () => _setMode(false)),
                        _pill('＋', false, () => setState(() => _zoom = (_zoom + .25).clamp(0.5, 2.5))),
                        _pill('－', false, () => setState(() => _zoom = (_zoom - .25).clamp(0.5, 2.5))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (bars.isEmpty)
                      const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text('Проведите первый день — здесь появится график баланса',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.mutedLight, fontSize: 13)),
                        ),
                      )
                    else
                      BalanceChart(bars: bars, candle: _candle, ma: _ma, zoom: _zoom),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Быстрая запись
              SectionCard(
                title: 'Быстрая запись',
                subtitle: 'Доход или расход одним касанием',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _pill('Сегодня', _quickOffset == 0, () => setState(() => _quickOffset = 0)),
                        const SizedBox(width: 6),
                        _pill('Вчера', _quickOffset == -1, () => setState(() => _quickOffset = -1)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quickIncome,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Доход, ₽'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _quickIncomeCat ??
                                (c.state.incomeCats.isNotEmpty ? c.state.incomeCats.first.id : null),
                            decoration: const InputDecoration(labelText: 'Источник'),
                            items: c.state.incomeCats
                                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                                .toList(),
                            onChanged: (v) => setState(() => _quickIncomeCat = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quickExpense,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Расход, ₽'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _quickExpCat,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Куда'),
                            items: [
                              const DropdownMenuItem(value: 'cush', child: Text('Подушка')),
                              ...activeCats.map((e) =>
                                  DropdownMenuItem(value: 'c:${e.id}', child: Text(e.name))),
                              ...openDebts.map((e) =>
                                  DropdownMenuItem(value: 'd:${e.id}', child: Text('Долг: ${e.name}'))),
                            ],
                            onChanged: (v) => setState(() => _quickExpCat = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quickNote,
                      decoration: const InputDecoration(labelText: 'Примечание', hintText: 'необязательно'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _quickDo('inc'),
                            icon: const Icon(Icons.add),
                            label: const Text('Доход'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _quickDo('exp'),
                            icon: const Icon(Icons.remove),
                            label: const Text('Записать'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Полная запись дня
              SectionCard(
                title: 'Полная запись дня',
                subtitle: 'Доход, траты, долги, накопления и подушка',
                action: TextButton(
                  onPressed: () => setState(() => _formExpanded = !_formExpanded),
                  child: Text(_formExpanded ? 'Свернуть' : 'Открыть'),
                ),
                child: _formExpanded
                    ? _buildFullForm(activeCats, openDebts)
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Заполните поля одним касанием — всё в одном месте.',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullForm(List<Category> cats, List<Debt> debts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final d in [-2, -1, 0, 1])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _pill(
                  d == 0 ? 'Сегодня' : d == -1 ? 'Вчера' : d == -2 ? 'Позавчера' : 'Завтра',
                  _daysBetween(_entryDate, DateTime.now()) == d,
                  () => setState(() => _entryDate = DateTime.now().add(Duration(days: d))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: _dateStr(_entryDate)),
          decoration: const InputDecoration(labelText: 'Дата'),
        ),
        const SizedBox(height: 16),
        const Text('Доход', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _income,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Сумма, ₽'),
        ),
        const SizedBox(height: 16),
        const Text('Траты', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...cats.map((cat) {
          _exp.putIfAbsent(cat.id, () => TextEditingController());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _exp[cat.id],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: cat.name + (cat.need ? ' · обяз.' : ''),
              ),
            ),
          );
        }),
        if (debts.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Погашение долгов', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...debts.map((d) {
            _debts.putIfAbsent(d.id, () => TextEditingController());
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _debts[d.id],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: d.name),
              ),
            );
          }),
        ],
        if (c.state.savings.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Накопления и инвестиции', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...c.state.savings.where((g) => !g.archived).map((g) {
            _savings.putIfAbsent(g.id, () => TextEditingController());
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _savings[g.id],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Пополнить: ${g.name}'),
              ),
            );
          }),
        ],
        const SizedBox(height: 8),
        const Text('Подушка', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cushIn,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Пополнить, ₽'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _cushOut,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Снять, ₽'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Заметка'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _submitFull, child: const Text('Провести день')),
        ),
      ],
    );
  }

  int _daysBetween(DateTime a, DateTime b) =>
      DateTime(a.year, a.month, a.day).difference(DateTime(b.year, b.month, b.day)).inDays;

  String _tfKey(String label) => const {
        'День': 'day',
        'Нед': 'week',
        'Мес': 'month',
        'Год': 'year',
      }[label] ?? 'day';

  Widget _metric(String label, String value, String sub, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppTheme.mutedLight),
        ),
      ],
    );
  }

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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.mutedLight,
          ),
        ),
      ),
    );
  }
}
