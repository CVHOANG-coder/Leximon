import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/lottie/dotlottie_decoder.dart';

enum CheckpointState { complete, current, uncheck }

const String _kAssetDir = 'assets/images/oceanKingdom';

class OceanCheckpointModel {
  OceanCheckpointModel({
    required this.id,
    required this.label,
    required this.topicId,
    required this.wordCount,
    required this.learnedCount,
    required this.state,
    this.dxFrac = 0,
    this.dyFrac = 0,
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

  /// Optional fine-tune offsets (fractions of map width) applied on top of the
  /// auto-computed position, so a checkpoint can be nudged off the road centre.
  final double dxFrac;
  final double dyFrac;
}

class OceanKingdomScreen extends StatefulWidget {
  const OceanKingdomScreen({super.key});

  @override
  State<OceanKingdomScreen> createState() => _OceanKingdomScreenState();
}

class _OceanKingdomScreenState extends State<OceanKingdomScreen>
    with TickerProviderStateMixin {
  // Themed islands of Ocean Kingdom, in play order (bottom → top):
  // (label, topic id in topics.json, total word count).
  static const List<(String, int, int)> _topics = [
    ('Chủ đề biển', 4, 32),
    ('Môi trường', 11, 20),
    ('Động vật', 47, 41),
    ('Thảm họa thiên nhiên', 56, 16),
    ('Thời tiết', 41, 38),
    ('Du lịch', 18, 21),
    ('Các loài hoa', 31, 19),
  ];

  // The winding road art is a single tile repeated vertically. Its height / width
  // ratio and the horizontal centre of the sand path, sampled top → bottom, were
  // measured from road.png so checkpoints can be snapped onto the road.
  static const double _roadAspect = 2.0202; // h / w of road.png
  // Road drawn narrower than the map width (centered); smaller = thinner road.
  static const double _roadWidthFrac = 0.62;
  static const List<double> _roadCenterline = [
    0.415,
    0.595,
    0.645,
    0.586,
    0.451,
    0.324,
    0.276,
    0.330,
    0.351,
    0.583,
    0.600,
    0.650,
    0.598,
    0.511,
    0.357,
    0.342,
    0.337,
    0.460,
    0.609,
    0.750,
    0.727,
    0.596,
    0.480,
    0.363,
    0.372,
    0.394,
  ];

  // Main architecture islands in the left/right gutters. Painted OVER the road
  // so they sit on top where the path passes by.
  // (asset, left frac, top frac of content height, w frac).
  static const List<(String, double, double, double)> _islands = [
    ('decord_item7.png', -0.04, 0.80, 0.54), // fish market (start), left
    ('decord_item6.png', 0.65, 0.655, 0.46), // windmill, right
    ('decord_item5.png', -0.04, 0.545, 0.46), // shell dome, left
    ('decord_item4.png', 0.56, 0.425, 0.46), // water-treatment, right
    ('decord_item3.png', -0.04, 0.24, 0.46), // weather dome, left
    ('decord_item2.png', 0.7, 0.185, 0.42), // lighthouse, right
    ('decord_item1.png', 0.2, 0.005, 0.50), // shell aquarium (top), left
    ('decord_item11.png', 0.56, 0.845, 0.45), // shell aquarium (top), left
  ];

  // Rock fillers in the open water. Painted behind the road.
  static const List<(String, double, double, double)> _rocks = [
    ('decord_item9.png', 0.80, 0.355, 0.11),
    ('decord_item8.png', 0.06, 0.235, 0.13),
    ('decord_item10.png', 0.72, 0.88, 0.20),
    ('decord_item10.png', 0.72, 0.12, 0.3),
    ('decord_item8.png', 0.82, 0.50, 0.12),
  ];

  // Vertical layout of the (taller-than-screen) scrollable map, as fractions of
  // the map width (so spacing scales with the screen).
  static const double _gapFrac = 0.58; // spacing between checkpoints
  static const double _topMarginFrac = 0.34;
  static const double _bottomMarginFrac = 0.62;

  // Per-checkpoint fine-tune (dx, dy) as fractions of map width, bottom → top.
  // (0, 0) = sit exactly on the road centre; tweak to nudge a checkpoint.
  static const List<(double, double)> _cpNudge = [
    (-0.05, 0), // Chủ đề biển
    (0, 0), // Môi trường
    (-0.1, 0.04), // Động vật
    (0.15, 0.12), // Thảm họa thiên nhiên
    (0, 0.021), // Thời tiết
    (0, 0), // Du lịch
    (0.1, 0.05), // Các loài hoa
  ];

  final List<OceanCheckpointModel> _checkpoints = List.generate(
    _topics.length,
    (i) => OceanCheckpointModel(
      id: i,
      label: _topics[i].$1,
      topicId: _topics[i].$2,
      wordCount: _topics[i].$3,
      learnedCount: 0,
      state: i == 0 ? CheckpointState.current : CheckpointState.uncheck,
      dxFrac: _cpNudge[i].$1,
      dyFrac: _cpNudge[i].$2,
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

  void _onCheckpointTap(int tappedIdx) {
    // Checkpoint đã mở (đang học hoặc đã xong) → vào màn học từ vựng.
    final tapped = _checkpoints[tappedIdx];
    if (tapped.state != CheckpointState.uncheck) {
      context.push('/lesson/${tapped.topicId}?islandId=ocean');
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
      _frameCtrl.forward(from: 0);
    });
    setState(() {});
  }

  double _cpY(double gap, double topMargin, int i) =>
      topMargin + (_checkpoints.length - 1 - i) * gap;

  /// Horizontal centre of the road (fraction of width) at content-y [y], given
  /// the tiled road's [tileH]. Interpolates the sampled centerline within the
  /// repeating tile, so checkpoints land on the sand wherever they fall.
  double _roadXFracAt(double y, double tileH) {
    final local = (y % tileH) / tileH; // 0..1 within the current tile
    final n = _roadCenterline.length;
    final t = (local * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final i = t.floor();
    final j = (i + 1).clamp(0, n - 1);
    final f = t - i;
    return _roadCenterline[i] * (1 - f) + _roadCenterline[j] * f;
  }

  /// Renders a list of side-gutter decor, depth-sorted by their visible bottom
  /// so lower items paint in front (isometric depth).
  List<Widget> _decorWidgets(
    List<(String, double, double, double)> decor,
    double w,
    double contentHeight,
  ) {
    final entries = <({double depth, Widget child})>[];

    for (final d in decor) {
      final dw = w * d.$4;
      final top = contentHeight * d.$3;
      entries.add((
        depth: top + dw, // width is a fair proxy for height here
        child: Positioned(
          left: w * d.$2,
          top: top,
          child: Image.asset(
            '$_kAssetDir/${d.$1}',
            width: dw,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ));
    }

    entries.sort((a, b) => a.depth.compareTo(b.depth));
    return [for (final e in entries) e.child];
  }

  /// The winding road: road.png tiled vertically from the top of the map to the
  /// bottom. Drawn over the decor so the path can run across the islands.
  List<Widget> _roadTiles(
    double roadW,
    double roadLeft,
    double contentHeight,
    double tileH,
  ) {
    final count = (contentHeight / tileH).ceil();
    return [
      for (var i = 0; i < count; i++)
        Positioned(
          top: i * tileH,
          left: roadLeft,
          child: Image.asset(
            '$_kAssetDir/road.png',
            width: roadW,
            height: tileH,
            fit: BoxFit.fill, // width:height already matches the road aspect
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E78C8),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final gap = w * _gapFrac;
          final topMargin = w * _topMarginFrac;
          final bottomMargin = w * _bottomMarginFrac;
          final n = _checkpoints.length;
          final mapHeight = topMargin + (n - 1) * gap + bottomMargin;
          final contentHeight = mapHeight > constraints.maxHeight
              ? mapHeight
              : constraints.maxHeight;
          // Road is narrower than the map and centered horizontally.
          final roadW = w * _roadWidthFrac;
          final roadLeft = (w - roadW) / 2;
          final tileH = roadW * _roadAspect;

          // Checkpoints sit on the road: y from the layout, x snapped to the
          // road centerline at that y, plus an optional per-checkpoint nudge.
          final cpPositions = [
            for (var i = 0; i < n; i++)
              Offset(
                roadLeft +
                    roadW * _roadXFracAt(_cpY(gap, topMargin, i), tileH) +
                    w * _checkpoints[i].dxFrac,
                _cpY(gap, topMargin, i) + w * _checkpoints[i].dyFrac,
              ),
          ];

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
                      // Tiled ocean water — repeated background component.
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E78C8),
                            image: DecorationImage(
                              image: AssetImage(
                                '$_kAssetDir/island_background_component.png',
                              ),
                              repeat: ImageRepeat.repeat,
                            ),
                          ),
                        ),
                      ),

                      // Rock fillers (behind the road).
                      ..._decorWidgets(_rocks, w, contentHeight),

                      // Winding road, road.png tiled top → bottom.
                      ..._roadTiles(roadW, roadLeft, contentHeight, tileH),

                      // Main architecture islands — painted over the road.
                      ..._decorWidgets(_islands, w, contentHeight),

                      // Checkpoints — the only thing riding on the road.
                      for (var i = 0; i < n; i++)
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

  final OceanCheckpointModel model;

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
