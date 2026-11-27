import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/balance_chart.dart';

/// Полноэкранный график: тот же BalanceChart, но на всю высоту экрана.
/// Возвращает масштаб и сдвиг, чтобы исходный экран остался в том же окне.
class ChartFullscreenScreen extends StatefulWidget {
  final AppController controller;
  final List<Bar> bars;
  final bool candle;
  final bool ma;
  final bool showVolume;
  final double zoom;
  final double rightOffset;

  const ChartFullscreenScreen({
    super.key,
    required this.controller,
    required this.bars,
    required this.candle,
    required this.ma,
    required this.showVolume,
    required this.zoom,
    required this.rightOffset,
  });

  @override
  State<ChartFullscreenScreen> createState() => _ChartFullscreenScreenState();
}

class _ChartFullscreenScreenState extends State<ChartFullscreenScreen> {
  final _chartKey = GlobalKey<BalanceChartState>();
  late double _zoom = widget.zoom;

  void _close() {
    Navigator.of(context).pop({
      'zoom': _chartKey.currentState?.currentZoom ?? _zoom,
      'rightOffset': _chartKey.currentState?.rightOffset ?? 0.0,
    });
  }

  Widget _control(String label, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(38, 34),
        padding: EdgeInsets.zero,
        side: BorderSide(color: AppTheme.border),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hideBal = widget.controller.state.hideBal;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('График'),
        backgroundColor: AppTheme.card,
        foregroundColor: AppTheme.text,
        actions: [
          IconButton(
            tooltip: 'Закрыть',
            onPressed: _close,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return BalanceChart(
                    key: _chartKey,
                    bars: widget.bars,
                    candle: widget.candle,
                    ma: widget.ma,
                    showVolume: widget.showVolume,
                    showSummary: true,
                    showFlow: true,
                    hideBal: hideBal,
                    zoom: widget.zoom,
                    initialRightOffset: widget.rightOffset,
                    height: constraints.maxHeight > 140
                        ? constraints.maxHeight - 110
                        : 140,
                    onZoomChanged: (v) => setState(() => _zoom = v),
                  );
                },
              ),
            ),
            Container(
              color: AppTheme.card,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _control('−', () => _chartKey.currentState?.zoomOut()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '×${_zoom.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _control('+', () => _chartKey.currentState?.zoomIn()),
                  const SizedBox(width: 8),
                  _control('↺', () => _chartKey.currentState?.resetZoom()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
