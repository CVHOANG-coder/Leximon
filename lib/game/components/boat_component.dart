import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

/// The player's boat that sits on the current island and animates along the
/// bezier path when the player selects a destination island.
class BoatComponent extends SpriteComponent {
  BoatComponent({required Vector2 position})
      : super(position: position, anchor: Anchor.center, size: Vector2(60, 54), priority: 30);

  // Bobbing
  late Vector2 _basePos;
  double _bobTime = 0;

  // Travel
  List<Vector2>? _pathPoints;
  int _pathIndex = 0;
  VoidCallback? _onArrived;

  static const double _speed = 220.0;

  bool get isMoving => _pathPoints != null;

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('homeScreen/boat.png');
    } catch (_) {}
    _basePos = position.clone();
  }

  /// Begin animating the boat through [points] (world coordinates).
  /// [onArrived] is called when the last point is reached.
  void travelAlong(List<Vector2> points, {VoidCallback? onArrived}) {
    _pathPoints = List.of(points);
    _pathIndex = 0;
    _onArrived = onArrived;
  }

  void snapTo(Vector2 pos) {
    _pathPoints = null;
    position.setFrom(pos);
    _basePos = pos.clone();
  }

  @override
  void update(double dt) {
    if (_pathPoints != null) {
      _stepAlongPath(dt);
    } else {
      _bobTime += dt;
      position.y = _basePos.y + math.sin(_bobTime * 2.0) * 3.5;
    }
  }

  void _stepAlongPath(double dt) {
    final pts = _pathPoints!;
    if (_pathIndex >= pts.length) {
      _pathPoints = null;
      _basePos = position.clone();
      _bobTime = 0;
      _onArrived?.call();
      return;
    }

    final target = pts[_pathIndex];
    final delta = target - position;
    final dist = delta.length;
    final step = _speed * dt;

    // Flip sprite to face direction of travel
    if (delta.x.abs() > 2) scale.x = delta.x > 0 ? 1 : -1;

    if (dist <= step) {
      position.setFrom(target);
      _pathIndex++;
    } else {
      position += delta.normalized() * step;
    }
  }
}
