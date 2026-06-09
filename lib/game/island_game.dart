import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Sample Flame game: an overworld island view with a wandering player.
/// Acts as the visual base for future exploration / encounter mechanics.
class IslandGame extends FlameGame with TapCallbacks {
  IslandGame({required this.islandId});

  final String islandId;

  late final PlayerComponent _player;

  @override
  Color backgroundColor() => AppColors.water;

  double get _shortestSide => math.min(size.x, size.y);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Island land mass (placeholder geometry until we wire Tiled maps).
    add(
      CircleComponent(
        radius: _shortestSide * 0.42,
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()..color = AppColors.sand,
      ),
    );
    add(
      CircleComponent(
        radius: _shortestSide * 0.36,
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()..color = AppColors.grass,
      ),
    );

    // Points of interest.
    for (var i = 0; i < 3; i++) {
      final angle = (i / 3) * math.pi * 2;
      final r = _shortestSide * 0.22;
      add(
        PoiComponent()
          ..position = size / 2 +
              Vector2(math.cos(angle) * r, math.sin(angle) * r),
      );
    }

    _player = PlayerComponent()..position = size / 2;
    add(_player);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _player.moveTo(event.localPosition);
  }
}

class PlayerComponent extends CircleComponent {
  PlayerComponent()
      : super(
          radius: 14,
          anchor: Anchor.center,
          paint: Paint()..color = AppColors.primary,
        );

  Vector2? _target;
  static const double _speed = 140;

  void moveTo(Vector2 target) => _target = target.clone();

  @override
  void update(double dt) {
    super.update(dt);
    final target = _target;
    if (target == null) return;
    final delta = target - position;
    final dist = delta.length;
    if (dist < 1) {
      _target = null;
      return;
    }
    position += delta.normalized() * math.min(_speed * dt, dist);
  }
}

class PoiComponent extends CircleComponent {
  PoiComponent()
      : super(
          radius: 10,
          anchor: Anchor.center,
          paint: Paint()..color = AppColors.accent,
        );
}
