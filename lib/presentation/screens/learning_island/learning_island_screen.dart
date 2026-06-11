import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum CheckpointState { complete, current, uncheck }

class CheckpointModel {
  CheckpointModel({
    required this.id,
    required this.label,
    required this.topicId,
    required this.state,
  });

  final int id;
  final String label;

  /// Id of the vocabulary topic in lib/data/sample/topics.json.
  final int topicId;
  CheckpointState state;
}

class LearningIslandScreen extends StatefulWidget {
  const LearningIslandScreen({super.key});

  @override
  State<LearningIslandScreen> createState() => _LearningIslandScreenState();
}

class _LearningIslandScreenState extends State<LearningIslandScreen>
    with TickerProviderStateMixin {
  // Vocabulary topics of Learning Island, in play order:
  // (label, topic id in lib/data/sample/topics.json).
  static const List<(String, int)> _topics = [
    ('Đồ dùng học tập', 1),
    ('Trường học', 39),
    ('Học tập', 49),
    ('Giáo dục', 44),
    ('Máy tính', 14),
    ('Số', 5),
  ];

  final List<CheckpointModel> _checkpoints = List.generate(
    _topics.length,
    (i) => CheckpointModel(
      id: i,
      label: _topics[i].$1,
      topicId: _topics[i].$2,
      state: i == 0 ? CheckpointState.current : CheckpointState.uncheck,
    ),
  );

  AnimationController? _unlockCtrl;
  int? _unlockingIdx;

  late final AnimationController _frameCtrl;
  // Vào màn hình thì checkpoint current đứng yên ở frame cuối;
  // animation chỉ chạy khi mở khóa checkpoint mới (_onCheckpointTap).
  int _currentFrame = 4;

  late final AnimationController _bobCtrl;

  @override
  void initState() {
    super.initState();

    _frameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _frameCtrl.addListener(() {
      final frame = (_frameCtrl.value * 5).floor().clamp(0, 4);
      if (frame != _currentFrame) setState(() => _currentFrame = frame);
    });

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _frameCtrl.dispose();
    _bobCtrl.dispose();
    _unlockCtrl?.dispose();
    super.dispose();
  }

  Widget _bob({required Widget child, double phase = 0, double amplitude = 6}) {
    return AnimatedBuilder(
      animation: _bobCtrl,
      builder: (_, c) {
        final dy = math.sin((_bobCtrl.value * 2 * math.pi) + phase) * amplitude;
        return Transform.translate(offset: Offset(0, dy), child: c);
      },
      child: child,
    );
  }

  int get _currentIdx =>
      _checkpoints.indexWhere((c) => c.state == CheckpointState.current);

  void _onCheckpointTap(int tappedIdx) {
    // Checkpoint đã mở (đang học hoặc đã xong) → vào màn học từ vựng
    final tapped = _checkpoints[tappedIdx];
    if (tapped.state != CheckpointState.uncheck) {
      context.push('/lesson/${tapped.topicId}?islandId=learning');
      return;
    }

    final curIdx = _currentIdx;
    if (tappedIdx != curIdx + 1) return;
    if (_unlockCtrl != null && _unlockCtrl!.isAnimating) return;

    _unlockCtrl?.dispose();
    _unlockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _unlockingIdx = tappedIdx;
    // Flip current → complete ngay với hiệu ứng nảy.
    _checkpoints[curIdx].state = CheckpointState.complete;

    _unlockCtrl!.forward().then((_) {
      setState(() {
        _checkpoints[tappedIdx].state = CheckpointState.current;
        _unlockingIdx = null;
        _currentFrame = 0;
      });
      _frameCtrl.forward(from: 0);
    });
    setState(() {});
  }

  // Waypoints from island center, tracing the sandy walkway of the island
  // (dock at bottom → up-left past the magnifying glass → below the school
  // → right side → up along the right edge to the "123" corner).
  // Converted from learning_main_island.png pixel coords (1254×1254) using:
  // dx = xPx * 380/1254 - 190, dy = yPx * 380/1254 - 230 (image drawn at
  // width 380, offset cx-190 / cy-230).
  // The dashed path is drawn through ALL of these; checkpoints sit on a
  // subset of them (see _cpIndices) so they spread evenly along the walkway.
  static const List<Offset> _pathOffsets = [
    Offset(  18,   97), // Đồ dùng học tập — đầu lối đi, cạnh dock
    Offset( -12,   78),
    Offset( -36,   57), // Trường học — đoạn dốc lên bên trái
    Offset( -54,   36),
    Offset( -69,   21),
    Offset( -78,    8), // Học tập — khúc cua trái, cạnh kính lúp
    Offset( -60,   -5),
    Offset( -45,  -13),
    Offset( -30,  -19),
    Offset( -11,  -22),
    Offset(  10,  -26),
    Offset(  30,  -32),
    Offset(  50,  -43), // Giáo dục — bên phải, dưới bàn máy tính
    Offset(  45,  -70),
    Offset(  30,  -95),
    Offset(   5, -115),
    Offset( -13, -131), // Máy tính — khúc cua giữa, đỉnh chữ S
    Offset(  15, -128),
    Offset(  48, -122),
    Offset(  74, -112), // Số — vòng tròn cờ, góc "123"
  ];

  // Indices into _pathOffsets where the 6 checkpoints sit.
  static const List<int> _cpIndices = [0, 2, 5, 12, 16, 19];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final cx = w / 2;
          final cy = h * 0.54;

          final pathPositions =
              _pathOffsets.map((o) => Offset(cx + o.dx, cy + o.dy)).toList();
          final cpPositions = [for (final i in _cpIndices) pathPositions[i]];

          return Stack(
            fit: StackFit.expand,
            children: [
              // Sea background
              Image.asset(
                'assets/images/homeScreen/background_sea.png',
                fit: BoxFit.cover,
                width: w,
                height: h,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0D4F7C), Color(0xFF2A88C8)],
                    ),
                  ),
                ),
              ),

              // Main island
              Positioned(
                left: cx - 190,
                top: cy - 230,
                child: _bob(
                  amplitude: 5,
                  child: Image.asset(
                    'assets/images/learningIslandScreen/learning_main_island.png',
                    width: 380,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 380, height: 300),
                  ),
                ),
              ),

              // Dashed path along the island walkway, through all waypoints
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    positions: pathPositions,
                    checkpoints: List.unmodifiable(_checkpoints),
                    cpIndices: _cpIndices,
                  ),
                ),
              ),

              // Checkpoints — Positioned directly in this Stack
              for (var i = 0; i < _checkpoints.length; i++)
                Positioned(
                  left: cpPositions[i].dx - _CheckpointContent.kSize / 2,
                  top: cpPositions[i].dy - _CheckpointContent.kSize * 1.1,
                  child: _bob(
                    amplitude: 5,
                    child: GestureDetector(
                      onTap: () => _onCheckpointTap(i),
                      child: _CheckpointContent(
                        model: _checkpoints[i],
                        currentFrame: _currentFrame,
                        isUnlocking: _unlockingIdx == i,
                        unlockCtrl: _unlockingIdx == i ? _unlockCtrl : null,
                      ),
                    ),
                  ),
                ),

              // Decor items
              Positioned(
                left: w * 0.02,
                top: h * 0.10,
                child: _bob(
                  phase: 1.1,
                  amplitude: 7,
                  child: Image.asset(
                    'assets/images/learningIslandScreen/decor_learning_island1.png',
                    width: 90,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                right: w * 0.02,
                top: h * 0.06,
                child: _bob(
                  phase: 2.4,
                  amplitude: 7,
                  child: Image.asset(
                    'assets/images/learningIslandScreen/decor_learning_island2.png',
                    width: 100,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                left: w * 0.03,
                bottom: h * 0.18,
                child: _bob(
                  phase: 3.0,
                  amplitude: 6,
                  child: Image.asset(
                    'assets/images/learningIslandScreen/decor_learning_island3.png',
                    width: 80,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                right: w * 0.03,
                bottom: h * 0.16,
                child: _bob(
                  phase: 0.6,
                  amplitude: 6,
                  child: Image.asset(
                    'assets/images/learningIslandScreen/decor_learning_island4.png',
                    width: 85,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                right: w * 0.06,
                top: h * 0.26,
                child: _bob(
                  phase: 1.8,
                  amplitude: 8,
                  child: Image.asset(
                    'assets/images/learningIslandScreen/island_globe.png',
                    width: 70,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Cloud strip at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/homeScreen/clouds/clouds_6.png',
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

              // Back button — must be Positioned so StackFit.expand doesn't inflate it
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.arrow_back, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Dashed path painter ──────────────────────────────────────────────────────

class _PathPainter extends CustomPainter {
  const _PathPainter({
    required this.positions,
    required this.checkpoints,
    required this.cpIndices,
  });

  /// All walkway waypoints (checkpoints + via-points between them).
  final List<Offset> positions;
  final List<CheckpointModel> checkpoints;

  /// Indices into [positions] where each checkpoint sits.
  final List<int> cpIndices;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length - 1; i++) {
      // Find the checkpoint interval this waypoint segment belongs to.
      var k = 0;
      while (k + 1 < cpIndices.length - 1 && cpIndices[k + 1] <= i) {
        k++;
      }
      final done = checkpoints[k].state == CheckpointState.complete &&
          checkpoints[k + 1].state != CheckpointState.uncheck;
      _drawDashedCurve(canvas, i, done);
    }
  }

  // Catmull-Rom → cubic bezier control points for segment i→i+1
  (Offset, Offset) _controlPoints(int i) {
    final p0 = i > 0 ? positions[i - 1] : positions[i];
    final p1 = positions[i];
    final p2 = positions[i + 1];
    final p3 = i + 2 < positions.length ? positions[i + 2] : positions[i + 1];
    const t = 8.0; // higher = tighter curves, less overshoot on zigzag paths
    return (
      Offset(p1.dx + (p2.dx - p0.dx) / t, p1.dy + (p2.dy - p0.dy) / t),
      Offset(p2.dx - (p3.dx - p1.dx) / t, p2.dy - (p3.dy - p1.dy) / t),
    );
  }

  void _drawDashedCurve(Canvas canvas, int i, bool done) {
    final paint = Paint()
      ..color = done ? const Color(0xFF3CB54A) : Colors.white70
      ..strokeWidth = done ? 3.5 : 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p1 = positions[i];
    final p2 = positions[i + 1];
    final (cp1, cp2) = _controlPoints(i);

    final curvePath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

    const dash = 8.0, gap = 6.0;
    for (final metric in curvePath.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => true;
}

// ─── Checkpoint content (no Positioned — parent is responsible) ───────────────

class _CheckpointContent extends StatelessWidget {
  const _CheckpointContent({
    required this.model,
    required this.currentFrame,
    required this.isUnlocking,
    required this.unlockCtrl,
  });

  static const double kSize = 36.0;

  final CheckpointModel model;
  final int currentFrame;
  final bool isUnlocking;
  final AnimationController? unlockCtrl;

  String get _asset {
    return switch (model.state) {
      CheckpointState.complete =>
        'assets/images/checkpoint/checkpoint_complete.png',
      CheckpointState.current =>
        'assets/images/checkpoint/checkpointCurrent/checkpoint_current${currentFrame + 1}.png',
      CheckpointState.uncheck =>
        'assets/images/checkpoint/checkpoint_uncheck.png',
    };
  }

  Widget _baseImg() => Image.asset(
        _asset,
        width: kSize,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: kSize,
          height: kSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (model.state) {
              CheckpointState.complete => const Color(0xFF3CB54A),
              CheckpointState.current => const Color(0xFFF5A623),
              CheckpointState.uncheck => Colors.white54,
            },
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget img = _baseImg();

    if (isUnlocking && unlockCtrl != null) {
      img = AnimatedBuilder(
        animation: unlockCtrl!,
        builder: (_, child) => Transform.scale(
          scale: Curves.elasticOut.transform(unlockCtrl!.value),
          child: child,
        ),
        child: Image.asset(
          'assets/images/checkpoint/checkpointCurrent/checkpoint_current1.png',
          width: kSize,
          height: kSize,
          errorBuilder: (_, __, ___) => _baseImg(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: kSize * 1.6,
          width: kSize,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: img,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: switch (model.state) {
                CheckpointState.complete =>
                  const [Color(0xFF7EDD66), Color(0xFF2F9E3F)],
                CheckpointState.current =>
                  const [Color(0xFFFFCE3F), Color(0xFFF58B1F)],
                CheckpointState.uncheck =>
                  const [Color(0xFF9BB2C6), Color(0xFF5F7991)],
              },
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1.6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            model.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Color(0x80000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
