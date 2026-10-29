import 'dart:math';
import 'package:flutter/material.dart';

class DonutSlice {
  final String label;
  final double value;
  final Color color;
  DonutSlice({required this.label, required this.value, required this.color});
}

/// Simple donut chart drawn with CustomPainter — no extra chart
/// package dependency required.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 160});

  final List<DonutSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(slices: slices, total: total),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.total});
  final List<DonutSlice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) {
      final paint = Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18;
      canvas.drawCircle(
          size.center(Offset.zero), size.width / 2 - paint.strokeWidth / 2, paint);
      return;
    }
    final strokeWidth = size.width * 0.18;
    final rect = Offset.zero & size;
    final adjustedRect = Rect.fromCircle(
      center: rect.center,
      radius: size.width / 2 - strokeWidth / 2,
    );
    double startAngle = -pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * 2 * pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(adjustedRect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}
