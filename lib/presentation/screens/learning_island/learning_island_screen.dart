import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/lottie/dotlottie_decoder.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../widgets/island_topic_progress_bar.dart';

enum CheckpointState { complete, current, uncheck }

class CheckpointModel {
  CheckpointModel({
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

/// A scattered filler decoration (pine trees, flower bushes) around the map.
class _DecorItem {
  const _DecorItem(this.asset, this.xFrac, this.yFrac, this.wFrac);

  final String asset;

  /// Left edge as a fraction of map width.
  final double xFrac;

  /// Top edge as a fraction of total (scrollable) map height.
  final double yFrac;

  /// Width as a fraction of map width.
  final double wFrac;
}

/// A main decoration item (decor_island1..10) standing on a stone platform.
class _Station {
  const _Station(
    this.item,
    this.leftSide,
    this.xFrac,
    this.yFrac, {
    this.baseWFrac = 0.34,
    this.itemScale = 0.60,
    this.seatY = 0.40,
  });

  /// The item asset sitting on top of the platform.
  final String item;

  /// Left column → platform with stairs on the right (decor_island15);
  /// right column → stairs on the left (decor_island12). Stairs face the path.
  final bool leftSide;

  /// Left edge of the platform as a fraction of map width.
  final double xFrac;

  /// Top edge of the platform as a fraction of total map height.
  final double yFrac;

  /// Platform width as a fraction of map width.
  final double baseWFrac;

  /// Item width as a fraction of the platform width.
  final double itemScale;

  /// Image-fraction (0..1, top→bottom) of the platform where the item's base
  /// rests. ~0.40 is the front lip of the flat top surface.
  final double seatY;
}

class LearningIslandScreen extends StatefulWidget {
  const LearningIslandScreen({super.key});

  @override
  State<LearningIslandScreen> createState() => _LearningIslandScreenState();
}

class _LearningIslandScreenState extends State<LearningIslandScreen>
    with TickerProviderStateMixin {
  // Vocabulary topics of Learning Island, in play order (bottom → top):
  // (label, topic id in lib/data/sample/topics.json, total word count).
  static const List<(String, int, int)> _topics = [
    ('Đồ dùng học tập', 1, 62),
    ('Trường học', 39, 39),
    ('Học tập', 49, 23),
    ('Giáo dục', 44, 58),
    ('Máy tính', 14, 37),
    ('Số', 5, 19),
  ];

  // Horizontal position of each checkpoint as a fraction of map width, bottom
  // (index 0) → top.
  static const List<double> _cpXFrac = [0.47, 0.39, 0.6, 0.42, 0.55, 0.48];

  // Bowed mid-points between consecutive checkpoints. Pushing them past the
  // checkpoints (e.g. 0.58 / 0.34) makes the sand road overshoot and wind like
  // the reference map instead of running almost straight.
  static const List<double> _midXFrac = [0.58, 0.35, 0.61, 0.34, 0.60];

  // Vertical layout of the (taller-than-screen) scrollable map.
  static const double _gap = 230; // vertical spacing between checkpoints
  static const double _topMargin = 200;
  static const double _bottomMargin = 180;

  // Main items, each standing on a stone platform, down the left/right gutters.
  // itemScale / seatY are per-item so each object sits squarely on its base.
  static const List<_Station> _stations = [
    // Left column (stairs face right → base decor_island15).
    _Station(
      'decor_island1.png',
      true,
      0.01,
      0.03,
      itemScale: 0.52,
      seatY: 0.44,
    ), // telescope
    _Station(
      'decor_island2.png',
      true,
      0.02,
      0.21,
      itemScale: 0.56,
      seatY: 0.45,
    ), // book + bulb
    _Station(
      'decor_island6.png',
      true,
      -0.01,
      0.41,
      itemScale: 0.6,
      seatY: 0.45,
    ), // pencils
    _Station(
      'decor_island8.png',
      true,
      -0.02,
      0.59,
      itemScale: 0.60,
      seatY: 0.53,
    ), // table
    _Station(
      'decor_island10.png',
      true,
      0.01,
      0.80,
      itemScale: 0.83,
      seatY: 0.26,
    ), // magic tree
    // Right column (stairs face left → base decor_island12).
    _Station(
      'decor_island3.png',
      false,
      0.64,
      0.02,
      itemScale: 0.55,
      seatY: 0.39,
    ), // grad cap
    _Station(
      'decor_island4.png',
      false,
      0.64,
      0.14,
      itemScale: 0.60,
      seatY: 0.46,
    ), // "123"
    _Station(
      'decor_island5.png',
      false,
      0.63,
      0.29,
      itemScale: 0.60,
      seatY: 0.42,
    ), // computer
    _Station(
      'decor_island9.png',
      false,
      0.64,
      0.46,
      itemScale: 0.58,
      seatY: 0.43,
    ), // books + trophy
    _Station(
      'decor_island7.png',
      false,
      0.63,
      0.82,
      itemScale: 0.58,
      seatY: 0.6,
    ), // magnifier
  ];

  // Filler greenery (pine trees decor_island13/14, flower bush decor_island11)
  // sprinkled in the gaps. Depth-sorted with the stations so overlaps look
  // natural (lower on screen = drawn in front).
  static const List<_DecorItem> _fillers = [
    _DecorItem('decor_island11.png', 0.40, 0.055, 0.2),
    _DecorItem('decor_island11.png', 0.22, 0.13, 0.15),
    _DecorItem('decor_island13.png', 0.85, 0.085, 0.2),
    _DecorItem('decor_island11.png', 0.78, 0.22, 0.1),
    _DecorItem('decor_island13.png', 0.02, 0.31, 0.2),
    _DecorItem('decor_island14.png', 0.7, 0.34, 0.5),
    _DecorItem('decor_island11.png', 0.24, 0.51, 0.15),
    _DecorItem('decor_island14.png', 0.75, 0.58, 0.25),
    _DecorItem('decor_island11.png', 0.03, 0.70, 0.15),
    _DecorItem('decor_island11.png', 0.7, 0.55, 0.1),
    _DecorItem('decor_island16.png', 0.5, 0.64, 0.5),
  ];

  // Platform geometry (image fractions, measured from decor_island12/15).
  static const double _platCx = 0.50; // horizontal centre of the top surface
  static const double _platBottom = 0.77; // visible bottom (for depth sorting)

  final List<CheckpointModel> _checkpoints = List.generate(
    _topics.length,
    (i) => CheckpointModel(
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
      // Tốc độ 0.5x: kéo dài thời lượng gấp đôi để lottie chạy chậm lại một nửa.
      duration: const Duration(milliseconds: 2000),
      value: 1.0,
    );
    _loadProgress();

    // Start the map scrolled to the bottom so checkpoint 0 (the current one)
    // is visible; the user pulls up to reveal the locked checkpoints above.
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

  CheckpointModel get _activeCheckpoint {
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
    // Checkpoint đã mở (đang học hoặc đã xong) → vào màn học từ vựng
    final tapped = _checkpoints[tappedIdx];
    if (tapped.state != CheckpointState.uncheck) {
      await context.push('/lesson/${tapped.topicId}?islandId=learning');
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

  /// A main item resting on a stone platform; stairs face the center path.
  /// Platforms (decor_island12/15) are square images; the flat top surface sits
  /// around image-y 0.40, so the item's bottom is anchored there.
  Widget _buildStation(_Station s, double w) {
    final b = w * s.baseWFrac;
    final itemW = b * s.itemScale;
    final baseAsset = s.leftSide ? 'decor_island15.png' : 'decor_island12.png';

    return SizedBox(
      width: b,
      height: b,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Stone platform (square image).
          Image.asset(
            'assets/images/learningIslandScreen/$baseAsset',
            width: b,
            height: b,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // Item, base centred on the platform's flat top surface.
          Positioned(
            left: _platCx * b - itemW / 2,
            top: s.seatY * b - itemW,
            child: Image.asset(
              'assets/images/learningIslandScreen/${s.item}',
              width: itemW,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// Stations + fillers, depth-sorted by their visible bottom so lower items
  /// are painted in front (isometric depth). Platform bases stay behind the
  /// things in front of them; trees nestle naturally around the platforms.
  List<Widget> _decorWidgets(double w, double contentHeight) {
    final entries = <({double depth, Widget child})>[];

    for (final s in _stations) {
      final b = w * s.baseWFrac;
      final top = contentHeight * s.yFrac;
      entries.add((
        depth: top + b * _platBottom,
        child: Positioned(
          left: w * s.xFrac,
          top: top,
          child: _buildStation(s, w),
        ),
      ));
    }

    for (final d in _fillers) {
      final fw = w * d.wFrac;
      final top = contentHeight * d.yFrac;
      entries.add((
        depth: top + fw,
        child: Positioned(
          left: w * d.xFrac,
          top: top,
          child: Image.asset(
            'assets/images/learningIslandScreen/${d.asset}',
            width: fw,
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
      backgroundColor: const Color(0xFF8DC63F),
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
                      // Tiled grass background — assembled from repeated
                      // island_background_component pieces.
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF8DC63F),
                            image: DecorationImage(
                              image: AssetImage(
                                'assets/images/learningIslandScreen/island_background_component.png',
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

                      // Stations (item-on-platform) + filler greenery,
                      // depth-sorted so lower items paint in front.
                      ..._decorWidgets(w, contentHeight),

                      // Checkpoints.
                      for (var i = 0; i < _checkpoints.length; i++)
                        Positioned(
                          left: cpPositions[i].dx - 65,
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

  final CheckpointModel model;

  /// Controller hoạt ảnh lottie cho checkpoint "current" (idle = khung cuối,
  /// chạy 0→1 khi vừa mở khóa).
  final AnimationController currentCtrl;
  final bool isUnlocking;
  final AnimationController? unlockCtrl;

  /// Text color of the label, by state (matches the reference map).
  Color get _labelColor => switch (model.state) {
    CheckpointState.complete => const Color(0xFF20160B),
    CheckpointState.current => const Color(0xFF2E6FB7),
    CheckpointState.uncheck => const Color(0xFF20160B),
  };

  /// Lottie checkpoint "current" với [ctrl] điều khiển tiến trình:
  /// - [currentCtrl]: idle ở khung cuối (value 1), chạy 0→1 khi mở khóa.
  /// - [kAlwaysDismissedAnimation]: đứng yên ở khung đầu (xem trước lúc nảy).
  Widget _currentLottieWidget(Animation<double> ctrl) => Lottie.asset(
    _currentLottie,
    controller: ctrl,
    width: kSize,
    height: kSize,
    fit: BoxFit.contain,
    decoder: dotLottieDecoder,
    errorBuilder: (_, _, _) => SvgPicture.asset(_uncheckSvg, width: kSize),
  );

  /// Ảnh tĩnh theo trạng thái: complete / uncheck dùng SVG, current dùng
  /// lottie (đứng ở khung hình cuối khi không chạy hoạt ảnh).
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
        // Xem trước khung đầu của lottie; sau khi nảy xong sẽ chạy tới khung cuối.
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
        // Cream label box: topic name + "X/N từ" progress (reference style).
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
