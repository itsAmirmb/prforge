import 'package:flutter/material.dart';

/// Minimal line chart: one value per point, evenly spaced, with the min and
/// max labelled. Points whose value is null are skipped.
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.values, this.height = 160});

  final List<double?> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall!;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          values: values,
          line: scheme.primary,
          grid: scheme.outlineVariant,
          label: style.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.line,
    required this.grid,
    required this.label,
  });

  final List<double?> values;
  final Color line;
  final Color grid;
  final TextStyle label;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  void paint(Canvas canvas, Size size) {
    final present = [for (final v in values) if (v != null) v];
    if (present.isEmpty) return;

    const left = 44.0, top = 8.0, bottom = 8.0, right = 8.0;
    final plot = Rect.fromLTRB(
        left, top, size.width - right, size.height - bottom);

    var minV = present.reduce((a, b) => a < b ? a : b);
    var maxV = present.reduce((a, b) => a > b ? a : b);
    if (minV == maxV) {
      // Flat data: give the axis some room so the line sits in the middle.
      minV -= 1;
      maxV += 1;
    }

    double x(int i) => values.length == 1
        ? plot.center.dx
        : plot.left + plot.width * i / (values.length - 1);
    double y(double v) =>
        plot.bottom - plot.height * (v - minV) / (maxV - minV);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(plot.topLeft, plot.topRight, gridPaint);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, gridPaint);

    void text(String s, double dy) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: label),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      tp.paint(canvas, Offset(left - 6 - tp.width, dy - tp.height / 2));
    }

    text(_fmt(maxV), plot.top);
    text(_fmt(minV), plot.bottom);

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = Offset(x(i), y(v));
      if (started) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        started = true;
      }
    }
    canvas.drawPath(path, linePaint);

    final dot = Paint()..color = line;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) canvas.drawCircle(Offset(x(i), y(v)), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values || old.line != line;
}
