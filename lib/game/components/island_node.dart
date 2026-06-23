import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import 'island_data.dart';

/// An island sprite on the world map with bobbing animation, lock overlay,
/// and a play-button indicator for the current island.
class IslandNodeComponent extends SpriteComponent {
  IslandNodeComponent({
    required this.data,
    required Vector2 position,
    required this.isCurrent,
    this.onTap,
    super.priority,
  }) : super(position: position, anchor: Anchor.center);

  /// Có thể đổi (vd: khi mở khóa) để đảo sáng lên thay vì bị làm mờ.
  IslandData data;
  bool isCurrent;
  final void Function(IslandData data)? onTap;

  late Vector2 _basePos;
  double _bobTime = 0;

  static const _nodeSize = 240.0;

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('homeScreen/islands/${data.assetName}');
    } catch (_) {
      // Fallback: invisible (no sprite) — won't crash
    }
    size = Vector2(_nodeSize, _nodeSize * 0.85);
    _basePos = position.clone();

    // Island name label — animated, anchored below the island sprite.
    // Child coordinates are relative to the parent's top-left corner.
    await add(
      _IslandLabel(
        text: data.name,
        // Sprite has transparent padding at the bottom, so pull the label
        // up above size.y to sit close to the visible island edge.
        labelPosition: Vector2(size.x / 2, size.y - 24),
        isCurrent: isCurrent,
      ),
    );
  }

  @override
  void update(double dt) {
    _bobTime += dt;
    position.y = _basePos.y + math.sin(_bobTime * 1.4) * 5;
  }

  @override
  void render(Canvas canvas) {
    final hh = size.y / 2;

    // Locked island: dim the sprite
    if (!data.unlocked) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    super.render(canvas);

    if (!data.unlocked) canvas.restore();

    // Play button below current island
    if (isCurrent) {
      _drawPlayButton(canvas, Offset(size.x / 2, hh + 24));
    }

    // Green checkmark for completed past islands
    if (data.completed && !isCurrent) {
      _drawCheckmark(canvas, Offset(size.x / 2, hh + 8));
    }
  }

  void _drawPlayButton(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 22, Paint()..color = const Color(0xFF3CB54A));
    canvas.drawCircle(
      center,
      22,
      Paint()
        ..color = const Color(0xFF2A8A37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final tri = Path()
      ..moveTo(center.dx - 7, center.dy - 10)
      ..lineTo(center.dx - 7, center.dy + 10)
      ..lineTo(center.dx + 12, center.dy)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.white);
  }

  void _drawCheckmark(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 16, Paint()..color = const Color(0xFF3CB54A));
    final path = Path()
      ..moveTo(center.dx - 7, center.dy)
      ..lineTo(center.dx - 1, center.dy + 6)
      ..lineTo(center.dx + 8, center.dy - 6);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  bool containsWorldPoint(Vector2 point) =>
      (point - position).length < (_nodeSize * 0.55);
}

class _IslandLabel extends TextComponent {
  _IslandLabel({
    required String text,
    required Vector2 labelPosition,
    required this.isCurrent,
  }) : super(
         text: text,
         anchor: Anchor.topCenter,
         position: labelPosition,
         textRenderer: TextPaint(
           style: TextStyle(
             color: Colors.white,
             fontSize: isCurrent ? 15 : 13,
             fontWeight: FontWeight.w800,
             letterSpacing: 0.5,
             shadows: const [
               Shadow(
                 color: Color(0xCC000000),
                 blurRadius: 8,
                 offset: Offset(0, 2),
               ),
               Shadow(color: Color(0x88000000), blurRadius: 16),
             ],
           ),
         ),
       );

  final bool isCurrent;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (isCurrent) {
      final alpha = (0.75 + 0.25 * math.sin(_t * 2.5)).clamp(0.0, 1.0);
      textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
            Shadow(color: Color(0x88000000), blurRadius: 16),
          ],
        ),
      );
    }
  }
}
