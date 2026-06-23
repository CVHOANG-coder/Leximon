import 'dart:math' as math;

import 'package:flame/components.dart';

/// A drifting cloud that creates fog-of-war over unreachable islands.
class FogCloudComponent extends SpriteComponent {
  FogCloudComponent({
    required Vector2 position,
    required String assetName,
    required this.driftSpeed,
    required this.worldWidth,
    required this.bobPhase,
    super.priority,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(220, 110),
        ) {
    _assetName = assetName;
  }

  late final String _assetName;
  final double driftSpeed; // px/s, can be negative
  final double worldWidth;
  final double bobPhase;
  double _t = 0;
  late Vector2 _basePos;

  /// Khi đảo được mở khóa, mây tan ra 2 bên (do effect điều khiển vị trí).
  /// Lúc này ngừng tự dao động để effect không bị ghi đè.
  bool dispersing = false;

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('homeScreen/clouds/$_assetName');
    } catch (_) {}
    opacity = 0.88;
    _basePos = position.clone();
  }

  @override
  void update(double dt) {
    if (dispersing) return; // effect đang điều khiển vị trí khi tan mây
    _t += dt;
    position.x = _basePos.x + math.sin(_t * 0.25 + bobPhase) * 18;
    position.y = _basePos.y + math.sin(_t * 0.18 + bobPhase * 1.3) * 6;
  }
}
