import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/download_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class ReportScreen extends StatefulWidget {
  final AppController controller;
  const ReportScreen({super.key, required this.controller});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _period = '30';
  AppController get c => widget.controller;

  String _buildReport() {
    final now = DateTime.now();
    final from = _period == 'all'
        ? DateTime(2000)
        : now.subtract(Duration(days: int.parse(_period) - 1));
    double inc = 0;
    double exp = 0;
    double paid = 0;
    for (final h in c.state.history) {
      if (h.type != 'day') continue;
      final d = DateTime.tryParse(h.date);
      if (d == null || d.isBefore(from)) continue;
      inc += h.income;
      exp += h.expenses.values.fold(0, (a, b) => a + b);
      paid += h.debtPays.values.fold(0, (a, b) => a + b);
    }
    final calc = c.calc;
    final net = inc - exp - paid;
    final debtOpen = calc.debtTotal > 0.004;
    final monthsToFree = debtOpen && net > 0 ? calc.debtTotal / net / 30 : null;
    final debtRows = c.state.debts
        .map((d) {
          final rem = calc.debtRemain[d.id] ?? d.amount;
          final closed = d.amount > 0
              ? ((d.amount - rem) / d.amount * 100).round()
              : 0;
          return '${d.name} | ${fmtMoney(d.amount)} ₽ | ${fmtMoney(rem)} ₽ | '
              '$closed% | ${d.due.isNotEmpty ? fmtDateRu(d.due) : 'без срока'}';
        })
        .join('\n');
    return 'ФИНАНСОВЫЙ ОТЧЁТ\n'
        'Период: ${_periodLabel()}\n'
        'СВОДКА\n'
        'Баланс: ${fmtMoney(calc.balance)} ₽\n'
        'Копилка: ${fmtMoney(calc.cash)} ₽\n'
        'Накопления: ${fmtMoney(calc.savingsTotal)} ₽\n'
        'Подушка: ${fmtMoney(calc.cushion)} ₽\n'
        'Долги: ${fmtMoney(calc.debtTotal)} ₽\n\n'
        'ДОХОДЫ И РАСХОДЫ ЗА ПЕРИОД\n'
        'Доход: ${fmtMoney(inc)} ₽\n'
        'Траты: ${fmtMoney(exp)} ₽\n'
        'На долги: ${fmtMoney(paid)} ₽\n'
        'Итог: ${fmtMoney(inc - exp - paid)} ₽\n\n'
        'ЗДОРОВЬЕ ДЕНЕГ\n'
        'Обязательные не выше: ${c.state.health.needsMax}%\n'
        'Остаток не ниже: ${c.state.health.saveMin}%\n'
        'Запас не меньше: ${c.state.health.runwayMin} дней\n'
        'Долги закрыть за: ${c.state.health.debtMonths} мес.\n'
        'Срок закрытия долгов: ${!debtOpen
            ? 'нет долгов'
            : monthsToFree == null
            ? 'при потоке не закроются'
            : '${monthsToFree.ceil()} мес.'}\n\n'
        'ДОЛГИ · НАЗВАНИЕ | СУММА | ОСТАТОК | ЗАКРЫТО | СРОК\n'
        '${debtRows.isEmpty ? 'Долгов нет' : debtRows}\n\n'
        'Это фактические данные, а не финансовая рекомендация.';
  }

  String _periodLabel() =>
      const {
        '7': '7 дней',
        '30': '30 дней',
        '90': '90 дней',
        '365': 'Год',
        'all': 'Всё время',
      }[_period] ??
      _period;

  void _download() {
    final text = _buildReport();
    downloadHtmlFile(
      'Финансовый_отчёт_${DateTime.now().toString().substring(0, 10)}.html',
      '<!doctype html><html><head><meta charset="utf-8"><title>Финансовый отчёт</title>'
          '<style>body{font:15px/1.6 system-ui;max-width:760px;margin:40px auto;padding:0 20px;color:#111827}'
          'pre{white-space:pre-wrap}</style></head><body><pre>$text</pre></body></html>',
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Отчёт скачан')));
  }

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      storageKey: 'report-scroll',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            eyebrow: 'Отчёт',
            title: 'Выгрузка для консультанта',
            subtitle: 'Только факты: баланс, долги, доходы и траты',
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Отчёт для консультанта',
            subtitle: 'Факты за период: баланс, копилка, подушка, долги, доходы и траты.',
            action: DropdownButton<String>(
              value: _period,
              items: const [
                DropdownMenuItem(value: '7', child: Text('7 дней')),
                DropdownMenuItem(value: '30', child: Text('30 дней')),
                DropdownMenuItem(value: '90', child: Text('90 дней')),
                DropdownMenuItem(value: '365', child: Text('Год')),
                DropdownMenuItem(value: 'all', child: Text('Всё время')),
              ],
              onChanged: (v) => setState(() => _period = v ?? '30'),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                _buildReport(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.6,
                  color: AppTheme.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('Скачать отчёт (HTML)'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Копировать',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _buildReport()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Отчёт скопирован')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Период: ${_periodLabel()}',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
