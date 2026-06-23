import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/lottie/dotlottie_decoder.dart';

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

/// A piece of home furniture standing on the grass beside the path, positioned
/// freely with x/y fractions just like a [_DecorItem].
class _Station {
  const _Station(this.item, this.xFrac, this.yFrac, {this.wFrac = 0.36});

  /// Furniture asset (decord_itemN.png).
  final String item;

  /// Left edge as a fraction of map width.
  final double xFrac;

  /// Top edge as a fraction of total (scrollable) map height.
  final double yFrac;

  /// Furniture width as a fraction of map width.
  final double wFrac;
}

/// A scattered filler decoration (flower bush, rocks, pond, fountain) around the
/// map.
class _DecorItem {
  const _DecorItem(this.asset, this.xFrac, this.yFrac, this.wFrac);

  /// Left edge as a fraction of map width.
  final double xFrac;

  /// Top edge as a fraction of total (scrollable) map height.
  final double yFrac;

  /// Width as a fraction of map width.
  final double wFrac;

  final String asset;
}

class HomeVillageScreen extends StatefulWidget {
  const HomeVillageScreen({super.key});

  @override
  State<HomeVillageScreen> createState() => _HomeVillageScreenState();
}

class _HomeVillageScreenState extends State<HomeVillageScreen>
    with TickerProviderStateMixin {
  static const String _assets = 'assets/images/homeVillage';

  // Home Village topics, in play order (bottom → top):
  // (label, topic id in lib/data/sample/topics.json, total word count).
  static const List<(String, int, int)> _topics = [
    ('Quần áo', 42, 38),
    ('Tình yêu', 37, 19),
    ('Công việc nhà', 15, 19),
    ('Nhà bếp', 9, 35),
    ('Phòng ngủ', 7, 28),
    ('Phòng khách', 12, 32),
    ('Gia đình', 45, 40),
  ];

  // Horizontal position of each checkpoint as a fraction of map width, bottom
  // (index 0) → top. Each leans toward the gutter where its furniture sits.
  static const List<double> _cpXFrac = [
    0.45,
    0.55,
    0.45,
    0.55,
    0.45,
    0.55,
    0.45,
  ];

  // Bowed mid-points between consecutive checkpoints; pushed past the
  // checkpoints so the sand road overshoots and winds.
  static const List<double> _midXFrac = [0.62, 0.36, 0.62, 0.36, 0.62, 0.38];

  // Vertical layout of the (taller-than-screen) scrollable map.
  static const double _gap = 250; // vertical spacing between checkpoints
  static const double _topMargin = 360; // room for the house above the top node
  static const double _bottomMargin = 180;

  // The house (decord_item9) at the very top. Its own front walkway exits the
  // image near the bottom-left (~21% across, ~93% down); the cobble road is
  // anchored there so the two paths join seamlessly.
  static const double _houseWFrac = 0.9;
  static const double _houseTop = 24;
  static const double _houseAspect = 825 / 982; // image height / width
  static const double _houseWalkXFrac = 0.38; // walkway exit, x within image
  static const double _houseWalkYFrac = 0.93; // walkway exit, y within image

  // Furniture stations, positioned freely with (xFrac, yFrac) — left/top edge as
  // fractions of map width / total content height. Tweak these to place each
  // piece exactly where you want it.
  static const List<_Station> _stations = [
    _Station('decord_item7.png', 0.63, 0.88, wFrac: 0.36), // dây phơi → Quần áo
    _Station(
      'decord_item6.png',
      0.01,
      0.76,
      wFrac: 0.36,
    ), // cổng hoa → Tình yêu
    _Station(
      'decord_item4.png',
      0.62,
      0.63,
      wFrac: 0.38,
    ), // máy giặt → Công việc nhà
    _Station('decord_item3.png', -0.01, 0.51, wFrac: 0.40), // bếp → Nhà bếp
    _Station('decord_item2.png', 0.62, 0.39, wFrac: 0.38), // giường → Phòng ngủ
    _Station('decord_item1.png', 0.00, 0.27, wFrac: 0.38), // sofa → Phòng khách
    _Station('decord_item5.png', 0.8, 0.2, wFrac: 0.45), // picnic → Gia đình
  ];

  // Filler scenery (flowers / rocks / pond / heart fountain) sprinkled in the
  // gaps; yFrac is a fraction of the total content height.
  static const List<_DecorItem> _fillers = [
    _DecorItem('decord_item8.png', 0.05, 0.85, 0.34), // heart fountain
    _DecorItem('decord_item12.png', 0.04, 0.40, 0.30), // pond
    _DecorItem('decord_item10.png', 0.74, 0.70, 0.18), // flower bush
    _DecorItem('decord_item10.png', 0.10, 0.58, 0.16), // flower bush
    _DecorItem('decord_item11.png', 0.78, 0.30, 0.16), // rocks
    _DecorItem('decord_item11.png', 0.05, 0.78, 0.16), // rocks
    _DecorItem('decord_item10.png', 0.46, 0.205, 0.15), // flower bush
  ];

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

  // Idle = last frame (value 1); runs 0→1 only when a new checkpoint unlocks.
  late final AnimationController _frameCtrl;

  // Cobblestone texture tiled along the road (loaded async).
  ui.Image? _roadTexture;

  @override
  void initState() {
    super.initState();
    _frameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
      value: 1.0,
    );
    _loadRoadTexture();

    // Start scrolled to the bottom so checkpoint 0 (the current one) is visible;
    // the user pulls up to reveal the locked checkpoints and the house above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _loadRoadTexture() async {
    final data = await rootBundle.load('$_assets/backgroud_roadway.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _roadTexture = frame.image);
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

  void _onCheckpointTap(int tappedIdx) {
    final tapped = _checkpoints[tappedIdx];
    // Đã mở (đang học hoặc đã xong) → vào màn học từ vựng.
    if (tapped.state != CheckpointState.uncheck) {
      context.push('/lesson/${tapped.topicId}?islandId=home');
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
    _checkpoints[curIdx].state = CheckpointState.complete;
    _checkpoints[curIdx].learnedCount = _checkpoints[curIdx].wordCount;

    _unlockCtrl!.forward().then((_) {
      setState(() {
        _checkpoints[tappedIdx].state = CheckpointState.current;
        _unlockingIdx = null;
      });
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
    // Flow up into decord_item9's own front walkway: the cobble road bends
    // gently left and ends right where the house's painted path exits the
    // image, so the two read as one continuous path.
    final houseW = w * _houseWFrac;
    final houseLeft = w * 0.5 - houseW / 2;
    final exitX = houseLeft + houseW * _houseWalkXFrac;
    final exitY = _houseTop + houseW * _houseAspect * _houseWalkYFrac;
    final lastCpY = _cpY(_checkpoints.length - 1);
    // Keep the bow close to the exit x so the road runs almost straight into the
    // walkway instead of looping out to the left.
    pts.add(Offset((w * _cpXFrac.last + exitX) / 2, (lastCpY + exitY) / 2));
    pts.add(Offset(exitX, exitY));
    return pts;
  }

  /// Furniture stations + filler scenery + the house, depth-sorted by their
  /// visible bottom so lower items paint in front (isometric depth).
  List<Widget> _decorWidgets(double w) {
    final entries = <({double depth, Widget child})>[];

    // Furniture stations — positioned freely via (xFrac, yFrac).
    for (final s in _stations) {
      final fw = w * s.wFrac;
      final top = _contentHeight * s.yFrac;
      entries.add((
        depth: top + fw,
        child: Positioned(
          left: w * s.xFrac,
          top: top,
          child: Image.asset(
            '$_assets/${s.item}',
            width: fw,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ));
    }

    // Fillers.
    for (final d in _fillers) {
      final fw = w * d.wFrac;
      final top = _contentHeight * d.yFrac;
      entries.add((
        depth: top + fw,
        child: Positioned(
          left: w * d.xFrac,
          top: top,
          child: Image.asset(
            '$_assets/${d.asset}',
            width: fw,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ));
    }

    // The house — the destination at the very top, centred. Depth-sorted just
    // below its walkway exit so the cobble road tucks under it and emerges at
    // the painted path.
    final houseW = w * _houseWFrac;
    final houseBottom = _houseTop + houseW * _houseAspect;
    entries.add((
      depth: houseBottom - 2,
      child: Positioned(
        left: w * 0.55 - houseW / 2,
        top: _houseTop,
        child: Image.asset(
          '$_assets/decord_item9.png',
          width: houseW,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    ));

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
                      // Tiled grass background.
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF8DC63F),
                            image: DecorationImage(
                              image: AssetImage(
                                '$_assets/island_background_component.png',
                              ),
                              repeat: ImageRepeat.repeat,
                            ),
                          ),
                        ),
                      ),

                      // Winding sand road connecting the checkpoints.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RoadPainter(
                            _roadWaypoints(w),
                            _roadTexture,
                          ),
                        ),
                      ),

                      // Furniture stations + filler scenery + house,
                      // depth-sorted so lower items paint in front.
                      ..._decorWidgets(w),

                      // Checkpoints (drawn on top of the decor).
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
            ],
          );
        },
      ),
    );
  }
}

// ─── Winding sand road painter ────────────────────────────────────────────────

class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.points, this.texture);

  /// Road waypoints, bottom → top; the road threads smoothly through them.
  final List<Offset> points;

  /// Cobblestone tile (backgroud_roadway.png) used to fill the road; null until
  /// the image finishes loading, in which case a flat sandy colour is used.
  final ui.Image? texture;

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
    final roadW = size.width * 0.16;

    // Golden border framing the path.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF0C246)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW + 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Cobblestone fill: tile backgroud_roadway.png along the road via an image
    // shader; fall back to a flat sandy colour until the texture loads.
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = roadW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final tex = texture;
    if (tex != null) {
      // Scale the tile so several cobbles span the road width.
      final scale = roadW * 3.2 / tex.width;
      fill.shader = ImageShader(
        tex,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(scale, scale, 1, 1)).storage,
      );
    } else {
      fill.color = const Color(0xFFEAD09A);
    }
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.points != points || old.texture != texture;
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
