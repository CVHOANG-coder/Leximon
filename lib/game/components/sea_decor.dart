import 'dart:math' as math;

import 'package:flame/components.dart';

/// Scatters sea decorations (shark, coral, whirlpool, water current) randomly
/// across the world to avoid an empty ocean.
class SeaDecorManager extends Component {
  SeaDecorManager({
    required this.worldSize,
    required this.random,
    this.islandPositions = const [],
    this.islandClearRadius = 120.0,
  }) : super(priority: 5);

  final Vector2 worldSize;
  final math.Random random;
  final List<Vector2> islandPositions;
  final double islandClearRadius;

  bool _isClear(double x, double y) {
    for (final pos in islandPositions) {
      final dx = x - pos.x;
      final dy = y - pos.y;
      if (dx * dx + dy * dy < islandClearRadius * islandClearRadius) return false;
    }
    return true;
  }

  Vector2 _randomPos(double marginX, double minY, double maxY, {int maxTries = 20}) {
    for (var t = 0; t < maxTries; t++) {
      final x = marginX + random.nextDouble() * (worldSize.x - marginX * 2);
      final y = minY + random.nextDouble() * (maxY - minY);
      if (_isClear(x, y)) return Vector2(x, y);
    }
    // fallback: return a position even if not clear
    return Vector2(
      marginX + random.nextDouble() * (worldSize.x - marginX * 2),
      minY + random.nextDouble() * (maxY - minY),
    );
  }

  @override
  Future<void> onLoad() async {
    await _addStaticDecors();
    await _addSharkAnimation();
  }

  Future<void> _addStaticDecors() async {
    final assets = [
      ('homeScreen/decor_item/whirlpool.png', 70.0, 70.0),
      ('homeScreen/decor_item/water_current.png', 90.0, 40.0),
      ('homeScreen/decor_item/kraken.png', 80.0, 80.0),
    ];

    for (final (path, w, h) in assets) {
      final count = 2 + random.nextInt(2);
      for (var i = 0; i < count; i++) {
        final pos = _randomPos(20, 200, worldSize.y - 200);
        try {
          final sprite = await Sprite.load(path);
          await add(_BobDecor(
            sprite: sprite,
            position: pos,
            size: Vector2(w, h),
            bobAmplitude: 4 + random.nextDouble() * 4,
            bobFrequency: 0.6 + random.nextDouble() * 0.6,
            bobPhase: random.nextDouble() * math.pi * 2,
          ));
        } catch (_) {
          // asset missing — skip silently
        }
      }
    }

    // Shark fin: moves diagonally right-to-left and top-to-bottom
    try {
      final finSprite = await Sprite.load('homeScreen/decor_item/shark_fin.png');
      final count = 2 + random.nextInt(2);
      for (var i = 0; i < count; i++) {
        final pos = _randomPos(20, 200, worldSize.y - 200);
        await add(_FinSwimmer(
          sprite: finSprite,
          startPosition: pos,
          worldSize: worldSize,
          speedX: 20 + random.nextDouble() * 15,
          speedY: 8 + random.nextDouble() * 6,
        ));
      }
    } catch (_) {}
  }

  Future<void> _addSharkAnimation() async {
    final forward = <Sprite>[];
    for (var i = 2; i <= 6; i++) {
      try {
        forward.add(
            await Sprite.load('homeScreen/decor_item/shark_shadow/shark_shadow$i.png'));
      } catch (_) {}
    }
    if (forward.isEmpty) return;

    // ping-pong: 3→4→5→4→3→4→...
    final pingPong = [...forward, ...forward.reversed.skip(1).take(forward.length - 1)];
    final anim = SpriteAnimation.spriteList(pingPong, stepTime: 0.12);
    final count = 2 + random.nextInt(2);
    for (var i = 0; i < count; i++) {
      final pos = _randomPos(20, 300, worldSize.y - 300);
      await add(_SharkSwimmer(
        animation: anim,
        startPosition: pos,
        worldWidth: worldSize.x,
        speed: 25 + random.nextDouble() * 20,
        direction: random.nextBool() ? 1 : -1,
      ));
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _BobDecor extends SpriteComponent {
  _BobDecor({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.bobAmplitude,
    required this.bobFrequency,
    required this.bobPhase,
    this.rotationSpeed = 0,
  }) : super(sprite: sprite, position: position, size: size, anchor: Anchor.center) {
    _base = position.clone();
  }

  final double bobAmplitude;
  final double bobFrequency;
  final double bobPhase;
  final double rotationSpeed;
  late Vector2 _base;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    position.y = _base.y + math.sin(_t * bobFrequency + bobPhase) * bobAmplitude;
    if (rotationSpeed != 0) angle += rotationSpeed * dt;
  }
}

class _FinSwimmer extends SpriteComponent {
  _FinSwimmer({
    required Sprite sprite,
    required Vector2 startPosition,
    required this.worldSize,
    required this.speedX,
    required this.speedY,
  }) : super(sprite: sprite, position: startPosition, size: Vector2(50, 40), anchor: Anchor.center);

  final Vector2 worldSize;
  final double speedX;
  final double speedY;

  @override
  void update(double dt) {
    position.x -= speedX * dt;
    position.y += speedY * dt;

    // Wrap: when off left/bottom edge, reset to right side near top
    if (position.x < -60 || position.y > worldSize.y + 40) {
      position.x = worldSize.x + 60;
      position.y = 200 + (position.y % (worldSize.y * 0.3));
    }
  }
}

class _SharkSwimmer extends SpriteAnimationComponent {
  _SharkSwimmer({
    required SpriteAnimation animation,
    required Vector2 startPosition,
    required this.worldWidth,
    required this.speed,
    required this.direction,
  }) : super(
          animation: animation,
          position: startPosition,
          size: Vector2(100, 60),
          anchor: Anchor.center,
        ) {
    if (direction < 0) scale = Vector2(-1, 1);
    _baseY = startPosition.y;
  }

  final double worldWidth;
  final double speed;
  final double direction;
  late double _baseY;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.x += speed * direction * dt;
    position.y = _baseY + math.sin(_t * 0.4) * 8;

    // Wrap around world width
    if (direction > 0 && position.x > worldWidth + 60) position.x = -60;
    if (direction < 0 && position.x < -60) position.x = worldWidth + 60;
  }
}
