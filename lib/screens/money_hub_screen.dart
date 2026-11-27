import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'analytics_screen.dart';
import 'money_screen.dart';

/// «Деньги» и «Аналитика» живут в одной вкладке, как «История» и «Отчёт».
/// Это освобождает точку в нижней навигации для центральной кнопки «+».
class MoneyHubScreen extends StatefulWidget {
  final AppController controller;
  const MoneyHubScreen({super.key, required this.controller});

  @override
  State<MoneyHubScreen> createState() => _MoneyHubScreenState();
}

class _MoneyHubScreenState extends State<MoneyHubScreen> {
  AppController get c => widget.controller;

  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ScreenHeader(
                        eyebrow: 'Деньги',
                        title: _section == 0
                            ? 'Категории и обязательства'
                            : 'Цифры и тренды',
                        subtitle: _section == 0
                            ? 'Расходы, долги, накопления и подушка'
                            : 'Здоровье денег, графики и прогнозы',
                        trailing: IconButton(
                          onPressed: () => c.commit(),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Деньги'),
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                      ),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Аналитика'),
                      icon: Icon(Icons.insert_chart_outlined, size: 16),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (v) => setState(() => _section = v.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
          ),
          Expanded(
            child: _section == 0
                ? MoneyScreen(controller: c, showHeader: false)
                : AnalyticsScreen(controller: c, showHeader: false),
          ),
        ],
      ),
    );
  }
}
