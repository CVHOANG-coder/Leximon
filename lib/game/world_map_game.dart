import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color;

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
    int currentIslandIndex = 1,
    this.onIslandSelected,
    this.onIslandTapped,
  })  : _islands = islands ?? IslandData.defaults,
        _currentIdx = currentIslandIndex;

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
        await _world.add(FogCloudComponent(
          position: center + Vector2(xOff, yOff),
          assetName: cloudFiles[rng.nextInt(cloudFiles.length)],
          driftSpeed: (rng.nextDouble() * 10 - 5),
          worldWidth: size.x,
          bobPhase: rng.nextDouble() * math.pi * 2,
          priority: 40,
        ));
      }
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

    // Tap vào đảo hiện tại → navigate ngay
    if (idx == _currentIdx) {
      onIslandTapped?.call(target);
      return;
    }

    // Only allow traveling to directly adjacent (next) island if locked
    // or to any unlocked island
    final isAdjacent = idx == _currentIdx + 1;
    if (!target.unlocked && !isAdjacent) return;

    // Build path from current island to target (can be multiple hops)
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
    onIslandSelected?.call(target);

    // Scroll toward destination while boat travels
    _scrollTo(idx);

    _boat.travelAlong(pathPoints, onArrived: () {
      _updateCurrentIsland(idx);
      _boatMoving = false;
    });
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
