import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'state/app_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

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
        if (_controller.loading) {
          return MaterialApp(
            title: 'BitBalance',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            themeMode: ThemeMode.light,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return MaterialApp(
          title: 'BitBalance',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          home: _controller.authenticated || _controller.guest
              ? HomeScreen(controller: _controller)
              : LoginScreen(controller: _controller),
        );
      },
    );
  }
}
