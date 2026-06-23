import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, Curves;

import 'components/boat_component.dart';
import 'components/fog_cloud.dart';
import 'components/island_data.dart';
import 'components/island_node.dart';
import 'components/sea_background.dart';
import 'components/sea_decor.dart';
import 'components/world_path.dart';

/// World-map game: a vertically scrollable island map with a boat that
/// travels along winding bezier paths between islands.
class WorldMapGame extends FlameGame with DragCallbacks, TapCallbacks {
  WorldMapGame({
    List<IslandData>? islands,
    int? currentIslandIndex,
    this.onIslandSelected,
    this.onIslandTapped,
  })  : _islands = List<IslandData>.of(islands ?? IslandData.defaults),
        _currentIdx = currentIslandIndex ??
            _lastUnlockedIndex(islands ?? IslandData.defaults);

  /// Index of the most recently unlocked island (the furthest one the
  /// player can be on). Falls back to 0 if nothing is unlocked.
  static int _lastUnlockedIndex(List<IslandData> islands) {
    final idx = islands.lastIndexWhere((i) => i.unlocked);
    return idx < 0 ? 0 : idx;
  }

  final List<IslandData> _islands;
  int _currentIdx;

  /// Called when the player initiates travel to an island.
  final void Function(IslandData island)? onIslandSelected;

  /// Called immediately when any island is tapped (before travel).
  final void Function(IslandData island)? onIslandTapped;

  // ── Layout constants ──────────────────────────────────────────────────────
  static const double _islandSpacing = 430.0;
  static const double _worldPadding = 220.0;

  // X offsets for zigzag — creates S-winding path
  static const List<double> _xOffsets = [0, -70, 70, -70, 70, -70, 70, -70, 0, 0];

  // ── Internals ─────────────────────────────────────────────────────────────
  late final World _world;
  late final CameraComponent _camera;
  final List<IslandNodeComponent> _islandNodes = [];
  late BoatComponent _boat;
  late WorldPathComponent _pathComp;
  double _scrollOffset = 0;
  double _maxScroll = 0;
  bool _boatMoving = false;

  /// Ổ khóa và mây che phủ theo từng đảo bị khóa — giữ tham chiếu để chạy
  /// hiệu ứng mở khóa (rung → vỡ → biến mất; mây tan sang 2 bên).
  final Map<int, SpriteComponent> _lockByIsland = {};
  final Map<int, List<FogCloudComponent>> _cloudsByIsland = {};

  /// Các đảo đang chạy hiệu ứng mở khóa (chặn bấm lặp).
  final Set<int> _unlocking = {};

  // ── Coordinate helpers ────────────────────────────────────────────────────

  double get _worldHeight =>
      _islands.length * _islandSpacing + _worldPadding * 2;

  double _islandX(int i) =>
      size.x / 2 + _xOffsets[i.clamp(0, _xOffsets.length - 1)];

  /// Y increases downward; index 0 is near the bottom.
  double _islandY(int i) =>
      _worldHeight - _worldPadding - i * _islandSpacing;

  Vector2 _islandPos(int i) => Vector2(_islandX(i), _islandY(i));

  // ── Load ──────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    _world = World();
    _camera = CameraComponent(world: _world)
      ..viewfinder.anchor = Anchor.topLeft
      ..viewfinder.zoom = 1.0;
    addAll([_world, _camera]);

    _maxScroll = (_worldHeight - size.y).clamp(0, double.infinity);

    // priority 0 — sea background (bottom-most layer)
    await _world.add(SeaBackgroundComponent(worldSize: Vector2(size.x, _worldHeight)));

    // priority 5 — sea decorations (above bg, below path)
    await _world.add(SeaDecorManager(
      worldSize: Vector2(size.x, _worldHeight),
      random: math.Random(42),
      islandPositions: List.generate(_islands.length, _islandPos),
    ));

    // priority 10 — path (above bg & decor, below islands/boat)
    final waypoints = List.generate(_islands.length, _islandPos);
    _pathComp = WorldPathComponent(
      waypoints: waypoints,
      unlockedCount: _currentIdx,
    );
    await _world.add(_pathComp);

    // priority 20 — island nodes (above path)
    for (var i = 0; i < _islands.length; i++) {
      final node = IslandNodeComponent(
        data: _islands[i],
        position: _islandPos(i),
        isCurrent: i == _currentIdx,
        onTap: (_) => _onIslandTapped(i),
        priority: 20,
      );
      _islandNodes.add(node);
      await _world.add(node);
    }

    // priority 30 — boat (above islands)
    _boat = BoatComponent(position: _islandPos(_currentIdx) - Vector2(0, 90));
    await _world.add(_boat);

    // Fog clouds over islands far ahead of the player
    await _addFogClouds();

    // priority 50 — lock icons above clouds
    await _addLockIcons();

    // Scroll to current island
    _scrollTo(_currentIdx, animate: false);
  }

  Future<void> _addFogClouds() async {
    final cloudFiles = [
      'clouds_1.png', 'clouds_2.png', 'clouds_3.png',
      'clouds_4.png', 'clouds_5.png',
    ];
    final rng = math.Random(7);

    for (var i = 0; i < _islands.length; i++) {
      if (_islands[i].unlocked) continue; // chỉ đảo chưa mở mới có mây che

      final center = _islandPos(i);
      // 3 clouds per locked island — trải rộng để che phủ toàn bộ đảo
      for (var c = 0; c < 3; c++) {
        final xOff = (c - 1) * 75.0 + rng.nextDouble() * 20 - 10;
        final yOff = (c == 1 ? -30.0 : 0.0) + rng.nextDouble() * 10 - 5;
        // priority 40 — clouds above islands (fog of war on top)
        final cloud = FogCloudComponent(
          position: center + Vector2(xOff, yOff),
          assetName: cloudFiles[rng.nextInt(cloudFiles.length)],
          driftSpeed: (rng.nextDouble() * 10 - 5),
          worldWidth: size.x,
          bobPhase: rng.nextDouble() * math.pi * 2,
          priority: 40,
        );
        (_cloudsByIsland[i] ??= []).add(cloud);
        await _world.add(cloud);
      }
    }
  }

  Future<void> _addLockIcons() async {
    Sprite? lockSprite;
    try {
      lockSprite = await Sprite.load('homeScreen/lock_chain.png');
    } catch (_) {
      return;
    }
    for (var i = 0; i < _islands.length; i++) {
      if (_islands[i].unlocked) continue;
      final lock = SpriteComponent(
        sprite: lockSprite,
        position: _islandPos(i),
        size: Vector2(52, 62),
        anchor: Anchor.center,
        priority: 50,
      );
      _lockByIsland[i] = lock;
      await _world.add(lock);
    }
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollTo(int islandIdx, {bool animate = true}) {
    final targetY = (_islandY(islandIdx) - size.y / 2).clamp(0.0, _maxScroll);
    _scrollOffset = targetY;
    _camera.viewfinder.position = Vector2(0, _scrollOffset);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _scrollOffset =
        (_scrollOffset - event.localDelta.y).clamp(0, _maxScroll);
    _camera.viewfinder.position = Vector2(0, _scrollOffset);
  }

  // ── Tap ───────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (_boatMoving) return;

    // Convert screen → world coordinates
    final worldPos = Vector2(
      event.localPosition.x,
      event.localPosition.y + _scrollOffset,
    );

    for (var i = 0; i < _islandNodes.length; i++) {
      if (_islandNodes[i].containsWorldPoint(worldPos)) {
        _onIslandTapped(i);
        return;
      }
    }
  }

  void _onIslandTapped(int idx) {
    if (_boatMoving) return;

    final target = _islands[idx];

    // Đảo đã mở khóa → vào thẳng bên trong (bất kể có phải đảo thuyền đang
    // đậu hay không).
    if (target.unlocked) {
      onIslandTapped?.call(target);
      return;
    }

    // Đảo còn khóa: chỉ mở được lần lượt — đúng đảo kế tiếp ngay sau đảo cuối
    // đã mở khóa mới mở được; các đảo xa hơn vẫn khóa.
    if (idx != _lastUnlockedIndex(_islands) + 1) return;

    // Chạy hiệu ứng mở khóa (rung → vỡ → tan mây) rồi cho thuyền tới đảo đó.
    _unlockIsland(idx);
  }

  /// Cho thuyền đi từ đảo hiện tại đến [idx] theo đường (có thể nhiều chặng),
  /// cập nhật đảo hiện tại khi tới nơi.
  void _travelBoatTo(int idx) {
    if (idx == _currentIdx) {
      _boatMoving = false;
      return;
    }

    final step = idx > _currentIdx ? 1 : -1;
    final pathPoints = <Vector2>[];
    var from = _currentIdx;
    while (from != idx) {
      final to = from + step;
      final samples = WorldPathComponent.samplePath(
        _islandPos(from) - Vector2(0, 90),
        _islandPos(to) - Vector2(0, 90),
        18,
      );
      pathPoints.addAll(from == _currentIdx ? samples : samples.skip(1));
      from = to;
    }

    _boatMoving = true;
    onIslandSelected?.call(_islands[idx]);

    // Scroll toward destination while boat travels
    _scrollTo(idx);

    _boat.travelAlong(pathPoints, onArrived: () {
      _updateCurrentIsland(idx);
      _boatMoving = false;
    });
  }

  /// Hiệu ứng mở khóa một đảo:
  /// 1. Ổ khóa rung rung tại chỗ.
  /// 2. Đổi sang ảnh khóa vỡ (`unlock_chain.png`), bật nảy nhẹ.
  /// 3. Khóa mờ dần + rơi xuống rồi biến mất.
  /// 4. Mây che tan ra 2 bên (trái/phải tùy vị trí) và mờ dần.
  /// 5. Đảo sáng lên (hết bị làm mờ) và được đánh dấu đã mở khóa.
  /// 6. Thuyền di chuyển tới đảo vừa mở (đảo cuối đã mở khóa).
  Future<void> _unlockIsland(int idx) async {
    if (_unlocking.contains(idx)) return;
    _unlocking.add(idx);
    // Chặn mọi thao tác khác trong lúc mở khóa.
    _boatMoving = true;

    final lock = _lockByIsland.remove(idx);
    final clouds = _cloudsByIsland.remove(idx) ?? const <FogCloudComponent>[];
    final center = _islandPos(idx);

    // ── 1. Khóa rung rung ───────────────────────────────────────────────
    if (lock != null) {
      lock.add(RotateEffect.by(
        0.20,
        EffectController(duration: 0.05, alternate: true, repeatCount: 8),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 480));

      // ── 2. Đổi sang ảnh khóa vỡ + nảy nhẹ ─────────────────────────────
      try {
        lock.sprite = await Sprite.load('homeScreen/unlock_chain.png');
      } catch (_) {}
      lock.add(ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.12, alternate: true),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 240));

      // ── 3. Khóa mờ dần + rơi xuống rồi biến mất ───────────────────────
      lock
        ..add(OpacityEffect.fadeOut(EffectController(duration: 0.35)))
        ..add(MoveByEffect(
          Vector2(0, 24),
          EffectController(duration: 0.35, curve: Curves.easeIn),
        ))
        ..add(RemoveEffect(delay: 0.4));
    }

    // ── 4. Mây tan ra 2 bên + mờ dần ─────────────────────────────────────
    for (final cloud in clouds) {
      cloud.dispersing = true;
      final dir = cloud.position.x >= center.x ? 1.0 : -1.0;
      cloud
        ..add(MoveByEffect(
          Vector2(dir * 280, -20),
          EffectController(duration: 0.7, curve: Curves.easeOut),
        ))
        ..add(OpacityEffect.fadeOut(EffectController(duration: 0.7)))
        ..add(RemoveEffect(delay: 0.75));
    }

    // ── 5. Đảo sáng lên + đánh dấu đã mở khóa ────────────────────────────
    _islands[idx] = _islands[idx].copyWith(unlocked: true);
    _islandNodes[idx].data = _islands[idx];

    // Chờ mây tan bớt để lộ đảo, rồi cho thuyền tiến tới đảo vừa mở.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _unlocking.remove(idx);

    // ── 6. Thuyền di chuyển tới đảo mới ──────────────────────────────────
    // _travelBoatTo sẽ tự giữ/nhả _boatMoving cho tới khi thuyền cập bến.
    _travelBoatTo(idx);
  }

  void _updateCurrentIsland(int newIdx) {
    _islandNodes[_currentIdx].isCurrent = false;
    _currentIdx = newIdx;
    _islandNodes[_currentIdx].isCurrent = true;

    // Rebuild path coloring
    _world.remove(_pathComp);
    final waypoints = List.generate(_islands.length, _islandPos);
    _pathComp = WorldPathComponent(
      waypoints: waypoints,
      unlockedCount: _currentIdx,
    );
    _world.add(_pathComp);
  }

  @override
  Color backgroundColor() => const Color(0xFF1A6B9C);
}
