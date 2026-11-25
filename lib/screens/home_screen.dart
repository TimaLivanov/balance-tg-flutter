import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'dashboard_screen.dart';
import 'money_screen.dart';
import 'analytics_screen.dart';
import 'history_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        DashboardScreen(controller: widget.controller),
        MoneyScreen(controller: widget.controller),
        AnalyticsScreen(controller: widget.controller),
        HistoryScreen(controller: widget.controller),
        ReportScreen(controller: widget.controller),
        SettingsScreen(controller: widget.controller),
      ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: _screens),
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
            child: ClipRRect(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Главная',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    activeIcon: Icon(Icons.account_balance_wallet),
                    label: 'Деньги',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.insert_chart_outlined),
                    activeIcon: Icon(Icons.insert_chart),
                    label: 'Аналитика',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: 'История',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.description_outlined),
                    activeIcon: Icon(Icons.description),
                    label: 'Отчёт',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Настройки',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
