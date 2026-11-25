import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _register = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Введите email и пароль');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = _register
        ? await widget.controller.register(_email.text, _password.text)
        : await widget.controller.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() => _error = 'Не удалось войти. Проверьте email и пароль.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                color: AppTheme.cardLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          size: 56, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'BitBalance',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Личный финансовый помощник',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.mutedLight),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _authTab('Вход', !_register),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _authTab('Регистрация', _register),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Электронная почта',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_register ? 'Создать аккаунт' : 'Войти'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => widget.controller.enterGuest(),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Продолжить как гость'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Гость: данные хранятся только в этом браузере.\n'
                        'Аккаунт: данные синхронизируются с сервером.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppTheme.mutedLight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authTab(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() {
        _register = label == 'Регистрация';
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.mutedLight,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
