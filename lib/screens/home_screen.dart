import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/full_entry_form.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'money_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Отчёт переехал внутрь «Истории», поэтому навигация стала компактнее.
  /// Создаём новые экземпляры при каждой пересборке: иначе Flutter видит
  /// те же объекты в IndexedStack и не обновляет экраны после записи операции.
  List<Widget> _screens(AppController controller) => [
    DashboardScreen(controller: controller),
    MoneyScreen(controller: controller),
    AnalyticsScreen(controller: controller),
    HistoryScreen(controller: controller),
    SettingsScreen(controller: controller),
  ];

  void _openFullEntry() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.92,
          child: FullEntryForm(
            controller: widget.controller,
            onDone: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final active = _selectedIndex == index;
    return Expanded(
      child: InkResponse(
        onTap: () => setState(() => _selectedIndex = index),
        radius: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 21,
              color: active ? AppTheme.primary : AppTheme.muted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                color: active ? AppTheme.primary : AppTheme.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plusButton() {
    return Expanded(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -18),
          child: GestureDetector(
            onTap: _openFullEntry,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens(widget.controller),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _navItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Главная',
                      index: 0,
                    ),
                    _navItem(
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet,
                      label: 'Деньги',
                      index: 1,
                    ),
                    _navItem(
                      icon: Icons.insert_chart_outlined,
                      activeIcon: Icons.insert_chart,
                      label: 'Аналитика',
                      index: 2,
                    ),
                    _plusButton(),
                    _navItem(
                      icon: Icons.history,
                      activeIcon: Icons.history,
                      label: 'История',
                      index: 3,
                    ),
                    _navItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings,
                      label: 'Настройки',
                      index: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
