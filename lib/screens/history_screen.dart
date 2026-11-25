import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/download_service.dart';
import '../services/import_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatefulWidget {
  final AppController controller;
  const HistoryScreen({super.key, required this.controller});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  AppController get c => widget.controller;

  String _dateRu(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      '',
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String _describe(Entry e) {
    final parts = <String>[];
    if (e.income > 0) parts.add('Доход ${fmtMoney(e.income)} ₽');
    if (e.expenses.isNotEmpty) {
      final total = e.expenses.values.fold(0.0, (a, b) => a + b);
      parts.add('Траты ${fmtMoney(total)} ₽');
    }
    e.debtPays.forEach((id, v) {
      if (v <= 0) return;
      final name =
          c.state.debts
              .where((d) => d.id == id)
              .map((d) => d.name)
              .firstOrNull ??
          id;
      parts.add('→ долг «$name» −${fmtMoney(v)} ₽');
    });
    if (e.savings.isNotEmpty) {
      final total = e.savings.values.fold(0.0, (a, b) => a + b);
      parts.add('Накопления ${fmtMoney(total)} ₽');
    }
    if (e.cushIn > 0) parts.add('В подушку ${fmtMoney(e.cushIn)} ₽');
    if (e.cushOut > 0) parts.add('Из подушки ${fmtMoney(e.cushOut)} ₽');
    if (e.type == 'debt') {
      final name =
          c.state.debts
              .where((d) => d.id == e.debtId)
              .map((d) => d.name)
              .firstOrNull ??
          '';
      parts.add(
        'долг «$name» +${fmtMoney(e.debtAmt)} ₽ '
        '${e.creditCash ? 'в копилку' : 'без зачисления в копилку'}',
      );
    }
    if (parts.isEmpty) parts.add('Пустая запись');
    return parts.join(' · ');
  }

  void _editNote(Entry e) {
    final ctrl = TextEditingController(text: e.note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Примечание'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Примечание'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final idx = c.state.history.indexWhere((x) => x.id == e.id);
              if (idx >= 0) {
                final old = c.state.history[idx];
                c.state.history[idx] = Entry(
                  id: old.id,
                  type: old.type,
                  date: old.date,
                  income: old.income,
                  incomeCat: old.incomeCat,
                  expenses: old.expenses,
                  debtPays: old.debtPays,
                  savings: old.savings,
                  savSpend: old.savSpend,
                  cushOut: old.cushOut,
                  cushIn: old.cushIn,
                  note: ctrl.text,
                  debtId: old.debtId,
                  debtAmt: old.debtAmt,
                  creditCash: old.creditCash,
                  autoItems: old.autoItems,
                  autoMk: old.autoMk,
                );
                c.commit();
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Примечание обновлено')),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _delete(Entry e) {
    confirmDialog(
      context,
      title: 'Удалить операцию?',
      message: _describe(e),
      confirm: 'Удалить',
    ).then((ok) {
      if (ok == true) {
        c.deleteEntry(e.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Удалено: ${_describe(e)}')));
      }
    });
  }

  void _undoLast() {
    if (c.state.history.isEmpty) return;
    final sorted = List<Entry>.from(c.state.history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final last = sorted.first;
    c.deleteEntry(last.id);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Отменено: ${_describe(last)}')));
  }

  void _export() {
    final s = c.state;
    final payload = jsonEncode({
      'app': 'BitBalance',
      'kind': 'history',
      'version': 3,
      'history': s.history.map((e) => e.toJson()).toList(),
      'cats': s.cats.map((e) => e.toJson()).toList(),
      'debts': s.debts.map((e) => e.toJson()).toList(),
      'savings': s.savings.map((e) => e.toJson()).toList(),
      'incomeCats': s.incomeCats.map((e) => e.toJson()).toList(),
    });
    final date = DateTime.now().toString().substring(0, 10);
    downloadJsonFile('Balance_история_$date.json', payload);
    _toast('История экспортирована: операции, категории, долги и накопления');
  }

  Future<void> _import() async {
    final raw = await pickJsonFile();
    if (raw == null || raw.isEmpty || !mounted) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return _toast('Не удалось прочитать файл');
    }
    List<dynamic> list = const [];
    Map<dynamic, dynamic> data = {};
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      data = decoded;
      if (decoded['history'] is List)
        list = decoded['history'] as List<dynamic>;
    }
    if (list.isEmpty) return _toast('В файле нет операций');
    final ok = await confirmDialog(
      context,
      title: 'Импортировать историю?',
      message:
          'Операций в файле: ${list.length}. Совпадающие id не дублируются, '
          'недостающие категории и долги будут созданы.',
      confirm: 'Импортировать',
    );
    if (ok != true || !mounted) return;

    final s = c.state;
    void merge<T>(
      List<T> target,
      List<dynamic>? items,
      T Function(Map<dynamic, dynamic>) make,
      String Function(T) idOf,
    ) {
      final have = target.map(idOf).toSet();
      for (final item in items ?? const []) {
        if (item is! Map) continue;
        final obj = make(item);
        final id = idOf(obj);
        if (id.isEmpty || have.contains(id)) continue;
        target.add(obj);
        have.add(id);
      }
    }

    merge(
      s.cats,
      data['cats'] as List<dynamic>?,
      Category.fromJson,
      (x) => x.id,
    );
    merge(s.debts, data['debts'] as List<dynamic>?, Debt.fromJson, (x) => x.id);
    merge(
      s.savings,
      data['savings'] as List<dynamic>?,
      SavingsGoal.fromJson,
      (x) => x.id,
    );
    merge(
      s.incomeCats,
      data['incomeCats'] as List<dynamic>?,
      IncomeCategory.fromJson,
      (x) => x.id,
    );

    final have = s.history.map((e) => e.id).toSet();
    var added = 0;
    for (final item in list) {
      if (item is! Map) continue;
      final e = Entry.fromJson(item);
      if (e.id.isEmpty || have.contains(e.id)) continue;
      s.history.add(e);
      have.add(e.id);
      added++;
      // Справочники из самих операций (старые файлы без cats/debts).
      for (final id in e.expenses.keys) {
        if (!s.cats.any((x) => x.id == id)) {
          s.cats.add(Category(id: id, name: 'Категория $id'));
        }
      }
      if (e.type == 'debt' &&
          e.debtId != null &&
          !s.debts.any((x) => x.id == e.debtId)) {
        s.debts.add(
          Debt(id: e.debtId!, name: 'Долг', amount: e.debtAmt, date: e.date),
        );
      }
    }
    c.commit();
    _toast('Импортировано операций: $added');
  }

  @override
  Widget build(BuildContext context) {
    final entries = List<Entry>.from(c.state.history)
      ..sort((a, b) {
        final c1 = b.date.compareTo(a.date);
        return c1 != 0 ? c1 : b.id.compareTo(a.id);
      });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: ScreenHeader(
                    eyebrow: 'История',
                    title: 'Все операции',
                    subtitle: 'Записи по дням, экспорт и отмена действий',
                  ),
                ),
                IconButton(
                  tooltip: 'Отменить последнюю',
                  onPressed: _undoLast,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Экспорт',
                  onPressed: _export,
                  icon: const Icon(Icons.file_download_outlined),
                ),
                IconButton(
                  tooltip: 'Импорт',
                  onPressed: _import,
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет операций',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _dateRu(e.date),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.note_alt_outlined,
                                      size: 18,
                                    ),
                                    tooltip: 'Изменить примечание',
                                    onPressed: () => _editNote(e),
                                  ),
                                  if (e.type == 'day')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      tooltip: 'Редактировать',
                                      onPressed: () =>
                                          _toast('Правка доступна на главной'),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    tooltip: 'Удалить',
                                    onPressed: () => _delete(e),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _describe(e),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.text,
                                ),
                              ),
                              if (e.note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  e.note,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }
}
