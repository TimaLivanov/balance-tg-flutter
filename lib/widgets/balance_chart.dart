import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  final List<String> ops;
  final double income;
  final double expense;

  Bar({
    required this.date,
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.empty = false,
    this.volume = 0,
    this.ops = const [],
    this.income = 0,
    this.expense = 0,
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
  var from = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: window - 1));
  if (from.isBefore(first)) from = first;

  final daily = <Bar>[];
  double? prevClose;
  for (
    var d = DateTime(from.year, from.month, from.day);
    _key(d).compareTo(endKey) <= 0;
    d = d.add(const Duration(days: 1))
  ) {
    final key = _key(d);
    final list = byDate[key];
    if (list == null || list.isEmpty) {
      // Дни без записей — плоские бары на уровне предыдущего закрытия.
      if (prevClose != null) {
        daily.add(
          _bar(key, prevClose, prevClose, prevClose, prevClose, true, 0),
        );
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
    daily.add(
      _bar(
        key,
        open,
        high,
        low,
        close,
        false,
        list.length,
        ops: list.expand((p) => p.ops).toList(),
        income: list.fold(0.0, (a, p) => a + p.income),
        expense: list.fold(0.0, (a, p) => a + p.expense),
      ),
    );
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
        ops: b.ops,
        income: b.income,
        expense: b.expense,
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
        ops: [...w.ops, ...b.ops],
        income: w.income + b.income,
        expense: w.expense + b.expense,
      );
    }
  }
  return order.map((k) => weeks[k]!).toList();
}

Bar _bar(
  String date,
  double o,
  double h,
  double l,
  double c,
  bool empty,
  int volume, {
  List<String> ops = const [],
  double income = 0,
  double expense = 0,
}) {
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
    ops: ops,
    income: income,
    expense: expense,
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

  /// Показывать сводку по свече при наведении/касании (как в HTML).
  final bool showSummary;

  const BalanceChart({
    super.key,
    required this.bars,
    this.candle = true,
    this.ma = false,
    this.zoom = 1,
    this.height = 240,
    this.showSummary = true,
  });

  @override
  State<BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<BalanceChart> {
  /// Как в Binance: окно свечей и сдвиг по истории живут внутри графика.
  late int _barCount;
  double _rightOffset = 0;

  final ValueNotifier<Offset?> _cursor = ValueNotifier(null);
  final Map<int, Offset> _pointers = {};

  double _startOffset = 0;
  double _startCell = 1;
  double _dragAccum = 0;

  /// Щипок считаем через Listener: ScaleGestureRecognizer перехватывает
  /// вертикальный жест и тормозит скролл страницы в Telegram.
  double? _pinchDistance;
  double? _pinchStartCount;

  @override
  void initState() {
    super.initState();
    _barCount = (60 / widget.zoom).round().clamp(8, 120);
  }

  @override
  void dispose() {
    _cursor.dispose();
    _pinnedCandle.dispose();
    super.dispose();
  }

  int get _visibleCount =>
      widget.bars.isEmpty ? 1 : _barCount.clamp(1, widget.bars.length);

  int get _maxOffset => widget.bars.length - _visibleCount < 0
      ? 0
      : widget.bars.length - _visibleCount;

  double _cellFor(double width) {
    final plotW = width - _BalanceChartPainter.padL - _BalanceChartPainter.padR;
    return plotW > 0 ? plotW / _visibleCount : 1;
  }

  int? _indexAt(Offset pos) {
    final width = (context.findRenderObject() as RenderBox?)?.size.width ?? 320;
    final plotW = width - _BalanceChartPainter.padL - _BalanceChartPainter.padR;
    final x = pos.dx - _BalanceChartPainter.padL;
    if (plotW <= 0 || x < 0 || x > plotW) return null;
    final (start, end) = _window();
    final i = start + (x / plotW * (end - start)).floor();
    return i.clamp(0, widget.bars.length - 1);
  }

  /// Зафиксированная свеча для подробной сводки (как popup в HTML).
  final ValueNotifier<int?> _pinnedCandle = ValueNotifier(null);

  void _setCandle(Offset pos) {
    if (!widget.showSummary) return;
    final i = _indexAt(pos);
    if (i != null && i != _pinnedCandle.value) _pinnedCandle.value = i;
  }

  (int, int) _window() {
    final end = widget.bars.length - _rightOffset.round().clamp(0, _maxOffset);
    final start = math.max(0, end - _visibleCount);
    return (start, end);
  }

  void _reset() {
    _pinnedCandle.value = null;
    setState(() {
      _barCount = (60 / widget.zoom).round().clamp(8, 120);
      _rightOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (start, end) = _window();
    final show = widget.bars.sublist(start, end);

    // Высота задаётся только области графика: сводка по свече должна
    // расширять виджет, иначе она перекрывается следующим блоком экрана.
    return MouseRegion(
      onExit: (_) {
        if (_pointers.isEmpty) _cursor.value = null;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.mouse) _setCandle(e.localPosition);
          _pointers[e.pointer] = e.localPosition;
          _cursor.value = e.localPosition;
          if (_pointers.length == 2) {
            final p = _pointers.values.toList();
            _pinchDistance = (p[0] - p[1]).distance;
            _pinchStartCount = _barCount.toDouble();
          }
        },
        onPointerMove: (e) {
          _pointers[e.pointer] = e.localPosition;
          if (_pointers.length == 2 &&
              _pinchDistance != null &&
              _pinchStartCount != null &&
              _pinchDistance! > 0) {
            final p = _pointers.values.toList();
            final ratio = (p[0] - p[1]).distance / _pinchDistance!;
            final count = (_pinchStartCount! / ratio).round().clamp(8, 120);
            if (count != _barCount) {
              setState(() {
                _barCount = count;
                _rightOffset = _rightOffset
                    .clamp(0, math.max(0, widget.bars.length - count))
                    .toDouble();
              });
            }
            return;
          }
          if (e.kind == PointerDeviceKind.mouse) {
            _cursor.value = e.localPosition;
            _setCandle(e.localPosition);
          }
        },
        onPointerUp: (e) => _endPointer(e.pointer),
        onPointerCancel: (e) => _endPointer(e.pointer),
        onPointerHover: (e) {
          _cursor.value = e.localPosition;
          _setCandle(e.localPosition);
        },
        onPointerSignal: (e) {
          // Обычное колесо/скролл листает экран, масштаб — только с Ctrl/Cmd.
          final zoomModifier =
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          if (e is PointerScrollEvent && zoomModifier) {
            setState(() {
              _barCount = (_barCount + (e.scrollDelta.dy > 0 ? 2 : -2)).clamp(
                8,
                120,
              );
              _rightOffset = _rightOffset.clamp(0, _maxOffset).toDouble();
            });
          }
        },
        // Только жесты, участвующие в арене, чтобы родительский скролл
        // не подхватывал горизонтальное движение по графику.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _dragAccum = 0;
            _startOffset = _rightOffset;
            _startCell = _cellFor(
              (context.findRenderObject() as RenderBox?)?.size.width ?? 320,
            );
          },
          onHorizontalDragUpdate: (d) {
            _dragAccum += d.delta.dx;
            setState(() {
              _rightOffset = (_startOffset + _dragAccum / _startCell)
                  .clamp(0, _maxOffset)
                  .toDouble();
            });
          },
          onHorizontalDragEnd: (_) {},
          onTapUp: (d) {
            if (d.kind != PointerDeviceKind.mouse) _setCandle(d.localPosition);
          },
          onDoubleTap: _reset,
          child: ValueListenableBuilder<int?>(
            valueListenable: _pinnedCandle,
            builder: (context, pinned, _) => ValueListenableBuilder<Offset?>(
              valueListenable: _cursor,
              builder: (context, cursor, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: widget.height,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return CustomPaint(
                            size: Size(constraints.maxWidth, widget.height),
                            painter: _BalanceChartPainter(
                              bars: show,
                              candle: widget.candle,
                              ma: widget.ma,
                              cursor: cursor,
                              pinnedCandle: pinned,
                            ),
                          );
                        },
                      ),
                    ),
                    if (widget.showSummary &&
                        pinned != null &&
                        pinned >= 0 &&
                        pinned < show.length)
                      _CandleSummary(bar: show[pinned]),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _endPointer(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2) {
      _pinchDistance = null;
      _pinchStartCount = null;
    }
    if (_pointers.isEmpty && !kIsWeb) _cursor.value = null;
  }
}

class _BalanceChartPainter extends CustomPainter {
  final List<Bar> bars;
  final bool candle;
  final bool ma;
  final Offset? cursor;
  final int? pinnedCandle;

  _BalanceChartPainter({
    required this.bars,
    required this.candle,
    required this.ma,
    required this.cursor,
    this.pinnedCandle,
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
    final legendIdx = pinnedCandle ?? idx;
    if (legendIdx != null && legendIdx >= 0 && legendIdx < bars.length) {
      _drawCandleMarker(canvas, legendIdx);
    }
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
    if (x < 0 || x > plotW || pos.dy < padT || pos.dy > padT + plotH)
      return null;
    return (x / cell).floor().clamp(0, bars.length - 1);
  }

  void _drawZones(Canvas canvas, Size size) {
    final green = Paint()
      ..color = const Color(0xFF0ECB81).withValues(alpha: 0.045);
    final red = Paint()
      ..color = const Color(0xFFF6465D).withValues(alpha: 0.055);
    canvas.drawRect(
      Rect.fromLTWH(padL, padT, plotW, math.max(0, y0 - padT)),
      green,
    );
    canvas.drawRect(
      Rect.fromLTWH(padL, y0, plotW, math.max(0, padT + plotH - y0)),
      red,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.55)
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
          color: AppTheme.muted,
          size: 9,
          align: TextAlign.center,
          width: 36,
        );
      }
    }

    // Горизонтальные уровни с ценой справа (как на бирже).
    for (
      var k = (minV / step - 1e-9).ceil();
      k <= (maxV / step + 1e-9).floor();
      k++
    ) {
      final v = k * step;
      final y = yOf(v);
      final zero = k == 0;
      final line = Paint()
        ..color = zero
            ? AppTheme.muted.withValues(alpha: 0.65)
            : AppTheme.border.withValues(alpha: 0.45)
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
            ? AppTheme.text
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
        Paint()
          ..color = color
          ..strokeWidth = 1.2,
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
      ..color = AppTheme.muted.withValues(alpha: 0.7)
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

  void _drawCandleMarker(Canvas canvas, int idx) {
    final b = bars[idx];
    final x = padL + (idx + 0.5) * cell;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 18, padT + plotH + 3, 36, 16),
        const Radius.circular(3),
      ),
      Paint()..color = AppTheme.primary,
    );
    _text(
      canvas,
      b.label,
      Offset(x - 18, padT + plotH + 5),
      color: Colors.white,
      size: 9,
      align: TextAlign.center,
      width: 36,
    );
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    final d = (b - a).distance;
    if (d == 0) return;
    final dir = (b - a) / d;
    for (var x = 0.0; x < d; x += dash * 2) {
      canvas.drawLine(a + dir * x, a + dir * math.min(x + dash, d), paint);
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
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
      old.cursor != cursor ||
      old.pinnedCandle != pinnedCandle;
}

/// Подробная сводка по свече: O/H/L/C, изменение, доход/расход и операции дня.
class _CandleSummary extends StatelessWidget {
  final Bar bar;
  const _CandleSummary({required this.bar});

  @override
  Widget build(BuildContext context) {
    final change = bar.close - bar.open;
    final pct = bar.open != 0 ? change / bar.open.abs() * 100 : 0.0;
    final color = change >= 0 ? AppTheme.success : AppTheme.danger;
    String val(double v) => fmtMoney(v);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Свеча ${bar.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${change >= 0 ? '+' : '−'}${val(change.abs())} ₽ '
                '(${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cell('Открыто', val(bar.open)),
              _cell('Закрыто', val(bar.close)),
              _cell('Максимум', val(bar.high)),
              _cell('Минимум', val(bar.low)),
            ],
          ),
          if (bar.income > 0 || bar.expense > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Доход ${val(bar.income)} ₽ · влияние −${val(bar.expense)} ₽ · диапазон ${val(bar.high - bar.low)} ₽',
              style: TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          ],
          if (bar.ops.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bar.ops.length,
                itemBuilder: (context, i) {
                  final op = bar.ops[i];
                  final parts = op.split(': ');
                  final positive = op.contains('+');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            parts.first,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        Text(
                          parts.length > 1 ? parts.sublist(1).join(': ') : '',
                          style: TextStyle(
                            fontSize: 10,
                            color: positive
                                ? AppTheme.success
                                : AppTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.muted)),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

double _niceStep(double raw) {
  if (raw <= 0 || !raw.isFinite) return 1;
  final exp = math.log(raw) / math.ln10;
  final p = math.pow(10, exp.floor()).toDouble();
  final f = raw / p;
  final nice = f <= 1
      ? 1.0
      : f <= 2
      ? 2.0
      : f <= 2.5
      ? 2.5
      : f <= 5
      ? 5.0
      : 10.0;
  return nice * p;
}
