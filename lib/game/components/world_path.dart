import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Draws a winding bezier path connecting island waypoints.
/// Segments up to [unlockedCount] are rendered in gold; the rest in faded white.
class WorldPathComponent extends Component {
  WorldPathComponent({
    required this.waypoints,
    required this.unlockedCount,
  }) : super(priority: 10);

  final List<Vector2> waypoints;
  final int unlockedCount;

  static const double _dashLen = 14;
  static const double _gapLen = 8;

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < waypoints.length - 1; i++) {
      _drawSegment(canvas, waypoints[i], waypoints[i + 1], i < unlockedCount);
    }
  }

  void _drawSegment(Canvas canvas, Vector2 from, Vector2 to, bool unlocked) {
    final midY = (from.y + to.y) / 2;
    final path = Path()
      ..moveTo(from.x, from.y)
      ..cubicTo(from.x, midY, to.x, midY, to.x, to.y);

    // Shadow / outline
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unlocked ? 10 : 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (unlocked) {
      // Solid gold path
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFD84D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // White inner highlight
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Dashed grey path for locked segments
      _drawDashed(canvas, from, to, midY);
    }
  }

  /// Sample points along the cubic bezier and draw dashes manually.
  void _drawDashed(Canvas canvas, Vector2 p0, Vector2 p3, double midY) {
    final p1 = Vector2(p0.x, midY);
    final p2 = Vector2(p3.x, midY);

    const steps = 80;
    final pts = List.generate(steps + 1, (s) {
      final t = s / steps;
      final u = 1 - t;
      return Vector2(
        u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
        u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y,
      );
    });

    // Compute cumulative arc lengths
    final lengths = <double>[0];
    for (var i = 1; i <= steps; i++) {
      lengths.add(lengths.last + (pts[i] - pts[i - 1]).length);
    }
    final total = lengths.last;

    final paint = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    var dist = 0.0;
    var drawing = true;

    while (dist < total) {
      final segEnd = math.min(dist + (drawing ? _dashLen : _gapLen), total);
      if (drawing) {
        final a = _sampleAt(pts, lengths, dist);
        final b = _sampleAt(pts, lengths, segEnd);
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
      }
      dist = segEnd;
      drawing = !drawing;
    }
  }

  Vector2 _sampleAt(List<Vector2> pts, List<double> lengths, double d) {
    for (var i = 1; i < lengths.length; i++) {
      if (lengths[i] >= d) {
        final t = (d - lengths[i - 1]) / (lengths[i] - lengths[i - 1]);
        return pts[i - 1] + (pts[i] - pts[i - 1]) * t;
      }
    }
    return pts.last;
  }

  /// Returns [steps] sample points along the bezier between [p0] and [p3].
  static List<Vector2> samplePath(Vector2 p0, Vector2 p3, int steps) {
    final midY = (p0.y + p3.y) / 2;
    final p1 = Vector2(p0.x, midY);
    final p2 = Vector2(p3.x, midY);
    return List.generate(steps + 1, (s) {
      final t = s / steps;
      final u = 1 - t;
      return Vector2(
        u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
        u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y,
      );
    });
  }
}
