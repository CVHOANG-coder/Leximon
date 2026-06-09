import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Fills the entire world height with a tiled sea background and animated
/// wave-shimmer bands.
class SeaBackgroundComponent extends Component {
  SeaBackgroundComponent({required this.worldSize});

  final Vector2 worldSize;
  Sprite? _bgSprite;
  double _time = 0;

  @override
  Future<void> onLoad() async {
    _bgSprite = await Sprite.load('homeScreen/background_sea.png');
  }

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    // Deep ocean gradient as fallback
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF0D4F7C), Color(0xFF2A88C8)],
    ).createShader(Rect.fromLTWH(0, 0, worldSize.x, worldSize.y));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, worldSize.x, worldSize.y),
      Paint()..shader = gradient,
    );

    // Tile background_sea.png vertically
    final sp = _bgSprite;
    if (sp != null && sp.srcSize.x > 0) {
      final tileH = worldSize.x * sp.srcSize.y / sp.srcSize.x;
      var y = 0.0;
      while (y < worldSize.y) {
        sp.render(canvas,
            position: Vector2(0, y), size: Vector2(worldSize.x, tileH));
        y += tileH;
      }
    }

    // Animated wave shimmer
    for (var i = 0; i < 14; i++) {
      final baseY = i * worldSize.y / 14;
      final waveY = baseY + math.sin(_time * 0.35 + i * 0.8) * 7;
      final alpha =
          (0.025 + 0.018 * math.sin(_time * 0.7 + i * 1.3)).clamp(0.0, 0.06);
      canvas.drawRect(
        Rect.fromLTWH(0, waveY, worldSize.x, 18),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }
}
