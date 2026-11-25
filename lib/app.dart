import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'state/app_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/ui.dart';

class BalanceApp extends StatefulWidget {
  const BalanceApp({super.key});

  @override
  State<BalanceApp> createState() => _BalanceAppState();
}

class _BalanceAppState extends State<BalanceApp> {
  final _controller = AppController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Применяем настройки внутри builder: иначе смена темы, акцента
        // или размера шрифта не доходит до MaterialApp после notifyListeners().
        AppTheme.applyAccent(_controller.state.accent);
        AppTheme.applyTheme(_controller.state.theme);
        final scale = switch (_controller.state.fontSize) {
          's' => 0.9,
          'l' => 1.15,
          _ => 1.0,
        };
        Widget home(BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: _controller.authenticated || _controller.guest
              ? HomeScreen(controller: _controller)
              : LoginScreen(controller: _controller),
        );

        final builder = (context, child) => ScrollConfiguration(
          behavior: AppScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
        if (_controller.loading) {
          return MaterialApp(
            title: 'BitBalance',
            debugShowCheckedModeBanner: false,
            builder: builder,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: AppTheme.isDark ? ThemeMode.dark : ThemeMode.light,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return MaterialApp(
          title: 'BitBalance',
          debugShowCheckedModeBanner: false,
          builder: builder,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: AppTheme.isDark ? ThemeMode.dark : ThemeMode.light,
          home: Builder(builder: home),
        );
      },
    );
  }
}
