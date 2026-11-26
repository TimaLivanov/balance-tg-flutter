import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class MoneyScreen extends StatefulWidget {
  final AppController controller;
  const MoneyScreen({super.key, required this.controller});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  AppController get c => widget.controller;

  bool _archiveExpanded = false;

  String _shown(double v) => c.state.hideBal ? '••••' : fmtMoney(v);

  @override
  Widget build(BuildContext context) {
    final calc = c.calc;
    final minSum = debtMinSum(c.state, calc);
    final cats = c.state.cats.where((x) => !x.archived).toList();
    final debts = orderedDebts(
      c.state,
      calc,
      c.state.debts.where((x) => !x.archived).toList(),
    );
    final savings = c.state.savings.where((x) => !x.archived).toList();
    final archivedCats = c.state.cats.where((x) => x.archived).toList();
    final archivedDebts = c.state.debts.where((x) => x.archived).toList();
    final archivedSavings = c.state.savings.where((x) => x.archived).toList();

    return AppScrollView(
      storageKey: 'money-scroll',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            eyebrow: 'Деньги',
            title: 'Категории и обязательства',
            subtitle: 'Расходы, долги, накопления и подушка',
            trailing: IconButton(
              onPressed: () => c.commit(),
              icon: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: 20),

          SectionCard(
            title: 'Подушка',
            subtitle: '${c.state.cushionMonths} месяцев запаса',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Сейчас', style: TextStyle(fontSize: 13)),
                    Text(
                      '${fmtMoney(calc.cushion)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Цель', style: TextStyle(fontSize: 13)),
                    Text(
                      '${fmtMoney(calc.cushionGoal)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressLine(
                  value: calc.cushionPct / 100,
                  color: AppTheme.success,
                ),
                const SizedBox(height: 8),
                Text(
                  calc.cushionRemaining > 0
                      ? 'До цели ${fmtMoney(calc.cushionRemaining)} ₽ · рек. ${fmtMoney(calc.cushionRecPerDay)} ₽/день'
                      : 'Цель набрана',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Категории расходов',
            subtitle: '${cats.length} активных',
            action: TextButton.icon(
              onPressed: () => _addCategoryDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Новая'),
            ),
            child: cats.isEmpty
                ? const _Empty('Пока нет категорий')
                : Column(
                    children: cats.map((cat) {
                      final st = catStats(c.state, cat);
                      final plan = cat.plan;
                      final hasDue = plan != null && plan.date.isNotEmpty;
                      final closed = hasDue && plan.amount > 0
                          ? (st.totalSpent / plan.amount * 100).round().clamp(
                              0,
                              100,
                            )
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primary.withValues(
                                    alpha: .12,
                                  ),
                                  child: cat.icon.isNotEmpty
                                      ? Text(
                                          cat.icon,
                                          style: const TextStyle(fontSize: 18),
                                        )
                                      : Icon(
                                          cat.need
                                              ? Icons.priority_high
                                              : Icons.category_outlined,
                                          color: cat.need
                                              ? AppTheme.primary
                                              : AppTheme.muted,
                                          size: 18,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (cat.need)
                                            _Tag('обяз.', AppTheme.primary),
                                          if (cat.rare)
                                            const _Tag(
                                              'редк.',
                                              AppTheme.warning,
                                            ),
                                          if (st.overdue)
                                            const _Tag(
                                              'срок прошёл',
                                              AppTheme.danger,
                                            ),
                                        ],
                                      ),
                                      Text(
                                        plan != null
                                            ? 'план ${fmtMoney(plan.amount)} ₽'
                                                  '${hasDue ? ' · до ${fmtDateRu(plan.date)}' : ''}'
                                                  '${st.remaining != null ? ' · осталось ${_shown(st.remaining!)} ₽' : ''}'
                                            : 'без плана',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                      Text(
                                        'отдано ${_shown(st.totalSpent)} ₽'
                                        '${st.spentWin > 0.004 ? ' · за окно ${_shown(st.spentWin)} ₽' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                      if (st.avgDay > 0.004)
                                        Text(
                                          'рек. ${c.state.hideBal ? '••••' : fmtRec(st.avgDay)} ₽ / день',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      if (st.minDay != null &&
                                          st.minDay! > 0.004)
                                        Text(
                                          'мин. ${c.state.hideBal ? '••••' : fmtRec(st.minDay!)} ₽ / день'
                                          '${st.daysLeft != null ? ' · ${st.daysLeft} дн.' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF06B6D4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => _catAction(v, cat.id),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'ops',
                                      child: Text('Операции'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Редактировать'),
                                    ),
                                    PopupMenuItem(
                                      value: 'reset',
                                      child: Text('Сбросить прогресс'),
                                    ),
                                    PopupMenuItem(
                                      value: 'del',
                                      child: Text('Удалить'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (hasDue) ...[
                              const SizedBox(height: 6),
                              ProgressLine(value: closed / 100),
                              const SizedBox(height: 2),
                              Text(
                                'плана $closed%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Долги',
            subtitle:
                '${debts.length} шт. · осталось вернуть ${_shown(calc.debtTotal)} ₽ · '
                'мин. ${c.state.hideBal ? '••••' : fmtRec(minSum)} ₽ / день',
            action: TextButton.icon(
              onPressed: () => _addDebtDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Новый'),
            ),
            child: debts.isEmpty
                ? const _Empty('Долгов нет')
                : Column(
                    children: debts.map((d) {
                      final rec = debtRec(c.state, calc, d);
                      final closed = d.amount > 0
                          ? ((d.amount - rec.remain) / d.amount * 100).round()
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.danger.withValues(
                                    alpha: .1,
                                  ),
                                  child: const Icon(
                                    Icons.credit_card,
                                    color: AppTheme.danger,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              d.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (rec.overdue)
                                            const _Tag(
                                              'срок прошёл',
                                              AppTheme.danger,
                                            ),
                                        ],
                                      ),
                                      Text(
                                        'остаток ${_shown(rec.remain)} ₽ из ${_shown(d.amount)} ₽'
                                        '${d.due.isNotEmpty ? ' · до ${fmtDateRu(d.due)}' : ' · без срока'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                      if (rec.perDay != null && rec.perDay! > 0)
                                        Text(
                                          'рек. ${c.state.hideBal ? '••••' : fmtRec(rec.perDay!)} ₽ / день'
                                          '${rec.daysLeft != null ? ' · ${rec.daysLeft} дн.' : ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => _debtAction(v, d.id),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'ops',
                                      child: Text('Операции'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Редактировать'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text('В архив'),
                                    ),
                                    PopupMenuItem(
                                      value: 'del',
                                      child: Text('Удалить'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ProgressLine(value: closed / 100),
                            const SizedBox(height: 2),
                            Text(
                              'закрыто $closed%',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Накопления и инвестиции',
            subtitle: '${savings.length} целей',
            action: TextButton.icon(
              onPressed: () => _addSavingsDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Новая'),
            ),
            child: savings.isEmpty
                ? const _Empty('Целей пока нет')
                : Column(
                    children: savings.map((g) {
                      final target = g.plan?.amount ?? 0;
                      final progress = target > 0
                          ? (g.closedFunded / target).clamp(0, 1)
                          : 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.success.withValues(
                                alpha: .1,
                              ),
                              child: Icon(
                                g.kind == 'invest'
                                    ? Icons.trending_up
                                    : Icons.savings,
                                color: AppTheme.success,
                                size: 18,
                              ),
                            ),
                            title: Text(g.name),
                            subtitle: Text(
                              'Цель ${fmtMoney(target)} ₽${g.plan?.date != null && g.plan!.date.isNotEmpty ? ' · до ${g.plan!.date}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Удалить цель?',
                                  message: 'Цель «${g.name}» будет удалена.',
                                );
                                if (ok == true) c.deleteSavings(g.id);
                              },
                            ),
                          ),
                          if (target > 0)
                            ProgressLine(
                              value: progress.toDouble(),
                              color: AppTheme.success,
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Доходные категории',
            action: TextButton.icon(
              onPressed: () => _addIncomeCatDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            ),
            child: Wrap(
              spacing: 8,
              children: c.state.incomeCats
                  .map(
                    (e) => Chip(
                      label: Text(e.name),
                      onDeleted: e.id == '1'
                          ? null
                          : () {
                              c.updateSetting(
                                (s) => s.incomeCats.removeWhere(
                                  (x) => x.id == e.id,
                                ),
                              );
                            },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Автоплатежи',
            subtitle: '${c.state.autopay.length} правил',
            action: TextButton.icon(
              onPressed: () => _addAutoPayDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Новый'),
            ),
            child: c.state.autopay.isEmpty
                ? const _Empty('Автоплатежей нет')
                : Column(
                    children: c.state.autopay
                        .map(
                          (a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(a.name),
                            subtitle: Text(
                              '${fmtMoney(a.amount)} ₽ · ${a.mode == 'monthly' ? 'каждое ${a.day}-е число' : 'каждый день'} · ${a.time}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => c.deleteAutoPay(a.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (archivedCats.isNotEmpty ||
              archivedDebts.isNotEmpty ||
              archivedSavings.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Архив',
              subtitle: _archiveExpanded
                  ? 'Закрытые цели и погашенные долги'
                  : '${archivedDebts.length + archivedCats.length + archivedSavings.length} записей · нажмите развернуть',
              action: IconButton(
                icon: Icon(
                  _archiveExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                tooltip: _archiveExpanded
                    ? 'Свернуть архив'
                    : 'Развернуть архив',
                onPressed: () =>
                    setState(() => _archiveExpanded = !_archiveExpanded),
              ),
              child: _archiveExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...archivedDebts.map(
                          (d) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Долг: ${d.name}'),
                            subtitle: Text(
                              'остаток был ${fmtMoney(calc.debtRemain[d.id] ?? 0)} ₽ · '
                              '${(calc.debtRemain[d.id] ?? 0) <= 0.004 ? 'долг погашен' : 'долг в архиве'}'
                              '${d.archivedAt.isNotEmpty ? ' · ${fmtDateRu(d.archivedAt)}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: TextButton(
                              onPressed: () =>
                                  c.updateDebt(d.id, archived: false),
                              child: const Text('Вернуть'),
                            ),
                          ),
                        ),
                        ...archivedCats.map(
                          (x) => Text(
                            'Категория: ${x.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                        ...archivedSavings.map(
                          (x) => Text(
                            'Цель: ${x.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(
                          'Нажмите ↕, чтобы посмотреть архив',
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _catOps(Category cat) {
    final ops =
        c.state.history.where((h) => (h.expenses[cat.id] ?? 0) > 0).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Операции · ${cat.icon.isNotEmpty ? '${cat.icon} ' : ''}${cat.name}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ops.isEmpty
              ? const Text('Операций пока нет', style: TextStyle(fontSize: 13))
              : ListView(
                  shrinkWrap: true,
                  children: ops.take(c.state.recentOpsLimit).map((h) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '−${fmtMoney(h.expenses[cat.id] ?? 0)} ₽',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        h.date,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _catAction(String action, String id) {
    final cat = c.state.cats.firstWhere((x) => x.id == id);
    if (action == 'ops') {
      _catOps(cat);
    } else if (action == 'reset') {
      confirmDialog(
        context,
        title: 'Сбросить «отдано»?',
        message:
            'Прогресс по «${cat.name}» начнётся заново. '
            'Баланс и история не изменятся.',
        confirm: 'Сбросить',
      ).then((ok) {
        if (ok == true) c.resetCategory(id);
      });
    } else if (action == 'del') {
      confirmDialog(
        context,
        title: 'Удалить категорию?',
        message: 'Категория «${cat.name}» будет удалена.',
      ).then((ok) {
        if (ok == true) c.deleteCategory(id);
      });
    } else {
      _editCategoryDialog(cat);
    }
  }

  void _debtAction(String action, String id) {
    final d = c.state.debts.firstWhere((x) => x.id == id);
    if (action == 'del') {
      confirmDialog(
        context,
        title: 'Удалить долг?',
        message: 'Долг «${d.name}» и его записи будут удалены.',
      ).then((ok) {
        if (ok == true) c.deleteDebt(id);
      });
    } else if (action == 'archive') {
      c.updateDebt(id, archived: true);
    } else if (action == 'ops') {
      _debtOps(d);
    } else {
      _editDebtDialog(d);
    }
  }

  void _debtOps(Debt d) {
    final ops =
        c.state.history
            .where(
              (h) =>
                  h.debtId == d.id ||
                  (h.type == 'day' && (h.debtPays[d.id] ?? 0) > 0),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Операции · ${d.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ops.isEmpty
              ? const Text('Операций пока нет', style: TextStyle(fontSize: 13))
              : ListView(
                  shrinkWrap: true,
                  children: ops.take(c.state.recentOpsLimit).map((h) {
                    final pay = h.debtPays[d.id] ?? 0;
                    final label = h.type == 'debt'
                        ? 'новый долг · ${fmtMoney(h.debtAmt)} ₽'
                        : 'погашение −${fmtMoney(pay)} ₽';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        h.date,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  static const _icons = [
    '',
    '🏠',
    '🍽',
    '🚕',
    '🛒',
    '💊',
    '🎓',
    '🎬',
    '✈️',
    '👕',
    '🐾',
    '🎁',
    '☕',
    '🏋️',
    '📱',
    '💡',
    '🔧',
    '🏦',
  ];

  Future<void> _pickIcon(String current, ValueChanged<String> onPick) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Иконка категории'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _icons
                .map(
                  (icon) => InkWell(
                    onTap: () => Navigator.pop(ctx, icon),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        icon.isEmpty ? '—' : icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _addCategoryDialog() async {
    final name = TextEditingController();
    final plan = TextEditingController();
    String icon = '';
    bool need = false;
    bool rare = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Новая категория'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    icon.isEmpty ? '—' : icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: const Text('Иконка', style: TextStyle(fontSize: 13)),
                  trailing: TextButton(
                    onPressed: () =>
                        _pickIcon(icon, (v) => setS(() => icon = v)),
                    child: const Text('Выбрать'),
                  ),
                ),
                TextField(
                  controller: plan,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Плановая сумма, ₽',
                  ),
                ),
                CheckboxListTile(
                  value: need,
                  title: const Text('обязательная (в подушку)'),
                  onChanged: (v) => setS(() => need = v ?? false),
                ),
                CheckboxListTile(
                  value: rare,
                  title: const Text('редкая'),
                  onChanged: (v) => setS(() => rare = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c.addCategory(
        name.text,
        icon: icon,
        need: need,
        rare: rare,
        plan: _d(plan.text),
      );
    }
  }

  Future<void> _editCategoryDialog(Category cat) async {
    final name = TextEditingController(text: cat.name);
    final plan = TextEditingController(text: cat.plan?.amount.toString() ?? '');
    String icon = cat.icon;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Редактировать категорию'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    icon.isEmpty ? '—' : icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: const Text('Иконка', style: TextStyle(fontSize: 13)),
                  trailing: TextButton(
                    onPressed: () =>
                        _pickIcon(icon, (v) => setS(() => icon = v)),
                    child: const Text('Выбрать'),
                  ),
                ),
                TextField(
                  controller: plan,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'План, ₽'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      c.updateCategory(
        cat.id,
        name: name.text,
        icon: icon,
        plan: _d(plan.text),
      );
    }
  }

  Future<void> _addDebtDialog() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final due = TextEditingController();
    final date = TextEditingController(
      text: DateTime.now().toString().substring(0, 10),
    );
    bool credit = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Новый долг'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Сумма, ₽'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(
                    labelText: 'Дата возникновения, ГГГГ-ММ-ДД',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: due,
                  decoration: const InputDecoration(
                    labelText: 'Срок (необязательно), ГГГГ-ММ-ДД',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: credit,
                  onChanged: (v) => setStateDialog(() => credit = v ?? true),
                  title: const Text(
                    'Деньги уже получил → в копилку',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Без галочки баланс снизится на сумму долга',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c.addDebt(
        name.text,
        _d(amount.text),
        due: due.text.trim(),
        date: date.text.trim(),
        creditCash: credit,
      );
    }
  }

  Future<void> _editDebtDialog(Debt debt) async {
    final name = TextEditingController(text: debt.name);
    final amount = TextEditingController(text: debt.amount.toString());
    final due = TextEditingController(text: debt.due);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать долг'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Сумма, ₽'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: due,
              decoration: const InputDecoration(labelText: 'Срок'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      c.updateDebt(
        debt.id,
        name: name.text,
        amount: _d(amount.text),
        due: due.text,
      );
    }
  }

  Future<void> _addSavingsDialog() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    String kind = 'goal';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Новая цель / инвестиция'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Тип'),
                items: const [
                  DropdownMenuItem(value: 'goal', child: Text('Цель')),
                  DropdownMenuItem(value: 'invest', child: Text('Инвестиция')),
                ],
                onChanged: (v) => setS(() => kind = v ?? 'goal'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Целевая сумма, ₽',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c.addSavings(name.text, _d(amount.text), kind: kind);
    }
  }

  Future<void> _addIncomeCatDialog() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Категория дохода'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c.updateSetting(
        (s) => s.incomeCats.add(
          IncomeCategory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name.text.trim(),
          ),
        ),
      );
    }
  }

  Future<void> _addAutoPayDialog() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    String mode = 'daily';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Новый автоплатёж'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сумма, ₽'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Периодичность'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Каждый день')),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('Каждый месяц'),
                  ),
                ],
                onChanged: (v) => setS(() => mode = v ?? 'daily'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c.addAutoPay(name.text, _d(amount.text), mode: mode);
    }
  }

  double _d(String v) => double.tryParse(v.replaceAll(',', '.')) ?? 0;
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text, style: TextStyle(color: AppTheme.muted, fontSize: 13)),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color)),
  );
}
