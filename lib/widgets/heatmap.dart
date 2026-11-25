import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/ui.dart';

/// Элемент тепловой карты: размер = последняя трата, цвет = изменение к прошлой.
class HeatItem {
  final String name;
  final double amount;
  final double? pct;
  final double? prev;

  const HeatItem(this.name, this.amount, this.pct, this.prev);
}

class _Placed {
  final HeatItem item;
  final Rect rect;
  const _Placed(this.item, this.rect);
}

/// Классическая тепловая карта (treemap, squarify): площадь прямоугольника
/// пропорциональна сумме, а не только ширина, как в старых «чипах».
class Heatmap extends StatelessWidget {
  final List<HeatItem> items;

  const Heatmap({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (items.length * 58).clamp(180, 320).toDouble();
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final placed = _squarify(items, Size(width, height), 4);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (final p in placed)
                Positioned(
                  left: p.rect.left,
                  top: p.rect.top,
                  width: p.rect.width,
                  height: p.rect.height,
                  child: _Tile(item: p.item),
                ),
            ],
          ),
        );
      },
    );
  }
}

List<_Placed> _squarify(List<HeatItem> items, Size size, double gap) {
  final valid = items.where((x) => x.amount > 0.004).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  if (valid.isEmpty || size.width <= 0 || size.height <= 0) return const [];

  final total = valid.fold<double>(0, (sum, x) => sum + x.amount);
  final areas = [for (final x in valid) size.width * size.height * x.amount / total];
  final left = List<int>.generate(valid.length, (i) => i);
  var x = 0.0;
  var y = 0.0;
  var w = size.width;
  var h = size.height;
  final out = <_Placed>[];

  double worst(List<int> row, double short) {
    if (row.isEmpty || short <= 0) return double.infinity;
    var minA = double.infinity;
    var maxA = 0.0;
    var sum = 0.0;
    for (final i in row) {
      minA = math.min(minA, areas[i]);
      maxA = math.max(maxA, areas[i]);
      sum += areas[i];
    }
    if (minA <= 0 || sum <= 0) return double.infinity;
    final s2 = short * short;
    return math.max(s2 * maxA / (sum * sum), sum * sum / (s2 * minA));
  }

  while (left.isNotEmpty && w > 0.5 && h > 0.5) {
    final short = math.min(w, h);
    final row = <int>[left.first];
    left.removeAt(0);
    while (left.isNotEmpty) {
      final before = worst(row, short);
      final after = worst([...row, left.first], short);
      if (after > before) break;
      row.add(left.first);
      left.removeAt(0);
    }

    final sum = row.fold<double>(0, (s, i) => s + areas[i]);
    final thickness = sum / short;
    if (w >= h) {
      // Вертикальная полоса слева.
      var yy = y;
      for (final i in row) {
        final hh = areas[i] / (thickness > 0 ? thickness : 1);
        out.add(_Placed(valid[i], Rect.fromLTWH(x, yy, thickness, hh)));
        yy += hh;
      }
      x += thickness;
      w -= thickness;
    } else {
      // Горизонтальная полоса сверху.
      var xx = x;
      for (final i in row) {
        final ww = areas[i] / (thickness > 0 ? thickness : 1);
        out.add(_Placed(valid[i], Rect.fromLTWH(xx, y, ww, thickness)));
        xx += ww;
      }
      y += thickness;
      h -= thickness;
    }
  }

  return out.map((p) {
    final r = p.rect.deflate(gap / 2);
    return _Placed(
      p.item,
      r.width > 0 && r.height > 0
          ? r
          : Rect.fromLTWH(p.rect.left, p.rect.top, 1, 1),
    );
  }).toList();
}

class _Tile extends StatelessWidget {
  final HeatItem item;
  const _Tile({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = item.pct;
    Color color;
    if (pct == null) {
      color = const Color(0xFF475569).withValues(alpha: .85);
    } else if (pct.abs() <= 0.05) {
      color = const Color(0xFF64748B).withValues(alpha: .75);
    } else {
      final m = math.min(pct.abs(), 40) / 40;
      final c = pct > 0 ? const Color(0xFFF6465D) : const Color(0xFF0ECB81);
      color = c.withValues(alpha: 0.35 + 0.55 * m);
    }
    final tiny = item.prev != null
        ? '${fmtMoney(item.amount)} ₽ ← ${fmtMoney(item.prev!)} ₽'
        : '${fmtMoney(item.amount)} ₽';
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        Widget child;
        if (w < 44 || h < 40) {
          child = const SizedBox.expand();
        } else {
          final showAll = w >= 70 && h >= 54;
          child = Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (showAll) ...[
                  const SizedBox(height: 2),
                  Text(
                    pct == null
                        ? '—'
                        : '${pct >= 0 ? '↑' : '↓'} ${pct.abs().toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  if (h >= 72) ...[
                    const SizedBox(height: 2),
                    Text(
                      tiny,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ],
              ],
            ),
          );
        }
        return Tooltip(
          message: '${item.name}\n$tiny${pct == null ? '' : ' · ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%'}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(color: color, child: child),
          ),
        );
      },
    );
  }
}
