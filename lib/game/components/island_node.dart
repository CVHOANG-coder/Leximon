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

  final IslandData data;
  bool isCurrent;
  final void Function(IslandData data)? onTap;

  late Vector2 _basePos;
  double _bobTime = 0;
  Sprite? _lockSprite;

  static const _nodeSize = 180.0;

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('homeScreen/islands/${data.assetName}');
    } catch (_) {
      // Fallback: invisible (no sprite) — won't crash
    }
    size = Vector2(_nodeSize, _nodeSize * 0.85);
    _basePos = position.clone();

    if (!data.unlocked) {
      try {
        _lockSprite = await Sprite.load('homeScreen/lock_chain.png');
      } catch (_) {}
    }

    // Island name label
    await add(
      TextComponent(
        text: data.name,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        anchor: Anchor.topCenter,
        position: Vector2(0, size.y / 2 + (isCurrent ? 48 : 8)),
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

    // Lock icon: centered horizontally, top-center of island
    if (!data.unlocked) {
      const lockW = 52.0;
      const lockH = 62.0;
      _lockSprite?.render(
        canvas,
        position: Vector2(-lockW / 2, -hh - lockH + 14),
        size: Vector2(lockW, lockH),
      );
    }

    // Play button below current island
    if (isCurrent) {
      _drawPlayButton(canvas, Offset(0, hh + 24));
    }

    // Green checkmark for completed past islands
    if (data.completed && !isCurrent) {
      _drawCheckmark(canvas, Offset(0, hh + 8));
    }
  }

  void _drawPlayButton(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      22,
      Paint()..color = const Color(0xFF3CB54A),
    );
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
