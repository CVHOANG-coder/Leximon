import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/lottie/dotlottie_decoder.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../widgets/island_topic_progress_bar.dart';

enum CheckpointState { complete, current, uncheck }

const String _kAssetDir = 'assets/images/natureIsland';

class NatureCheckpointModel {
  NatureCheckpointModel({
    required this.id,
    required this.label,
    required this.topicId,
    required this.wordCount,
    required this.learnedCount,
    required this.state,
  });

  final int id;
  final String label;

  /// Id of the vocabulary topic in lib/data/sample/topics.json.
  final int topicId;

  /// Total words in this topic.
  final int wordCount;

  /// Words the learner has finished (drives the "X/N từ" progress label).
  int learnedCount;

  CheckpointState state;
}

/// A self-contained nature scene (cave, pond, fruit trees…) standing on the
/// grass. Placed in the side gutters and depth-sorted with the others.
/// (asset, left frac, top frac of content height, w frac).
class _Decor {
  const _Decor(this.asset, this.xFrac, this.yFrac, this.wFrac);

  final String asset;
  final double xFrac;
  final double yFrac;
  final double wFrac;
}

class NatureIslandScreen extends StatefulWidget {
  const NatureIslandScreen({super.key});

  @override
  State<NatureIslandScreen> createState() => _NatureIslandScreenState();
}

class _NatureIslandScreenState extends State<NatureIslandScreen>
    with TickerProviderStateMixin {
  // Nature-themed vocabulary topics, in play order (bottom → top):
  // (label, topic id in topics.json, total word count).
  static const List<(String, int, int)> _topics = [
    ('Động vật', 47, 41),
    ('Côn trùng', 48, 18),
    ('Các loài hoa', 31, 19),
    ('Thực vật', 50, 16),
    ('Trái cây', 46, 39),
    ('Rau, củ, quả', 25, 26),
  ];

  // Horizontal position of each checkpoint as a fraction of map width, bottom
  // (index 0) → top. Winds left/right like the reference path.
  static const List<double> _cpXFrac = [0.50, 0.62, 0.45, 0.58, 0.42, 0.50];

  // Bowed mid-points between consecutive checkpoints — pushed past the
  // checkpoints so the sand road overshoots and winds.
  static const List<double> _midXFrac = [0.66, 0.36, 0.66, 0.34, 0.60];

  // Vertical layout of the (taller-than-screen) scrollable map.
  static const double _gap = 230; // vertical spacing between checkpoints
  static const double _topMargin = 220;
  static const double _bottomMargin = 180;

  // The nature scenes from assets/images/natureIsland, scattered down the
  // gutters. decord_item1 (the cave) caps the top where the path ends.
  static const List<_Decor> _decor = [
    _Decor('decord_item1.png', 0.30, 0.00, 0.44), // cave (path leads in), top
    _Decor('decord_item3.png', 0.60, 0.075, 0.42), // fruit trees, right
    _Decor('decord_item2.png', -0.02, 0.20, 0.40), // flower bush, left
    _Decor('decord_item4.png', 0.58, 0.275, 0.44), // vegetable garden, right
    _Decor('decord_item7.png', 0.62, 0.45, 0.38), // squirrel tree, right
    _Decor('decord_item5.png', -0.04, 0.515, 0.46), // frog pond, left
    _Decor('decord_item6.png', 0.58, 0.665, 0.42), // rabbit burrow, right
    _Decor('decord_item8.png', -0.01, 0.78, 0.38), // log + stump, left
  ];

  final List<NatureCheckpointModel> _checkpoints = List.generate(
    _topics.length,
    (i) => NatureCheckpointModel(
      id: i,
      label: _topics[i].$1,
      topicId: _topics[i].$2,
      wordCount: _topics[i].$3,
      learnedCount: 0,
      state: i == 0 ? CheckpointState.current : CheckpointState.uncheck,
    ),
  );

  final ScrollController _scrollCtrl = ScrollController();

  AnimationController? _unlockCtrl;
  int? _unlockingIdx;

  // Điều khiển hoạt ảnh lottie của checkpoint "current": đứng yên ở khung hình
  // cuối khi vào màn (value = 1), chỉ chạy 0→1 khi mở khóa checkpoint mới.
  late final AnimationController _frameCtrl;

  @override
  void initState() {
    super.initState();

    _frameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
      value: 1.0,
    );
    _loadProgress();

    // Start scrolled to the bottom so checkpoint 0 (the current one) is
    // visible; the user pulls up to reveal the locked checkpoints above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _frameCtrl.dispose();
    _unlockCtrl?.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _currentIdx =>
      _checkpoints.indexWhere((c) => c.state == CheckpointState.current);

  NatureCheckpointModel get _activeCheckpoint {
    final index = _currentIdx;
    return _checkpoints[index < 0 ? _checkpoints.length - 1 : index];
  }

  Future<void> _loadProgress() async {
    final counts = await Future.wait([
      for (final checkpoint in _checkpoints)
        ProgressRepository.instance.learnedWordCount(
          topicId: checkpoint.topicId,
        ),
    ]);
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _checkpoints.length; i++) {
        _checkpoints[i].learnedCount = counts[i].clamp(
          0,
          _checkpoints[i].wordCount,
        );
      }
      final current = _checkpoints.indexWhere(
        (checkpoint) => checkpoint.learnedCount < checkpoint.wordCount,
      );
      for (var i = 0; i < _checkpoints.length; i++) {
        _checkpoints[i].state = current < 0 || i < current
            ? CheckpointState.complete
            : i == current
            ? CheckpointState.current
            : CheckpointState.uncheck;
      }
    });
  }

  Future<void> _onCheckpointTap(int tappedIdx) async {
    // Checkpoint đã mở (đang học hoặc đã xong) → vào màn học từ vựng.
    final tapped = _checkpoints[tappedIdx];
    if (tapped.state != CheckpointState.uncheck) {
      await context.push('/lesson/${tapped.topicId}?islandId=nature');
      await _loadProgress();
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
    _checkpoints[curIdx].learnedCount = _checkpoints[curIdx].wordCount;

    _unlockCtrl!.forward().then((_) {
      setState(() {
        _checkpoints[tappedIdx].state = CheckpointState.current;
        _unlockingIdx = null;
      });
      // Chạy lottie checkpoint "current" từ đầu → dừng ở khung hình cuối.
      _frameCtrl.forward(from: 0);
    });
    setState(() {});
  }

  /// Total scrollable height of the map.
  double get _contentHeight =>
      _topMargin + (_checkpoints.length - 1) * _gap + _bottomMargin;

  double _cpY(int i) => _topMargin + (_checkpoints.length - 1 - i) * _gap;

  /// Checkpoint center positions in map (content) coordinates.
  List<Offset> _checkpointPositions(double w) => [
    for (var i = 0; i < _checkpoints.length; i++)
      Offset(w * _cpXFrac[i], _cpY(i)),
  ];

  /// All road waypoints (checkpoints + bowed mid-points), bottom → top.
  List<Offset> _roadWaypoints(double w) {
    final pts = <Offset>[];
    for (var i = 0; i < _checkpoints.length; i++) {
      pts.add(Offset(w * _cpXFrac[i], _cpY(i)));
      if (i < _midXFrac.length) {
        pts.add(Offset(w * _midXFrac[i], (_cpY(i) + _cpY(i + 1)) / 2));
      }
    }
    return pts;
  }

  /// Nature scenes, depth-sorted by their visible bottom so lower items are
  /// painted in front (isometric depth).
  List<Widget> _decorWidgets(double w, double contentHeight) {
    final entries = <({double depth, Widget child})>[];

    for (final d in _decor) {
      final dw = w * d.wFrac;
      final top = contentHeight * d.yFrac;
      entries.add((
        depth: top + dw, // width is a fair proxy for height here
        child: Positioned(
          left: w * d.xFrac,
          top: top,
          child: Image.asset(
            '$_kAssetDir/${d.asset}',
            width: dw,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ));
    }

    entries.sort((a, b) => a.depth.compareTo(b.depth));
    return [for (final e in entries) e.child];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7DBE3A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final contentHeight = constraints.maxHeight > _contentHeight
              ? constraints.maxHeight
              : _contentHeight;
          final cpPositions = _checkpointPositions(w);

          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: w,
                  height: contentHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Tiled grass background — repeated background component.
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF7DBE3A),
                            image: DecorationImage(
                              image: AssetImage(
                                '$_kAssetDir/island_background_component.png',
                              ),
                              repeat: ImageRepeat.repeat,
                            ),
                          ),
                        ),
                      ),

                      // Winding sand road connecting the checkpoints.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RoadPainter(_roadWaypoints(w)),
                        ),
                      ),

                      // Nature scenes, depth-sorted so lower items paint in
                      // front.
                      ..._decorWidgets(w, contentHeight),

                      // Checkpoints riding on the road.
                      for (var i = 0; i < _checkpoints.length; i++)
                        Positioned(
                          left: cpPositions[i].dx - 70,
                          top:
                              cpPositions[i].dy -
                              _CheckpointContent.kSize * 1.3,
                          child: SizedBox(
                            width: 140,
                            child: GestureDetector(
                              onTap: () => _onCheckpointTap(i),
                              child: _CheckpointContent(
                                model: _checkpoints[i],
                                currentCtrl: _frameCtrl,
                                isUnlocking: _unlockingIdx == i,
                                unlockCtrl: _unlockingIdx == i
                                    ? _unlockCtrl
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Back button — fixed overlay, outside the scroll view.
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: IslandTopicProgressBar(
                    learnedWords: _activeCheckpoint.learnedCount,
                    totalWords: _activeCheckpoint.wordCount,
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

// ─── Winding sand road painter ────────────────────────────────────────────────

class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.points);

  /// Road waypoints, bottom → top; the road threads smoothly through them.
  final List<Offset> points;

  /// Smooth Catmull-Rom curve through all waypoints.
  Path _buildPath() {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
      const t = 3.5; // lower = rounder, more pronounced curves
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / t,
        p1.dy + (p2.dy - p0.dy) / t,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / t,
        p2.dy - (p3.dy - p1.dy) / t,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath();
    final roadW = size.width * 0.13;

    // Golden border around the path.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF0C246)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW + 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Earthy dirt fill.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC79A52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Rough, speckled dirt texture ("nham nhở như đất").
    _drawSpeckles(canvas, path, roadW);

    // Dashed line tracing the path.
    _drawDashed(canvas, path);
  }

  // Deterministic pseudo-noise in [0,1) — avoids Math.random so repaints are
  // stable.
  double _noise(double x) {
    final v = math.sin(x * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  void _drawSpeckles(Canvas canvas, Path path, double roadW) {
    const lighter = Color(0xFFD9B877);
    const darker = Color(0xFFA9793A);
    var k = 0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final tan = m.getTangentForOffset(d);
        if (tan != null) {
          final normal = Offset(-tan.vector.dy, tan.vector.dx);
          final offset = (_noise(k * 1.7) - 0.5) * roadW * 0.85;
          final radius = 1.2 + _noise(k * 3.1 + 0.5) * 2.4;
          final color = _noise(k * 5.3) > 0.5 ? lighter : darker;
          canvas.drawCircle(
            tan.position + normal * offset,
            radius,
            Paint()..color = color.withValues(alpha: 0.55),
          );
        }
        d += 8;
        k++;
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path) {
    final paint = Paint()
      ..color = const Color(0xFFA95D05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 11.0, gap = 9.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final end = (d + dash).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.points != points;
}

// ─── Checkpoint content (no Positioned — parent is responsible) ───────────────

class _CheckpointContent extends StatelessWidget {
  const _CheckpointContent({
    required this.model,
    required this.currentCtrl,
    required this.isUnlocking,
    required this.unlockCtrl,
  });

  static const double kSize = 56.0;

  static const _completeSvg = 'assets/svgs/checkpoint_complete.svg';
  static const _uncheckSvg = 'assets/svgs/checkpoint_uncheck.svg';
  static const _currentLottie = 'assets/lotties/checkpoint.lottie';

  final NatureCheckpointModel model;

  /// Controller hoạt ảnh lottie cho checkpoint "current" (idle = khung cuối,
  /// chạy 0→1 khi vừa mở khóa).
  final AnimationController currentCtrl;
  final bool isUnlocking;
  final AnimationController? unlockCtrl;

  /// Text color of the label, by state.
  Color get _labelColor => switch (model.state) {
    CheckpointState.complete => const Color(0xFF20160B),
    CheckpointState.current => const Color(0xFF2E6FB7),
    CheckpointState.uncheck => const Color(0xFF20160B),
  };

  Widget _currentLottieWidget(Animation<double> ctrl) => Lottie.asset(
    _currentLottie,
    controller: ctrl,
    width: kSize,
    height: kSize,
    fit: BoxFit.contain,
    decoder: dotLottieDecoder,
    errorBuilder: (_, _, _) => SvgPicture.asset(_uncheckSvg, width: kSize),
  );

  Widget _baseImg() => switch (model.state) {
    CheckpointState.complete => SvgPicture.asset(_completeSvg, width: kSize),
    CheckpointState.uncheck => SvgPicture.asset(_uncheckSvg, width: kSize),
    CheckpointState.current => _currentLottieWidget(currentCtrl),
  };

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
        child: _currentLottieWidget(kAlwaysDismissedAnimation),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: kSize * 1.5,
          width: kSize,
          child: Align(alignment: Alignment.bottomCenter, child: img),
        ),
        const SizedBox(height: 4),
        // Cream label box: topic name + "X/N từ" progress.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF4E2B4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCA9C49), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                model.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${model.learnedCount}/${model.wordCount} từ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
