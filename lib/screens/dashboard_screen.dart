import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/balance_chart.dart';
import '../widgets/ui.dart';
import 'chart_fullscreen_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AppController controller;
  const DashboardScreen({super.key, required this.controller});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String _tf;
  late bool _candle;
  bool _ma = true;
  bool _volume = true;
  double _zoom = 1;
  final _chartKey = GlobalKey<BalanceChartState>();

  final _quickIncome = TextEditingController();
  final _quickExpense = TextEditingController();
  final _quickNote = TextEditingController();
  String? _quickIncomeCat;
  String? _quickExpCat;
  int _quickOffset = 0;

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
    super.dispose();
  }

  String get _today =>
      _dateStr(DateTime.now().add(Duration(days: _quickOffset)));

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _num(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;

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
      _quickIncomeCat ??= c.state.incomeCats.isNotEmpty
          ? c.state.incomeCats.first.id
          : '1';
      c.saveDayEntry(
        date: date,
        income: amt,
        expenses: {},
        debtPays: {},
        savings: {},
        note: _quickNote.text.trim().isEmpty
            ? 'быстрая запись'
            : _quickNote.text.trim(),
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
      note: _quickNote.text.trim().isEmpty
          ? 'быстрая запись'
          : _quickNote.text.trim(),
    );
    _quickExpense.clear();
    _quickNote.clear();
    _toast('Расход записан');
  }

  void _toast(String msg) {
    if (!mounted) return;
    appToast(context, msg, c.state);
  }

  Future<void> _openFullChart(List<Bar> bars) async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChartFullscreenScreen(
          controller: c,
          bars: bars,
          candle: _candle,
          ma: _ma,
          showVolume: _volume,
          zoom: _zoom,
          rightOffset: _chartKey.currentState?.rightOffset ?? 0,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _zoom = result['zoom'] ?? _zoom);
    _chartKey.currentState?.setView(
      zoom: result['zoom'] ?? _zoom,
      rightOffset: result['rightOffset'] ?? 0,
    );
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
    final openDebts = c.state.debts
        .where(
          (x) => !x.archived && (calc.debtRemain[x.id] ?? x.amount) > 0.004,
        )
        .toList();

    return AppScrollView(
      storageKey: 'dashboard-scroll',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BitBalance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Финансовый пульт',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Скрыть суммы',
                onPressed: () => c.updateSetting((s) => s.hideBal = !s.hideBal),
                icon: Icon(
                  c.state.hideBal ? Icons.visibility_off : Icons.visibility,
                ),
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
                  Text(
                    'Текущий баланс',
                    style: TextStyle(fontSize: 13, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _shown(calc.balance),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: calc.balance >= 0
                            ? AppTheme.text
                            : AppTheme.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (change >= 0 ? AppTheme.success : AppTheme.danger)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${change >= 0 ? '+' : ''}${_shown(change)} · ${changePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: change >= 0
                                ? AppTheme.success
                                : AppTheme.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'за период',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _metric(
                          'Копилка',
                          _shown(calc.cash + calc.savingsTotal),
                          'своб. ${_shown(calc.cash)}',
                          AppTheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _metric(
                          'Долги',
                          _shown(calc.debtTotal),
                          'осталось вернуть',
                          AppTheme.danger,
                        ),
                      ),
                      Expanded(
                        child: _metric(
                          'Подушка',
                          _shown(calc.cushion),
                          'безопасность',
                          AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Подушка безопасности',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${calc.cushionPct.toStringAsFixed(0)}% · ${c.state.cushionMonths} мес.',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressLine(
                    value: calc.cushionPct / 100,
                    color: AppTheme.success,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Цель ${_shown(calc.cushionGoal)} · осталось ${_shown(calc.cushionRemaining)}',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // График в стиле биржевого терминала из скриншота.
          SectionCard(
            title: 'Динамика баланса',
            subtitle: 'Свечи, объём и скользящие средние MA7 / MA14 / MA28',
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: ChartColors.bg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                          child: Row(
                            children: [
                              Text(
                                'Баланс',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ChartColors.label,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                bars.isEmpty
                                    ? _shown(calc.balance)
                                    : _shown(bars.last.close),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${change >= 0 ? '+' : '−'}${changePct.abs().toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: change >= 0
                                      ? ChartColors.up
                                      : ChartColors.down,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final t in ['День', 'Нед', 'Мес', 'Год'])
                                _terminalPill(
                                  t,
                                  _tf == _tfKey(t),
                                  () => _setTf(_tfKey(t)),
                                ),
                              _terminalPill(
                                'Свечи',
                                _candle,
                                () => _setMode(true),
                              ),
                              _terminalPill(
                                'Линия',
                                !_candle,
                                () => _setMode(false),
                              ),
                            ],
                          ),
                        ),
                        if (bars.isEmpty)
                          SizedBox(
                            height: 220,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  'Проведите первый день — здесь появится график баланса',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ChartColors.label,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          BalanceChart(
                            key: _chartKey,
                            bars: bars,
                            candle: _candle,
                            ma: _ma,
                            showVolume: _volume,
                            showFlow: true,
                            hideBal: c.state.hideBal,
                            height: 300,
                            onZoomChanged: (value) =>
                                setState(() => _zoom = value),
                          ),
                        Container(
                          color: ChartColors.panel,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              _terminalPill(
                                'MA',
                                _ma,
                                () => setState(() => _ma = !_ma),
                              ),
                              _terminalPill(
                                'Объём',
                                _volume,
                                () => setState(() => _volume = !_volume),
                              ),
                              const Spacer(),
                              _terminalPill(
                                '−',
                                false,
                                () => _chartKey.currentState?.zoomOut(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Text(
                                  '×${_zoom.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: ChartColors.axis,
                                  ),
                                ),
                              ),
                              _terminalPill(
                                '+',
                                false,
                                () => _chartKey.currentState?.zoomIn(),
                              ),
                              _terminalPill(
                                '↺',
                                false,
                                () => _chartKey.currentState?.resetZoom(),
                              ),
                              _terminalPill(
                                '⛶',
                                false,
                                () => _openFullChart(bars),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Масштаб кнопками − / +, жестом щипка или Ctrl/⌘ + колесо. Тяните влево/вправо по истории, двойной тап — сброс.',
                  style: TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
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
                    _pill(
                      'Сегодня',
                      _quickOffset == 0,
                      () => setState(() => _quickOffset = 0),
                    ),
                    const SizedBox(width: 6),
                    _pill(
                      'Вчера',
                      _quickOffset == -1,
                      () => setState(() => _quickOffset = -1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quickIncome,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Доход, ₽',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            _quickIncomeCat ??
                            (c.state.incomeCats.isNotEmpty
                                ? c.state.incomeCats.first.id
                                : null),
                        decoration: const InputDecoration(
                          labelText: 'Источник',
                        ),
                        items: c.state.incomeCats
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name),
                              ),
                            )
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
                        decoration: const InputDecoration(
                          labelText: 'Расход, ₽',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _quickExpCat,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Куда'),
                        items: [
                          const DropdownMenuItem(
                            value: 'cush',
                            child: Text('Подушка'),
                          ),
                          ...activeCats.map(
                            (e) => DropdownMenuItem(
                              value: 'c:${e.id}',
                              child: Text(e.name),
                            ),
                          ),
                          ...openDebts.map(
                            (e) => DropdownMenuItem(
                              value: 'd:${e.id}',
                              child: Text('Долг: ${e.name}'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _quickExpCat = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _quickNote,
                  decoration: const InputDecoration(
                    labelText: 'Примечание',
                    hintText: 'необязательно',
                  ),
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
        ],
      ),
    );
  }

  String _tfKey(String label) =>
      const {
        'День': 'day',
        'Нед': 'week',
        'Мес': 'month',
        'Год': 'year',
      }[label] ??
      'day';

  Widget _metric(String label, String value, String sub, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _terminalPill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? ChartColors.ma7.withValues(alpha: 0.18)
              : ChartColors.panel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? ChartColors.ma7 : ChartColors.grid,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? ChartColors.ma7 : ChartColors.label,
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}
