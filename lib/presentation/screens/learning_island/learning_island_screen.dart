import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CheckpointState { complete, current, uncheck }

class CheckpointModel {
  CheckpointModel({required this.id, required this.label, required this.state});
  final int id;
  final String label;
  CheckpointState state;
}

class LearningIslandScreen extends StatefulWidget {
  const LearningIslandScreen({super.key});

  @override
  State<LearningIslandScreen> createState() => _LearningIslandScreenState();
}

class _LearningIslandScreenState extends State<LearningIslandScreen>
    with TickerProviderStateMixin {
  final List<CheckpointModel> _checkpoints = List.generate(
    8,
    (i) => CheckpointModel(
      id: i,
      label: 'Lesson ${i + 1}',
      state: i == 0 ? CheckpointState.current : CheckpointState.uncheck,
    ),
  );

  AnimationController? _unlockCtrl;
  int? _unlockingIdx;

  late final AnimationController _frameCtrl;
  int _currentFrame = 0;

  late final AnimationController _bobCtrl;

  @override
  void initState() {
    super.initState();

    _frameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
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

  // Offsets from island center — calibrated from screenshot pixel positions
  static const List<Offset> _cpOffsets = [
    Offset(  15,   78), // Lesson 1 — đầu path trên đảo (sát dock)
    Offset( -29,   69), // Lesson 2 — flag/pole area
    Offset( -76,   11), // Lesson 3 — near magnifying glass
    Offset( -37,  -22), // Lesson 4 — center below school
    Offset(  45,  -15), // Lesson 5 — trên đoạn path phải trường học
    Offset(  41,  -94), // Lesson 6 — right (computer desk)
    Offset( -18, -140), // Lesson 7 — upper-center (big tree)
    Offset(  70, -120), // Lesson 8 — sát chân stairs 123, trên path
  ];

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

          final cpPositions =
              _cpOffsets.map((o) => Offset(cx + o.dx, cy + o.dy)).toList();

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

              // Dashed path between checkpoints
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    positions: cpPositions,
                    checkpoints: List.unmodifiable(_checkpoints),
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
  const _PathPainter({required this.positions, required this.checkpoints});
  final List<Offset> positions;
  final List<CheckpointModel> checkpoints;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length - 1; i++) {
      final done = checkpoints[i].state == CheckpointState.complete &&
          checkpoints[i + 1].state != CheckpointState.uncheck;
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
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            model.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
