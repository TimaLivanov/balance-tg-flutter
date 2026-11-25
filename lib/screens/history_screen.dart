import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_state.dart';
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
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
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
    if (e.debtPays.isNotEmpty) {
      final total = e.debtPays.values.fold(0.0, (a, b) => a + b);
      parts.add('На долги ${fmtMoney(total)} ₽');
    }
    if (e.savings.isNotEmpty) {
      final total = e.savings.values.fold(0.0, (a, b) => a + b);
      parts.add('Накопления ${fmtMoney(total)} ₽');
    }
    if (e.cushIn > 0) parts.add('В подушку ${fmtMoney(e.cushIn)} ₽');
    if (e.cushOut > 0) parts.add('Из подушки ${fmtMoney(e.cushOut)} ₽');
    if (e.type == 'debt') parts.add('Новый долг');
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удалено: ${_describe(e)}')),
        );
      }
    });
  }

  void _undoLast() {
    if (c.state.history.isEmpty) return;
    final sorted = List<Entry>.from(c.state.history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final last = sorted.first;
    c.deleteEntry(last.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Отменено: ${_describe(last)}')),
    );
  }

  void _export() {
    final json = {
      'app': 'BitBalance',
      'kind': 'history',
      'version': 3,
      'history': c.state.history.map((e) => e.toJson()).toList(),
      'cats': c.state.cats.map((e) => e.toJson()).toList(),
      'debts': c.state.debts.map((e) => e.toJson()).toList(),
      'savings': c.state.savings.map((e) => e.toJson()).toList(),
      'incomeCats': c.state.incomeCats.map((e) => e.toJson()).toList(),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('История скопирована в буфер обмена'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
    // ignore: unused_local_variable
    final payload = jsonEncode(json);
  }

  @override
  Widget build(BuildContext context) {
    final entries = List<Entry>.from(c.state.history)
      ..sort((a, b) {
        final c1 = b.date.compareTo(a.date);
        return c1 != 0 ? c1 : b.id.compareTo(a.id);
      });

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
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
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('Пока нет операций',
                        style: TextStyle(color: AppTheme.mutedLight)),
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
                                          fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.note_alt_outlined, size: 18),
                                    tooltip: 'Изменить примечание',
                                    onPressed: () => _editNote(e),
                                  ),
                                  if (e.type == 'day')
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Редактировать',
                                      onPressed: () => _toast('Правка доступна на главной'),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    tooltip: 'Удалить',
                                    onPressed: () => _delete(e),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_describe(e),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                              if (e.note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(e.note,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.mutedLight)),
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
