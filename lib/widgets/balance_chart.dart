import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/app_controller.dart';

class Bar {
  final String label;
  final double open;
  final double high;
  final double low;
  final double close;
  final bool empty;
  Bar({
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.empty = false,
  });
}

List<Bar> buildBars(List<DailyPoint> points, String tf) {
  if (points.isEmpty) return [];
  final window = tf == 'day'
      ? 14
      : tf == 'week'
          ? 28
          : tf == 'month'
              ? 30
              : 365;
  final sorted = List<DailyPoint>.from(points)
    ..sort((a, b) => a.date.compareTo(b.date));
  final start = sorted.first.date;
  final end = sorted.last.date;
  var from = DateTime.parse(end).subtract(Duration(days: window - 1));
  final first = DateTime.parse(start);
  if (from.isBefore(first)) from = first;

  final byDate = <String, List<double>>{};
  for (final p in sorted) {
    byDate.putIfAbsent(p.date, () => []).add(p.balance);
  }
  final keys = byDate.keys.toList()..sort();
  final bars = <Bar>[];
  double prev = byDate[keys.first]!.first;
  for (var d = DateTime(from.year, from.month, from.day);
      !d.isAfter(DateTime.parse(end));
      d = d.add(const Duration(days: 1))) {
    final key =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final vals = byDate[key];
    if (vals == null || vals.isEmpty) {
      bars.add(Bar(
        label: tf == 'day'
            ? '${d.day}'
            : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
        open: prev,
        high: prev,
        low: prev,
        close: prev,
        empty: true,
      ));
      continue;
    }
    final open = prev;
    var high = vals.fold<double>(open, (a, b) => a > b ? a : b);
    var low = vals.fold<double>(open, (a, b) => a < b ? a : b);
    final close = vals.last;
    high = high > close ? high : close;
    low = low < close ? low : close;
    bars.add(Bar(
      label: tf == 'day'
          ? '${d.day}'
          : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
      open: open,
      high: high,
      low: low,
      close: close,
    ));
    prev = close;
  }
  return bars;
}

class BalanceChart extends StatelessWidget {
  final List<Bar> bars;
  final bool candle;
  final bool ma;
  final double zoom;
  const BalanceChart({
    super.key,
    required this.bars,
    this.candle = true,
    this.ma = false,
    this.zoom = 1,
  });

  @override
  Widget build(BuildContext context) {
    final visible = (60 / zoom).round().clamp(8, 60);
    final show = bars.length > visible ? bars.sublist(bars.length - visible) : bars;
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 200),
          painter: _BalanceChartPainter(
            bars: show,
            candle: candle,
            ma: ma,
          ),
        );
      },
    );
  }
}

class _BalanceChartPainter extends CustomPainter {
  final List<Bar> bars;
  final bool candle;
  final bool ma;
  _BalanceChartPainter({required this.bars, required this.candle, required this.ma});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final padL = 8.0;
    final padR = 8.0;
    final padT = 12.0;
    final padB = 22.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    var minV = bars.map((b) => b.low).reduce((a, b) => a < b ? a : b);
    var maxV = bars.map((b) => b.high).reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 1) {
      final pad = maxV.abs() * 0.05 < 1000 ? 1000.0 : maxV.abs() * 0.05;
      minV -= pad;
      maxV += pad;
    }
    final range = maxV - minV;
    final span = range * 1.12;
    final center = (maxV + minV) / 2;
    minV = center - span / 2;
    maxV = center + span / 2;

    double yOf(double v) => padT + h - ((v - minV) / (maxV - minV)) * h;
    final cell = w / bars.length;

    // Сетка
    final grid = Paint()
      ..color = AppTheme.borderLight.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padT + (h / 4) * i;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), grid);
      final val = maxV - (span / 4) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: _compact(val),
          style: const TextStyle(fontSize: 9, color: AppTheme.mutedLight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL + 2, y - 11));
    }

    // Нулевая линия
    if (minV < 0 && maxV > 0) {
      canvas.drawLine(
        Offset(padL, yOf(0)),
        Offset(padL + w, yOf(0)),
        Paint()
          ..color = AppTheme.mutedLight.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    final up = const Color(0xFF0ECB81);
    final down = const Color(0xFFF6465D);
    final last = bars.last.close;
    final first = bars.first.open;
    final color = last >= first ? up : down;

    if (candle) {
      final bw = (cell * 0.62).clamp(3.0, 18.0);
      for (var i = 0; i < bars.length; i++) {
        final b = bars[i];
        final cx = padL + cell * i + cell / 2;
        final c = b.close >= b.open ? up : down;
        canvas.drawLine(
          Offset(cx, yOf(b.high)),
          Offset(cx, yOf(b.low)),
          Paint()..color = c..strokeWidth = 1.4,
        );
        final top = yOf(b.open > b.close ? b.open : b.close);
        final bottom = yOf(b.open > b.close ? b.close : b.open);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - bw / 2, top, bw, (bottom - top).clamp(1.5, h)),
            const Radius.circular(2),
          ),
          Paint()..color = b.empty ? c.withValues(alpha: 0.35) : c,
        );
      }
    } else {
      final path = Path();
      for (var i = 0; i < bars.length; i++) {
        final x = padL + cell * i + cell / 2;
        final y = yOf(bars[i].close);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (ma) {
      _drawMa(canvas, bars, 7, yOf, cell, padL, const Color(0xFFF0B90B));
      _drawMa(canvas, bars, 25, yOf, cell, padL, const Color(0xFFC99402));
    }

    // Подписи оси X
    final step = (bars.length / 6).ceil().clamp(1, 20);
    for (var i = 0; i < bars.length; i += step) {
      final tp = TextPainter(
        text: TextSpan(
          text: bars[i].label,
          style: const TextStyle(fontSize: 9, color: AppTheme.mutedLight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL + cell * i + cell / 2 - tp.width / 2, size.height - 15));
    }
  }

  void _drawMa(
    Canvas canvas,
    List<Bar> bars,
    int period,
    double Function(double) yOf,
    double cell,
    double padL,
    Color color,
  ) {
    if (bars.length <= period) return;
    final path = Path();
    for (var i = period - 1; i < bars.length; i++) {
      var sum = 0.0;
      for (var j = i - period + 1; j <= i; j++) {
        sum += bars[j].close;
      }
      final avg = sum / period;
      final x = padL + cell * i + cell / 2;
      final y = yOf(avg);
      if (i == period - 1) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
  }

  String _compact(double v) {
    final a = v.abs();
    if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _BalanceChartPainter old) =>
      old.bars != bars || old.candle != candle || old.ma != ma;
}
