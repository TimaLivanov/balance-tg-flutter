import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Свеча/бар с настоящими OHLC из пересчёта истории (аналог buildBars в HTML).
class Bar {
  final String date;
  final String label;
  final double open;
  final double high;
  final double low;
  final double close;
  final bool empty;
  final int volume;

  Bar({
    required this.date,
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.empty = false,
    this.volume = 0,
  });
}

List<Bar> buildBars(List<DailyPoint> points, String tf) {
  if (points.isEmpty) return [];
  final sorted = List<DailyPoint>.from(points)
    ..sort((a, b) => a.date.compareTo(b.date));

  final byDate = <String, List<DailyPoint>>{};
  for (final p in sorted) {
    byDate.putIfAbsent(p.date, () => []).add(p);
  }

  final window = tf == 'day'
      ? 14
      : tf == 'week'
          ? 7
          : tf == 'month'
              ? 30
              : 365;
  final now = DateTime.now();
  final endKey = _key(now);
  final dates = byDate.keys.toList()..sort();
  final first = DateTime.parse(dates.first);
  var from = DateTime(now.year, now.month, now.day).subtract(Duration(days: window - 1));
  if (from.isBefore(first)) from = first;

  final daily = <Bar>[];
  double? prevClose;
  for (var d = DateTime(from.year, from.month, from.day);
      _key(d).compareTo(endKey) <= 0;
      d = d.add(const Duration(days: 1))) {
    final key = _key(d);
    final list = byDate[key];
    if (list == null || list.isEmpty) {
      // Дни без записей — плоские бары на уровне предыдущего закрытия.
      if (prevClose != null) {
        daily.add(_bar(key, prevClose, prevClose, prevClose, prevClose, true, 0));
      }
      continue;
    }
    final open = list.first.open;
    var high = list.first.high;
    var low = list.first.low;
    for (final p in list) {
      if (p.high > high) high = p.high;
      if (p.low < low) low = p.low;
    }
    final close = list.last.close;
    daily.add(_bar(key, open, high, low, close, false, list.length));
    prevClose = close;
  }

  if (tf != 'year') return daily;

  // Год — недельные свечи, как в эталонной HTML-версии.
  final weeks = <String, Bar>{};
  final order = <String>[];
  for (final b in daily) {
    final k = _key(_weekStart(DateTime.parse(b.date)));
    final w = weeks[k];
    if (w == null) {
      weeks[k] = Bar(
        date: k,
        label: '${k.substring(8, 10)}.${k.substring(5, 7)}',
        open: b.open,
        high: b.high,
        low: b.low,
        close: b.close,
        volume: b.volume,
      );
      order.add(k);
    } else {
      weeks[k] = Bar(
        date: k,
        label: '${k.substring(8, 10)}.${k.substring(5, 7)}',
        open: w.open,
        high: math.max(w.high, b.high),
        low: math.min(w.low, b.low),
        close: b.close,
        volume: w.volume + b.volume,
      );
    }
  }
  return order.map((k) => weeks[k]!).toList();
}

Bar _bar(String date, double o, double h, double l, double c, bool empty, int volume) {
  return Bar(
    date: date,
    label: date.substring(5, 7) == '01' || date.substring(8, 10) == '01'
        ? '${date.substring(5, 7)}.${date.substring(8, 10)}'
        : '${date.substring(8, 10)}',
    open: o,
    high: h,
    low: l,
    close: c,
    empty: empty,
    volume: volume,
  );
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// График в стиле TradingView/Binance: свечи, MA, сетка, объём, перекрестие
/// и легенда OHLC. Поддерживает масштабирование через [zoom].
class BalanceChart extends StatefulWidget {
  final List<Bar> bars;
  final bool candle;
  final bool ma;
  final double zoom;
  final double height;

  const BalanceChart({
    super.key,
    required this.bars,
    this.candle = true,
    this.ma = false,
    this.zoom = 1,
    this.height = 240,
  });

  @override
  State<BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<BalanceChart> {
  Offset? _cursor;

  @override
  Widget build(BuildContext context) {
    final visibleCount = (60 / widget.zoom).round().clamp(8, 120);
    final show = widget.bars.length > visibleCount
        ? widget.bars.sublist(widget.bars.length - visibleCount)
        : widget.bars;

    return SizedBox(
      height: widget.height,
      child: Listener(
        onPointerDown: (e) => setState(() => _cursor = e.localPosition),
        onPointerMove: (e) => setState(() => _cursor = e.localPosition),
        onPointerUp: (_) => setState(() => _cursor = null),
        onPointerCancel: (_) => setState(() => _cursor = null),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, widget.height),
              painter: _BalanceChartPainter(
                bars: show,
                candle: widget.candle,
                ma: widget.ma,
                cursor: _cursor,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BalanceChartPainter extends CustomPainter {
  final List<Bar> bars;
  final bool candle;
  final bool ma;
  final Offset? cursor;

  _BalanceChartPainter({
    required this.bars,
    required this.candle,
    required this.ma,
    required this.cursor,
  });

  static const padL = 6.0;
  static const padR = 62.0;
  static const padT = 34.0;
  static const padB = 24.0;

  late double plotW;
  late double plotH;
  late double cell;
  late double minV;
  late double maxV;
  late double step;
  late double y0;

  double yOf(double v) => padT + (maxV - v) / (maxV - minV) * plotH;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    plotW = size.width - padL - padR;
    plotH = size.height - padT - padB;
    if (plotW <= 10 || plotH <= 10) return;
    cell = plotW / bars.length;

    _calcRange();
    y0 = (minV < 0 && maxV > 0)
        ? yOf(0).clamp(padT, padT + plotH)
        : (maxV <= 0 ? padT : padT + plotH);

    _drawZones(canvas, size);
    _drawGrid(canvas, size);
    _drawVolume(canvas);
    if (candle) {
      _drawCandles(canvas);
    } else {
      _drawLine(canvas);
    }
    if (ma) {
      _drawMa(canvas, 7, const Color(0xFFF0B90B));
      _drawMa(canvas, 25, const Color(0xFFA78BFA));
    }

    final idx = _cursorIndex();
    if (idx != null) _drawCrosshair(canvas, size, idx);
    _drawLegend(canvas, idx ?? bars.length - 1);
  }

  void _calcRange() {
    var lo = bars.first.low;
    var hi = bars.first.high;
    for (final b in bars) {
      if (b.low < lo) lo = b.low;
      if (b.high > hi) hi = b.high;
    }
    if ((hi - lo).abs() < 1) {
      final pad = math.max(500.0, hi.abs() * 0.05);
      lo -= pad;
      hi += pad;
    }
    final pad = math.max((hi - lo) * 0.08, 500.0);
    lo -= pad;
    hi += pad;

    step = _niceStep((hi - lo) / 8);
    var guard = 0;
    while ((hi - lo) / step < 6 && guard < 6) {
      step = _niceStep(step / 2);
      guard++;
    }
    minV = (lo / step).floor() * step;
    maxV = (hi / step).ceil() * step;
    if (maxV <= minV) maxV = minV + step;
  }

  int? _cursorIndex() {
    final pos = cursor;
    if (pos == null) return null;
    final x = pos.dx - padL;
    if (x < 0 || x > plotW || pos.dy < padT || pos.dy > padT + plotH) return null;
    return (x / cell).floor().clamp(0, bars.length - 1);
  }

  void _drawZones(Canvas canvas, Size size) {
    final green = Paint()..color = const Color(0xFF0ECB81).withValues(alpha: 0.045);
    final red = Paint()..color = const Color(0xFFF6465D).withValues(alpha: 0.055);
    canvas.drawRect(Rect.fromLTWH(padL, padT, plotW, math.max(0, y0 - padT)), green);
    canvas.drawRect(Rect.fromLTWH(padL, y0, plotW, math.max(0, padT + plotH - y0)), red);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppTheme.borderLight.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    // Вертикальная сетка и подписи времени.
    final labelEvery = bars.length > 20
        ? (bars.length / 7).ceil()
        : bars.length > 12
            ? 2
            : 1;
    for (var i = 0; i < bars.length; i++) {
      final x = padL + (i + 0.5) * cell;
      canvas.drawLine(Offset(x, padT), Offset(x, padT + plotH), grid);
      if (i % labelEvery == 0 || i == bars.length - 1) {
        _text(
          canvas,
          bars[i].label,
          Offset(x - 18, padT + plotH + 6),
          color: AppTheme.mutedLight,
          size: 9,
          align: TextAlign.center,
          width: 36,
        );
      }
    }

    // Горизонтальные уровни с ценой справа (как на бирже).
    for (var k = (minV / step - 1e-9).ceil();
        k <= (maxV / step + 1e-9).floor();
        k++) {
      final v = k * step;
      final y = yOf(v);
      final zero = k == 0;
      final line = Paint()
        ..color = zero
            ? AppTheme.mutedLight.withValues(alpha: 0.65)
            : AppTheme.borderLight.withValues(alpha: 0.45)
        ..strokeWidth = zero ? 1.2 : 1;
      if (!zero) {
        _dashedLine(canvas, Offset(padL, y), Offset(padL + plotW, y), line);
      } else {
        canvas.drawLine(Offset(padL, y), Offset(padL + plotW, y), line);
      }
      _text(
        canvas,
        fmtCompact(v),
        Offset(padL + plotW + 6, y - 6),
        color: zero
            ? AppTheme.textLight
            : (v > 0 ? AppTheme.success : AppTheme.danger),
        size: 9,
      );
    }
  }

  void _drawVolume(Canvas canvas) {
    final maxVol = bars.map((b) => b.volume).reduce(math.max);
    if (maxVol <= 1) return;
    final h = plotH * 0.16;
    final bw = math.max(2.0, cell * 0.7);
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final bh = b.volume / maxVol * h;
      canvas.drawRect(
        Rect.fromLTWH(
          padL + (i + 0.5) * cell - bw / 2,
          padT + plotH - bh,
          bw,
          bh,
        ),
        Paint()
            ..color = (b.close >= b.open ? AppTheme.success : AppTheme.danger)
                .withValues(alpha: 0.28),
      );
    }
  }

  void _drawCandles(Canvas canvas) {
    final bw = (cell * 0.72).clamp(2.5, 18.0);
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final up = b.close >= b.open;
      final color = up ? const Color(0xFF0ECB81) : const Color(0xFFF6465D);
      final cx = padL + (i + 0.5) * cell;
      canvas.drawLine(
        Offset(cx, yOf(b.high)),
        Offset(cx, yOf(b.low)),
        Paint()..color = color..strokeWidth = 1.2,
      );
      final top = yOf(math.max(b.open, b.close));
      final bottom = yOf(math.min(b.open, b.close));
      canvas.drawRect(
        Rect.fromLTWH(cx - bw / 2, top, bw, math.max(1.5, bottom - top)),
        Paint()..color = b.empty ? color.withValues(alpha: 0.4) : color,
      );
    }
  }

  void _drawLine(Canvas canvas) {
    final path = Path();
    for (var i = 0; i < bars.length; i++) {
      final x = padL + (i + 0.5) * cell;
      final y = yOf(bars[i].close);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final up = bars.last.close >= bars.first.open;
    canvas.drawPath(
      path,
      Paint()
        ..color = up ? const Color(0xFF0ECB81) : const Color(0xFFF6465D)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < bars.length; i++) {
      canvas.drawCircle(
        Offset(padL + (i + 0.5) * cell, yOf(bars[i].close)),
        2,
        Paint()..color = up ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
      );
    }
  }

  void _drawMa(Canvas canvas, int period, Color color) {
    if (bars.length <= period) return;
    final path = Path();
    for (var i = period - 1; i < bars.length; i++) {
      var sum = 0.0;
      for (var j = i - period + 1; j <= i; j++) {
        sum += bars[j].close;
      }
      final x = padL + (i + 0.5) * cell;
      final y = yOf(sum / period);
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
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawCrosshair(Canvas canvas, Size size, int idx) {
    final b = bars[idx];
    final x = padL + (idx + 0.5) * cell;
    final y = cursor!.dy.clamp(padT, padT + plotH);
    final line = Paint()
      ..color = AppTheme.mutedLight.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    _dashedLine(canvas, Offset(x, padT), Offset(x, padT + plotH), line);
    _dashedLine(canvas, Offset(padL, y), Offset(padL + plotW, y), line);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(padL + plotW + 2, y - 8, padR - 4, 16),
        const Radius.circular(3),
      ),
      Paint()..color = AppTheme.primary,
    );
    _text(
      canvas,
      fmtCompact(maxV - (y - padT) / plotH * (maxV - minV)),
      Offset(padL + plotW + 6, y - 6),
      color: Colors.white,
      size: 9,
    );
    _text(
      canvas,
      b.label,
      Offset(x - 18, padT + plotH + 6),
      color: Colors.white,
      size: 9,
      align: TextAlign.center,
      width: 36,
      background: AppTheme.primary,
    );
  }

  void _drawLegend(Canvas canvas, int idx) {
    final b = bars[idx];
    final change = b.close - b.open;
    final pct = b.open != 0 ? change / b.open.abs() * 100 : 0.0;
    final color = change >= 0 ? const Color(0xFF0ECB81) : const Color(0xFFF6465D);
    final text =
        'O ${fmtCompact(b.open)}  H ${fmtCompact(b.high)}  L ${fmtCompact(b.low)}  C ${fmtCompact(b.close)}  '
        '${change >= 0 ? '+' : ''}${fmtCompact(change)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: plotW - 8);
    tp.paint(canvas, Offset(padL + 4, 6));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    final d = (b - a).distance;
    if (d == 0) return;
    final dir = (b - a) / d;
    for (var x = 0.0; x < d; x += dash * 2) {
      canvas.drawLine(
        a + dir * x,
        a + dir * math.min(x + dash, d),
        paint,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    required double size,
    TextAlign align = TextAlign.left,
    double? width,
    Color? background,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width ?? double.infinity);
    if (background != null && width != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx, at.dy - 1, width, tp.height + 2),
          const Radius.circular(3),
        ),
        Paint()..color = background,
      );
    }
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _BalanceChartPainter old) =>
      old.bars != bars ||
      old.candle != candle ||
      old.ma != ma ||
      old.cursor != cursor;
}

double _niceStep(double raw) {
  if (raw <= 0 || !raw.isFinite) return 1;
  final exp = math.log(raw) / math.ln10;
  final p = math.pow(10, exp.floor()).toDouble();
  final f = raw / p;
  final nice = f <= 1 ? 1.0 : f <= 2 ? 2.0 : f <= 2.5 ? 2.5 : f <= 5 ? 5.0 : 10.0;
  return nice * p;
}
