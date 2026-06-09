import 'dart:math' as math;

import 'package:flame/components.dart';

/// Scatters sea decorations (shark, coral, whirlpool, water current) randomly
/// across the world to avoid an empty ocean.
class SeaDecorManager extends Component {
  SeaDecorManager({required this.worldSize, required this.random})
      : super(priority: 5);

  final Vector2 worldSize;
  final math.Random random;

  @override
  Future<void> onLoad() async {
    await _addStaticDecors();
    await _addSharkAnimation();
  }

  Future<void> _addStaticDecors() async {
    final assets = [
      ('homeScreen/decor_item/shark_fin.png', 50.0, 40.0),
      ('homeScreen/decor_item/whirlpool.png', 70.0, 70.0),
      ('homeScreen/decor_item/water_current.png', 90.0, 40.0),
      ('homeScreen/decor_item/kraken.png', 80.0, 80.0),
    ];

    for (final (path, w, h) in assets) {
      final count = 2 + random.nextInt(2);
      for (var i = 0; i < count; i++) {
        final x = 20 + random.nextDouble() * (worldSize.x - 40);
        final y = 200 + random.nextDouble() * (worldSize.y - 400);
        try {
          final sprite = await Sprite.load(path);
          await add(_BobDecor(
            sprite: sprite,
            position: Vector2(x, y),
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
  }

  Future<void> _addSharkAnimation() async {
    final sprites = <Sprite>[];
    for (var i = 1; i <= 8; i++) {
      try {
        sprites.add(
            await Sprite.load('homeScreen/decor_item/shark_shadow/shark_shadow$i.png'));
      } catch (_) {}
    }
    if (sprites.isEmpty) return;

    final anim = SpriteAnimation.spriteList(sprites, stepTime: 0.12);
    final count = 2 + random.nextInt(2);
    for (var i = 0; i < count; i++) {
      final x = 20 + random.nextDouble() * (worldSize.x - 140);
      final y = 300 + random.nextDouble() * (worldSize.y - 600);
      await add(_SharkSwimmer(
        animation: anim,
        startPosition: Vector2(x, y),
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
  }) : super(sprite: sprite, position: position, size: size, anchor: Anchor.center) {
    _base = position.clone();
  }

  final double bobAmplitude;
  final double bobFrequency;
  final double bobPhase;
  late Vector2 _base;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    position.y = _base.y + math.sin(_t * bobFrequency + bobPhase) * bobAmplitude;
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
