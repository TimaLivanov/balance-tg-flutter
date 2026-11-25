import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../theme/app_theme.dart';

String fmtMoney(double v) => v
    .toStringAsFixed(0)
    .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );

/// Как в HTML-версии: рекомендации округляются вверх до 100 ₽.
double roundUp100(double v) {
  final x = v < 0 ? 0.0 : v;
  return (x / 100 - 1e-9).ceil() * 100.0;
}

String fmtRec(double v) => fmtMoney(roundUp100(v));

String fmtDateRu(String iso) {
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

/// Короткие подписи для осей графика и легенды OHLC.
String fmtCompact(double v) {
  final sign = v < 0 ? '−' : '';
  final a = v.abs();
  if (a >= 1000000000) return '$sign${(a / 1000000000).toStringAsFixed(1)}B';
  if (a >= 1000000) return '$sign${(a / 1000000).toStringAsFixed(2)}M';
  if (a >= 1000)
    return '$sign${(a / 1000).toStringAsFixed(a >= 100000 ? 0 : 1)}k';
  return '$sign${a.toStringAsFixed(0)}';
}

/// На Web/Telegram не используем bounce и не отдаём жест браузеру:
/// вертикальный swipe всегда скроллит содержимое приложения.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}

/// Единственный скролл экрана: без chain-scroll, без вложенного SafeArea
/// снизу и без сброса позиции при появлении клавиатуры или смене данных.
class AppScrollView extends StatelessWidget {
  final String storageKey;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const AppScrollView({
    super.key,
    required this.storageKey,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bg,
      child: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: NotificationListener<OverscrollNotification>(
          onNotification: (_) => true,
          child: SingleChildScrollView(
            key: PageStorageKey(storageKey),
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            if (title != null) const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final double value;
  final String? subtitle;
  final Color color;
  final IconData icon;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmtMoney(value),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Полоса прогресса: чем больше закрыто, тем зеленее (красный → жёлтый → зелёный).
class ProgressLine extends StatelessWidget {
  final double value;
  final Color? color;
  const ProgressLine({super.key, required this.value, this.color});

  static Color debtColor(double value) {
    final v = value.clamp(0.0, 1.0);
    // HSL: 0° — красный, 120° — зелёный.
    return HSLColor.fromAHSL(1, v * 120, 0.75, 0.46).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final c = color ?? debtColor(v);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: v,
        color: c,
        backgroundColor: c.withValues(alpha: 0.14),
        minHeight: 8,
      ),
    );
  }
}

Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Подтвердить',
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
}
