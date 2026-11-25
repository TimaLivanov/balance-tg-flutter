import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppController get c => widget.controller;

  Future<void> _numberDialog({
    required String title,
    required double value,
    required void Function(double) onSave,
  }) async {
    final ctrl = TextEditingController(text: value.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
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
    if (ok == true)
      onSave(double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0);
  }

  Future<void> _timeDialog({
    required String title,
    required String value,
    required void Function(String) onSave,
  }) async {
    final parts = value.split(':');
    final h = TextEditingController(text: parts.isNotEmpty ? parts[0] : '09');
    final m = TextEditingController(text: parts.length > 1 ? parts[1] : '00');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: h,
                keyboardType: TextInputType.number,
              ),
            ),
            const Text(':'),
            Expanded(
              child: TextField(
                controller: m,
                keyboardType: TextInputType.number,
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
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      onSave('${h.text.padLeft(2, '0')}:${m.text.padLeft(2, '0')}');
    }
  }

  void _tgResult(String? error, String okText) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? okText)));
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state;
    return AppScrollView(
      storageKey: 'settings-scroll',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            eyebrow: 'Настройки',
            title: 'Правила и оформление',
            subtitle: 'Нормы, напоминания, тема и данные',
          ),
          const SizedBox(height: 20),

          SectionCard(
            title: 'Профиль',
            subtitle: c.guest
                ? 'Гостевой режим (данные на этом устройстве)'
                : (c.email ?? ''),
            action: c.guest
                ? null
                : TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Выйти из аккаунта?',
                        message: 'Вы вернётесь к экрану входа.',
                        confirm: 'Выйти',
                      );
                      if (ok == true) await c.logout();
                    },
                    child: const Text('Выйти'),
                  ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: .12),
                  child: Icon(Icons.person, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.guest ? 'Гость' : (c.email ?? 'Пользователь'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (c.guest)
                  OutlinedButton(
                    onPressed: () => c.openLogin(),
                    child: const Text('Войти'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Уведомления',
            subtitle: 'Как долго показывать сообщения',
            child: Column(
              children: [
                _selectRow('Время показа', s.toastMode, const {
                  'auto': 'Авто',
                  'short': 'Короткое, 4 с',
                  'normal': 'Обычное, 8 с',
                  'long': 'Долгое, 15 с',
                  'custom': 'Своё',
                }, (v) => c.updateSetting((x) => x.toastMode = v)),
                _tapRow(
                  'Своё время, секунд',
                  '${s.toastSec}',
                  () => _numberDialog(
                    title: 'Своё время, секунд',
                    value: s.toastSec.toDouble(),
                    onSave: (v) => c.updateSetting(
                      (x) => x.toastSec = v < 1 ? 1 : v.round(),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Не исчезать, пока не нажму'),
                  value: s.toastSticky,
                  onChanged: (v) => c.updateSetting((x) => x.toastSticky = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Уведомления бота',
            subtitle:
                'Telegram привязывается автоматически при входе из Mini App.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _selectRow('Уместность сообщений', s.tgMessageMode, const {
                  'smart': 'Умные сводки по фактам',
                  'ai': 'ИИ-анализ перед отправкой',
                }, (v) => c.updateSetting((x) => x.tgMessageMode = v)),
                Text(
                  'Бот сначала разбирает ваши данные, затем присылает вывод и конкретное действие. '
                  'ИИ-разбор включается в выбранный час; в остальное время идут умные сводки.',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Частота отправки',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                ...s.tgNotifyTimes.asMap().entries.map((e) {
                  final i = e.key;
                  final t = e.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primary.withValues(alpha: .12),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 10, color: AppTheme.primary),
                      ),
                    ),
                    title: Text(
                      'Отправка ${i + 1}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t,
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          tooltip: 'Изменить',
                          onPressed: () => _timeDialog(
                            title: 'Отправка ${i + 1}',
                            value: t,
                            onSave: (v) =>
                                c.updateSetting((x) => x.tgNotifyTimes[i] = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Убрать',
                          onPressed: () => c.updateSetting(
                            (x) => x.tgNotifyTimes.removeAt(i),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (s.tgNotifyTimes.length < 10)
                  TextButton.icon(
                    onPressed: () =>
                        c.updateSetting((x) => x.tgNotifyTimes.add('19:00')),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Добавить время'),
                  ),
                Text(
                  'До 10 времён в сутки. Бот проверяет час отправки.',
                  style: TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                _tapRow(
                  'Время ИИ-разбора',
                  s.aiNotifyTime,
                  () => _timeDialog(
                    title: 'Время ИИ-разбора',
                    value: s.aiNotifyTime,
                    onSave: (v) => c.updateSetting((x) => x.aiNotifyTime = v),
                  ),
                ),
                _tapRow(
                  'Тихий режим с',
                  s.aiQuietStart,
                  () => _timeDialog(
                    title: 'Тихий режим с',
                    value: s.aiQuietStart,
                    onSave: (v) => c.updateSetting((x) => x.aiQuietStart = v),
                  ),
                ),
                _tapRow(
                  'Тихий режим до',
                  s.aiQuietEnd,
                  () => _timeDialog(
                    title: 'Тихий режим до',
                    value: s.aiQuietEnd,
                    onSave: (v) => c.updateSetting((x) => x.aiQuietEnd = v),
                  ),
                ),
                _tapRow(
                  'Напоминать, если не вносили дней',
                  '${s.remindDays} (0 — выключить)',
                  () => _numberDialog(
                    title: 'Напоминать, если не вносили дней',
                    value: s.remindDays.toDouble(),
                    onSave: (v) => c.updateSetting(
                      (x) => x.remindDays = v < 0 ? 0 : v.round(),
                    ),
                  ),
                ),
                Text(
                  '0 — выключить напоминания. Бот пришлёт сообщение, если не было записей в течение дня.',
                  style: TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
                _tapRow(
                  'Макс. ИИ-уведомлений в день',
                  '${s.aiMaxNotifications}',
                  () => _numberDialog(
                    title: 'Макс. ИИ-уведомлений в день',
                    value: s.aiMaxNotifications.toDouble(),
                    onSave: (v) => c.updateSetting(
                      (x) => x.aiMaxNotifications = v < 0 ? 0 : v.round(),
                    ),
                  ),
                ),
                _selectRow(
                  'Часовой пояс (UTC)',
                  s.tzOffset == null
                      ? 'auto'
                      : (s.tzOffset!.round()).toString(),
                  _tzItems(),
                  (v) => c.updateSetting(
                    (x) => x.tzOffset = v == 'auto' ? null : double.tryParse(v),
                  ),
                ),
                const SizedBox(height: 8),
                if (c.inTelegram)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async => _tgResult(
                            await c.linkTelegram(),
                            'Telegram привязан',
                          ),
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('Привязать'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async => _tgResult(
                            await c.testTelegram(),
                            'Сообщение отправлено',
                          ),
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Тест'),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Откройте приложение через бота Telegram, чтобы привязать уведомления.',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async =>
                        _tgResult(await c.enablePush(), 'Push включён'),
                    icon: const Icon(Icons.notifications_active, size: 16),
                    label: const Text('Включить Push в браузере'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async =>
                        _tgResult(await c.debugNotify(), 'Проверка отправлена'),
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: const Text('Проверить настройки уведомлений'),
                  ),
                ),
                if (c.telegramError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      c.telegramError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Правило распределения',
            subtitle: 'Нормы и приоритеты',
            child: Column(
              children: [
                _selectRow(
                  'Пресет нормы',
                  s.preset,
                  const {
                    '50/30/20': '50 / 30 / 20',
                    '70/20/10': '70 / 20 / 10',
                    'custom': 'Своё',
                  },
                  (v) => c.updateSetting((x) {
                    x.preset = v;
                    if (v == '50/30/20') {
                      x.budget = Budget();
                    } else if (v == '70/20/10') {
                      x.budget = Budget(
                        needs: 70,
                        wants: 20,
                        goals: 10,
                        cushion: 0,
                      );
                    }
                  }),
                ),
                _tapRow(
                  'Норма обязательных, %',
                  '${s.budget.needs}',
                  () => _numberDialog(
                    title: 'Норма обязательных, %',
                    value: s.budget.needs,
                    onSave: (v) => c.updateSetting((x) {
                      x.budget = Budget(
                        needs: v,
                        wants: x.budget.wants,
                        goals: x.budget.goals,
                        cushion: x.budget.cushion,
                      );
                      x.preset = 'custom';
                    }),
                  ),
                ),
                _tapRow(
                  'Норма прочих, %',
                  '${s.budget.wants}',
                  () => _numberDialog(
                    title: 'Норма прочих, %',
                    value: s.budget.wants,
                    onSave: (v) => c.updateSetting((x) {
                      x.budget = Budget(
                        needs: x.budget.needs,
                        wants: v,
                        goals: x.budget.goals,
                        cushion: x.budget.cushion,
                      );
                      x.preset = 'custom';
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Настройки подушки',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                _selectRow(
                  'На сколько месяцев',
                  '${s.cushionMonths}',
                  const {
                    '1': '1 мес.',
                    '2': '2 мес.',
                    '3': '3 мес.',
                    '4': '4 мес.',
                    '6': '6 мес.',
                    '9': '9 мес.',
                    '12': '12 мес.',
                  },
                  (v) => c.updateSetting((x) => x.cushionMonths = int.parse(v)),
                ),
                _selectRow('Что учитывать', s.cushionInclude, const {
                  'need': 'Только обязательные',
                  'need_rare': 'Обязательные + редкие',
                  'all': 'Все категории',
                }, (v) => c.updateSetting((x) => x.cushionInclude = v)),
                _selectRow('От чего считать', s.cushionBase, const {
                  'avg': 'Среднее по тратам',
                  'rec': 'Рекомендуемые платежи',
                  'min': 'Минимальные платежи',
                }, (v) => c.updateSetting((x) => x.cushionBase = v)),
                _tapRow(
                  'Окно для среднего, дней',
                  '${s.windowDays}',
                  () => _numberDialog(
                    title: 'Окно для среднего, дней',
                    value: s.windowDays.toDouble(),
                    onSave: (v) => c.updateSetting(
                      (x) => x.windowDays = v < 1 ? 1 : v.round(),
                    ),
                  ),
                ),
                _selectRow('Порядок погашения долгов', s.strategy, const {
                  'snow': 'Снежок: мелкие сначала',
                  'aval': 'Лавина: крупные сначала',
                  'order': 'По порядку добавления',
                }, (v) => c.updateSetting((x) => x.strategy = v)),
                _selectRow('Порог заметности статьи', s.cutLevel, const {
                  'eff': 'Эффективный (от 10%)',
                  'hard': 'Быстрый (от 20%)',
                  'soft': 'Экономичный (от 5%)',
                }, (v) => c.updateSetting((x) => x.cutLevel = v)),
                _selectRow(
                  'Последних операций в списке',
                  s.recentOpsLimit.toString(),
                  const {'5': '5', '10': '10', '30': '30'},
                  (v) => c.updateSetting(
                    (x) => x.recentOpsLimit = int.tryParse(v) ?? 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Здоровье денег: пороги',
            child: Column(
              children: [
                _tapRow(
                  'Обязательные не выше, %',
                  '${s.health.needsMax}',
                  () => _numberDialog(
                    title: 'Обязательные не выше, %',
                    value: s.health.needsMax,
                    onSave: (v) => c.updateSetting(
                      (x) => x.health = Health(
                        needsMax: v,
                        saveMin: x.health.saveMin,
                        runwayMin: x.health.runwayMin,
                        debtMonths: x.health.debtMonths,
                      ),
                    ),
                  ),
                ),
                _tapRow(
                  'Остаток не ниже, %',
                  '${s.health.saveMin}',
                  () => _numberDialog(
                    title: 'Остаток не ниже, %',
                    value: s.health.saveMin,
                    onSave: (v) => c.updateSetting(
                      (x) => x.health = Health(
                        needsMax: x.health.needsMax,
                        saveMin: v,
                        runwayMin: x.health.runwayMin,
                        debtMonths: x.health.debtMonths,
                      ),
                    ),
                  ),
                ),
                _tapRow(
                  'Запас не меньше, дней',
                  '${s.health.runwayMin}',
                  () => _numberDialog(
                    title: 'Запас не меньше, дней',
                    value: s.health.runwayMin,
                    onSave: (v) => c.updateSetting(
                      (x) => x.health = Health(
                        needsMax: x.health.needsMax,
                        saveMin: x.health.saveMin,
                        runwayMin: v,
                        debtMonths: x.health.debtMonths,
                      ),
                    ),
                  ),
                ),
                _tapRow(
                  'Долги закрыть за, мес.',
                  '${s.health.debtMonths}',
                  () => _numberDialog(
                    title: 'Долги закрыть за, мес.',
                    value: s.health.debtMonths.toDouble(),
                    onSave: (v) => c.updateSetting(
                      (x) => x.health = Health(
                        needsMax: x.health.needsMax,
                        saveMin: x.health.saveMin,
                        runwayMin: x.health.runwayMin,
                        debtMonths: v.round().toDouble(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Внешний вид',
            subtitle: 'Тема: ${s.theme == 'dark' ? 'тёмная' : 'светлая'}',
            child: Column(
              children: [
                _selectRow('Тема', s.theme, const {
                  'light': 'Светлая',
                  'dark': 'Тёмная',
                }, (v) => c.updateSetting((x) => x.theme = v)),
                _selectRow('Размер шрифта', s.fontSize, const {
                  's': 'Мелкий',
                  'm': 'Обычный',
                  'l': 'Крупный',
                }, (v) => c.updateSetting((x) => x.fontSize = v)),
                _selectRow('Цвет акцента', s.accent, const {
                  'indigo': 'Синий',
                  'emerald': 'Зелёный',
                  'sky': 'Голубой',
                  'violet': 'Фиолетовый',
                }, (v) => c.updateSetting((x) => x.accent = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Поведение ИИ',
            subtitle: 'Влияет на стиль ответов советника',
            child: _selectRow('Режим', s.aiBehavior, const {
              'balanced': 'Сбалансированный',
              'strict': 'Строгий (только факты)',
              'coach': 'Коуч (мотивация)',
              'analyst': 'Аналитик (подробно)',
              'choleric': 'Холерик (жёстко)',
            }, (v) => c.updateSetting((x) => x.aiBehavior = v)),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Справка',
            subtitle: 'Как пользоваться BitBalance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Главная — баланс, график и быстрая запись.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Деньги — категории, долги, накопления и подушка.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Аналитика — тренды, здоровье денег и AI-советник.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'История — все операции, удаление и экспорт.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Гость: данные хранятся в этом браузере. Аккаунт: синхронизация с сервером.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tapRow(String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Text(
        value,
        style: TextStyle(fontSize: 12, color: AppTheme.muted),
      ),
      onTap: onTap,
    );
  }

  /// Ключ — часы: worker прибавляет tzOffset * 60000 к времени.
  Map<String, String> _tzItems() {
    final items = <String, String>{'auto': 'Авто'};
    for (var h = -12; h <= 14; h++) {
      final sign = h >= 0 ? '+' : '';
      var label = 'UTC$sign$h';
      if (h == 3) label = 'UTC+3 (Москва)';
      items[h.toString()] = label;
    }
    return items;
  }

  Widget _selectRow(
    String label,
    String value,
    Map<String, String> items,
    void Function(String) onChanged,
  ) {
    final keys = items.keys.toList();
    final safeValue = keys.contains(value) ? value : keys.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              items: keys
                  .map(
                    (k) =>
                        DropdownMenuItem(value: k, child: Text(items[k] ?? k)),
                  )
                  .toList(),
              onChanged: (v) => onChanged(v ?? safeValue),
            ),
          ),
        ],
      ),
    );
  }
}
