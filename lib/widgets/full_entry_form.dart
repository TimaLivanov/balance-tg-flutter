import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Полная запись дня. Вынесена с главной и открывается центральной кнопкой
/// «+» в нижней навигации.
class FullEntryForm extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onDone;

  /// Если передана запись, форма открывается в режиме её редактирования.
  final Entry? editing;

  const FullEntryForm({
    super.key,
    required this.controller,
    this.onDone,
    this.editing,
  });

  @override
  State<FullEntryForm> createState() => _FullEntryFormState();
}

class _FullEntryFormState extends State<FullEntryForm> {
  AppController get c => widget.controller;

  final _income = TextEditingController();
  final _cushIn = TextEditingController();
  final _cushOut = TextEditingController();
  final _note = TextEditingController();
  final _dateCtrl = TextEditingController();
  final Map<String, TextEditingController> _exp = {};
  final Map<String, TextEditingController> _debts = {};
  final Map<String, TextEditingController> _savings = {};
  DateTime _entryDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  void initState() {
    super.initState();
    final edit = widget.editing;
    if (edit != null) {
      _entryDate = DateTime.tryParse(edit.date) ?? DateTime.now();
      _income.text = edit.income > 0 ? _inputAmount(edit.income) : '';
      _cushIn.text = edit.cushIn > 0 ? _inputAmount(edit.cushIn) : '';
      _cushOut.text = edit.cushOut > 0 ? _inputAmount(edit.cushOut) : '';
      _note.text = edit.note;
      _exp.addAll({
        for (final e in edit.expenses.entries)
          if (e.value > 0)
            e.key: TextEditingController(text: _inputAmount(e.value)),
      });
      _debts.addAll({
        for (final e in edit.debtPays.entries)
          if (e.value > 0)
            e.key: TextEditingController(text: _inputAmount(e.value)),
      });
      _savings.addAll({
        for (final e in edit.savings.entries)
          if (e.value > 0)
            e.key: TextEditingController(text: _inputAmount(e.value)),
      });
    }
    _dateCtrl.text = fmtDateRu(_dateStr(_entryDate));
  }

  @override
  void dispose() {
    _income.dispose();
    _cushIn.dispose();
    _cushOut.dispose();
    _note.dispose();
    _dateCtrl.dispose();
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

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Точное значение для поля ввода: без пробелов разрядов и без округления
  /// до сотен, которое применяют рекомендации.
  static String _inputAmount(double v) =>
      v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

  double _num(TextEditingController ctrl) =>
      double.tryParse(
        ctrl.text.replaceAll(RegExp(r'[\s\u00A0]'), '').replaceAll(',', '.'),
      ) ??
      0;

  String _shown(double v, {String suffix = ' ₽'}) =>
      c.state.hideBal ? '••••' : '${fmtMoney(v)}$suffix';

  void _toast(String msg) {
    if (!mounted) return;
    appToast(context, msg, c.state);
  }

  void _setEntryDate(DateTime d) {
    final picked = DateTime(d.year, d.month, d.day);
    setState(() {
      _entryDate = picked;
      _dateCtrl.text = fmtDateRu(_dateStr(picked));
    });
  }

  /// Дата выбирается календарём, а не только кнопками «вчера/сегодня/завтра».
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ru'),
    );
    if (picked != null) _setEntryDate(picked);
  }

  int _daysBetween(DateTime a, DateTime b) => DateTime(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime(b.year, b.month, b.day)).inDays;

  void _fillRec(TextEditingController ctrl, double value) {
    setState(() => ctrl.text = fmtRec(value));
  }

  Widget _recChip(
    String label,
    String value,
    VoidCallback onTap, {
    Color? color,
  }) {
    final chipColor = color ?? AppTheme.primary;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: chipColor,
        side: BorderSide(color: chipColor.withValues(alpha: 0.55)),
      ),
      onPressed: onTap,
      child: Text('$label $value', style: const TextStyle(fontSize: 11)),
    );
  }

  ({double avgDay, double? minDay}) _goalStats(SavingsGoal g) {
    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final win = c.state.windowDays < 1 ? 30 : c.state.windowDays;
    final from = _dateStr(today.subtract(Duration(days: win - 1)));
    var spentWin = 0.0;
    var funded = 0.0;
    final daysWith = <String>{};
    for (final e in c.state.history) {
      if (e.type == 'debt') continue;
      final add = e.savings[g.id] ?? 0;
      funded += add - (e.savSpend[g.id] ?? 0);
      if (add > 0 &&
          e.date.compareTo(from) >= 0 &&
          e.date.compareTo(todayStr) <= 0) {
        spentWin += add;
        daysWith.add(e.date);
      }
    }
    final avgDay = spentWin / (daysWith.isEmpty ? 1 : daysWith.length);
    double? minDay;
    final plan = g.plan;
    if (plan != null && plan.amount > 0) {
      final remaining = plan.amount - funded;
      if (remaining > 0.004 && plan.date.isNotEmpty) {
        final due = DateTime.tryParse(plan.date);
        if (due != null) {
          final raw = _daysBetween(due, today) + 1;
          minDay = remaining / (raw < 1 ? 1 : raw);
        }
      }
    }
    return (avgDay: avgDay, minDay: minDay);
  }

  void _submit() {
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
    if (income <= 0 &&
        exp.isEmpty &&
        pays.isEmpty &&
        sav.isEmpty &&
        ci <= 0 &&
        co <= 0) {
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
      editingId: widget.editing?.id,
    );
    _toast(widget.editing == null ? 'День проведён' : 'Операция обновлена');
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final calc = c.calc;
    final cats = c.state.cats.where((x) => !x.archived).toList();
    final debts = c.state.debts
        .where(
          (x) => !x.archived && (calc.debtRemain[x.id] ?? x.amount) > 0.004,
        )
        .toList();
    final goals = c.state.savings.where((g) => !g.archived).toList();
    final stats = {for (final cat in cats) cat.id: catStats(c.state, cat)};
    final catRecSum = stats.values.fold(
      0.0,
      (sum, st) => sum + (st.avgDay > 0.004 ? st.avgDay : 0),
    );
    final catMinSum = stats.values.fold(
      0.0,
      (sum, st) => sum + ((st.minDay ?? 0) > 0.004 ? st.minDay! : 0),
    );
    final goalStats = {for (final g in goals) g.id: _goalStats(g)};

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.editing == null
                          ? 'Полная запись дня'
                          : 'Редактирование операции',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Доход, траты, долги, накопления и подушка',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final d in [-2, -1, 0, 1])
                      _DatePill(
                        d == 0
                            ? 'Сегодня'
                            : d == -1
                            ? 'Вчера'
                            : d == -2
                            ? 'Позавчера'
                            : 'Завтра',
                        _daysBetween(_entryDate, DateTime.now()) == d,
                        () => _setEntryDate(
                          DateTime.now().add(Duration(days: d)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  readOnly: true,
                  controller: _dateCtrl,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Дата',
                    suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Доход',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _income,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Сумма, ₽'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Траты',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (catRecSum > 0.004 || catMinSum > 0.004) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (catRecSum > 0.004)
                        'рек. ${fmtRec(catRecSum)} ₽ / день',
                      if (catMinSum > 0.004)
                        'мин. ${fmtRec(catMinSum)} ₽ / день',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
                const SizedBox(height: 8),
                ...cats.map((cat) {
                  _exp.putIfAbsent(cat.id, () => TextEditingController());
                  final st = stats[cat.id]!;
                  final buttons = <Widget>[];
                  if (st.avgDay > 0.004) {
                    buttons.add(
                      _recChip(
                        'рек.',
                        fmtRec(st.avgDay),
                        () => _fillRec(_exp[cat.id]!, st.avgDay),
                      ),
                    );
                  }
                  if ((st.minDay ?? 0) > 0.004) {
                    buttons.add(
                      _recChip(
                        'мин.',
                        fmtRec(st.minDay!),
                        () => _fillRec(_exp[cat.id]!, st.minDay!),
                        color: AppTheme.success,
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _exp[cat.id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: cat.name + (cat.need ? ' · обяз.' : ''),
                          ),
                        ),
                        if (buttons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Wrap(spacing: 6, children: buttons),
                          ),
                      ],
                    ),
                  );
                }),
                if (debts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Погашение долгов',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'мин. всего ${fmtRec(debtMinSum(c.state, calc))} ₽ / день · '
                    'рек. платёж = остаток ÷ дни до срока',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 8),
                  ...debts.map((d) {
                    _debts.putIfAbsent(d.id, () => TextEditingController());
                    final rec = debtRec(c.state, calc, d);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _debts[d.id],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    '${d.name} · остаток ${_shown(rec.remain)}',
                              ),
                            ),
                          ),
                          if (rec.perDay != null && rec.perDay! > 0.004)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 6),
                              child: _recChip(
                                'рек.',
                                fmtRec(rec.perDay!),
                                () => _fillRec(_debts[d.id]!, rec.perDay!),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Накопления и инвестиции',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...goals.map((g) {
                    _savings.putIfAbsent(g.id, () => TextEditingController());
                    final st = goalStats[g.id]!;
                    final buttons = <Widget>[];
                    if (st.avgDay > 0.004) {
                      buttons.add(
                        _recChip(
                          'рек.',
                          fmtRec(st.avgDay),
                          () => _fillRec(_savings[g.id]!, st.avgDay),
                        ),
                      );
                    }
                    if (g.kind != 'invest' && (st.minDay ?? 0) > 0.004) {
                      buttons.add(
                        _recChip(
                          'мин.',
                          fmtRec(st.minDay!),
                          () => _fillRec(_savings[g.id]!, st.minDay!),
                          color: AppTheme.success,
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _savings[g.id],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Пополнить: ${g.name}',
                            ),
                          ),
                          if (buttons.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Wrap(spacing: 6, children: buttons),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Подушка',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cushIn,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Пополнить, ₽',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cushOut,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Снять, ₽',
                        ),
                      ),
                    ),
                  ],
                ),
                if (calc.cushionRecPerDay > 0.004) ...[
                  const SizedBox(height: 6),
                  _recChip(
                    'рек.',
                    fmtRec(calc.cushionRecPerDay),
                    () => _fillRec(_cushIn, calc.cushionRecPerDay),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Заметка'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.editing == null ? 'Провести день' : 'Сохранить',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DatePill(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.14)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppTheme.primary : AppTheme.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
