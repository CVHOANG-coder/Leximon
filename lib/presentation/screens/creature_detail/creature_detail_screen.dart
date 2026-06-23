import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:lottie/lottie.dart';

import '../../../data/models/creature.dart';
import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/services/creature_stats.dart';

// ─── Palette (parchment / cartoon game style) ─────────────────────────────────

const _kCream = Color(0xFFFFF6DE);
const _kBorder = Color(0xFFC9A05E);
const _kInk = Color(0xFF1E3A5F);
const _kBlue = Color(0xFF2F6BFF);
const _kGold = Color(0xFFF5B91E);
const _kGreen = Color(0xFF3CB54A);
const _kRed = Color(0xFFE53935);

/// Tên đảo rút gọn tiếng Việt (hiển thị trên chip "Đảo …").
const _islandShortVi = <String, String>{
  'Learning Island': 'Tri Thức',
  'Home Village': 'Gia Đình',
  'Ocean Kingdom': 'Đại Dương',
  'Nature Island': 'Thiên Nhiên',
  'City Island': 'Thành Phố',
  'Adventure Island': 'Phiêu Lưu',
  'Life Island': 'Cuộc Sống',
  'Entertainment Island': 'Giải Trí',
  'Festival Island': 'Lễ Hội',
};

/// Các dạng tiến hóa hiển thị trên màn.
const _stageOrder = [
  ('baby', 'Bé'),
  ('teen', 'Thiếu niên'),
  ('adult', 'Trưởng thành'),
];

/// Chỉ số giả lập (chưa có hệ thống nuôi thú trong DB). Sinh ổn định theo
/// id + độ hiếm để mỗi thú có số khác nhau nhưng không đổi giữa các lần mở.
class _MockStats {
  _MockStats(Creature c) {
    final seed = c.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final mult = switch (c.rarity) {
      'legendary' => 2.4,
      'epic' => 1.8,
      'rare' => 1.4,
      _ => 1.0,
    };
    power = creaturePower(c);
    powerGain = 30 + seed % 12;
    hp = (900 + seed % 600) * mult ~/ 1;
    hpGain = 80 + seed % 30;
    defense = (180 + seed % 120) * mult ~/ 1;
    defenseGain = 12 + seed % 8;
    speed = 100 + seed % 60;
    speedGain = 4 + seed % 6;
    shards = 40 + seed % 60;
    shardsMax = 100;
    stones = 8 + seed % 12;
    stonesMax = 20;
  }

  late final int power, powerGain, hp, hpGain;
  late final int defense, defenseGain, speed, speedGain;
  late final int shards, shardsMax, stones, stonesMax;
}

/// Màn hình chi tiết thú cưng (theo mockup).
class CreatureDetailScreen extends StatefulWidget {
  const CreatureDetailScreen({super.key, required this.creatureId});
  final String creatureId;

  @override
  State<CreatureDetailScreen> createState() => _CreatureDetailScreenState();
}

class _CreatureDetailScreenState extends State<CreatureDetailScreen> {
  bool _loading = true;
  Creature? _creature;
  _MockStats? _stats;

  /// Trạng thái sở hữu thật từ DB (sao, giai đoạn, mảnh). null nếu chưa sở hữu.
  CreatureInventoryEntry? _inventory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creatures = await CreatureRepository.instance.loadCreatures();
    final c = creatures.firstWhere(
      (e) => e.id == widget.creatureId,
      orElse: () => creatures.first,
    );
    final inv = await InventoryRepository.instance.getCreature(c.id);
    if (!mounted) return;
    setState(() {
      _creature = c;
      _stats = _MockStats(c);
      _inventory = inv;
      _loading = false;
    });
  }

  /// Sao thật (0 nếu chưa sở hữu).
  int get _stars => _inventory?.stars ?? 0;

  /// Giai đoạn thật (baby nếu chưa sở hữu).
  String get _stage => _inventory?.stage ?? 'baby';

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — tính năng sắp ra mắt'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Nền rừng huyền ảo lấy từ assets; gradient chỉ là dự phòng khi
        // ảnh chưa nạp được.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF1B3A4B)],
          ),
          image: DecorationImage(
            image: AssetImage('assets/images/pet_detail_screen/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _loading || _creature == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        child: Column(
                          children: [
                            _buildHero(),
                            // const SizedBox(height: 12),
                            // _buildStatsPanel(),
                            const SizedBox(height: 8),
                            _buildStarPanel(),
                            const SizedBox(height: 8),
                            _buildEvolutionPanel(),
                            const SizedBox(height: 8),
                            _buildSkillPanel(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Image.asset(
              'assets/images/back_button/back2.png',
              width: 46,
              height: 46,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFFF6E6C5),
                size: 26,
              ),
            ),
          ),
          Expanded(
            child: Center(child: _TitleBanner(title: _creature!.name)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleButton(
                color: _kCream,
                icon: Icons.more_vert_rounded,
                iconColor: _kInk,
                onTap: () => _comingSoon('Thông tin'),
              ),
              const SizedBox(height: 2),
              const Text(
                'Thông tin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────

  /// Phần hình bên trong thẻ: nếu thú có file lottie cho giai đoạn hiện tại thì
  /// phủ kín thẻ; nếu không (hoặc nạp lỗi) thì hiện ảnh nền card + ảnh thú tĩnh.
  Widget _buildCardVisual(Creature c, double cardHeight) {
    final scene = _buildCardScene(c, cardHeight);
    final lottiePath = CreatureRepository.lottieAsset(c.id, stage: _stage);
    if (lottiePath == null) return scene;
    return Lottie.asset(
      lottiePath,
      fit: BoxFit.cover,
      // File lottie của thú là JSON thuần (assets/lotties/pet) nên dùng decoder
      // mặc định, không phải dotLottie.
      // Không có file lottie cho giai đoạn này → rơi về cảnh nền + ảnh tĩnh.
      errorBuilder: (_, _, _) => scene,
    );
  }

  /// Cảnh nền card + thú tĩnh đứng trên bệ (dùng khi không có lottie).
  Widget _buildCardScene(Creature c, double cardHeight) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/pet_detail_screen/card_background.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
              ),
            ),
          ),
        ),
        // Hào quang sau lưng thú.
        Align(
          alignment: const Alignment(0.18, 0.05),
          child: Container(
            width: cardHeight * 0.78,
            height: cardHeight * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kGold.withValues(alpha: 0.40),
                  _kGold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Thú đứng trên bệ.
        Align(
          alignment: const Alignment(0.18, 0.58),
          child: Image.asset(
            CreatureRepository.imageAsset(c.id, stage: _stage),
            height: cardHeight * 0.62,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              CreatureRepository.defaultImage,
              height: cardHeight * 0.62,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    final c = _creature!;
    // Thẻ trưng bày tỉ lệ 4:3: khung giấy da bo góc + viền vàng kép. Bên trong
    // là lottie phủ kín thẻ (nếu có) hoặc cảnh nền + ảnh thú; nút chức năng đè
    // ở cột trái.
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, cons) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _buildCardVisual(c, cons.maxHeight),
                  // Viền vàng mảnh bên trong tạo cảm giác khung kép.
                  Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.85),
                        width: 2,
                      ),
                    ),
                  ),
                  // Tên + chip đảo + nút chức năng (cột bên trái).
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Khung "Độ hiếm" + tên độ hiếm (khung lấy từ assets,
                        // chia theo từng cấp độ hiếm).
                        _RarityFrame(rarity: c.rarity),
                        const SizedBox(height: 4),
                        // Chip đảo (nền kem, icon đảo + tên đảo rút gọn).
                        _Pill(
                          color: _kCream,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/pet_detail_screen/icon_island.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Text(
                                  '🏝️',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Đảo ${_islandShortVi[c.island] ?? c.island}',
                                style: const TextStyle(
                                  color: _kInk,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  // Widget _buildStatsPanel() {
  //   final s = _stats!;
  //   return _Panel(
  //     child: Row(
  //       children: [
  //         // Đảo của thú.
  //         Column(
  //           children: [
  //             const Text(
  //               'Đảo',
  //               style: TextStyle(
  //                 color: _kInk,
  //                 fontSize: 12,
  //                 fontWeight: FontWeight.w800,
  //               ),
  //             ),
  //             const SizedBox(height: 6),
  //             Image.asset(
  //               'assets/images/pet_detail_screen/icon_island.png',
  //               width: 40,
  //               height: 40,
  //               fit: BoxFit.contain,
  //               errorBuilder: (_, _, _) =>
  //                   const Text('🏝️', style: TextStyle(fontSize: 30)),
  //             ),
  //             const SizedBox(height: 6),
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  //               decoration: BoxDecoration(
  //                 color: _kBlue,
  //                 borderRadius: BorderRadius.circular(10),
  //               ),
  //               child: Text(
  //                 _islandShortVi[_creature!.island] ?? _creature!.island,
  //                 style: const TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 11,
  //                   fontWeight: FontWeight.w800,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(width: 6),
  //         Expanded(
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceAround,
  //             children: [
  //               _stat('⚔️', 'Sức mạnh', s.power, s.powerGain),
  //               _stat('❤️', 'HP', s.hp, s.hpGain),
  //               _stat('🛡️', 'Phòng thủ', s.defense, s.defenseGain),
  //               _stat('🪽', 'Tốc độ', s.speed, s.speedGain),
  //             ],
  //           ),
  //         ),
  //         GestureDetector(
  //           onTap: () => _comingSoon('Chi tiết chỉ số'),
  //           child: Icon(
  //             Icons.info_outline_rounded,
  //             color: _kInk.withValues(alpha: 0.6),
  //             size: 22,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _stat(String emoji, String label, int value, int gain) {
  //   String fmt(int v) =>
  //       v >= 1000 ? (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 3) : '$v';
  //   return Column(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Text(
  //         label,
  //         style: const TextStyle(
  //           color: _kInk,
  //           fontSize: 11,
  //           fontWeight: FontWeight.w800,
  //         ),
  //       ),
  //       const SizedBox(height: 2),
  //       Text(emoji, style: const TextStyle(fontSize: 20)),
  //       const SizedBox(height: 2),
  //       Text(
  //         fmt(value),
  //         style: const TextStyle(
  //           color: _kInk,
  //           fontSize: 14,
  //           fontWeight: FontWeight.w900,
  //         ),
  //       ),
  //       Text(
  //         '+$gain',
  //         style: const TextStyle(
  //           color: _kGreen,
  //           fontSize: 11,
  //           fontWeight: FontWeight.w800,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // ── Nâng cấp sao ────────────────────────────────────────────────────────

  Widget _buildStarPanel() {
    final c = _creature!;
    final s = _stats!;
    final shards = _inventory?.shards ?? 0;
    final puzzle = CreatureRepository.puzzleAsset(c.id);
    // Padding trên chừa chỗ cho tag nhô lên, tránh đè vào panel phía trên.
    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chừa chỗ cho tag "NÂNG CẤP SAO" đính ở góc trên-trái.
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Image.asset(
                          i < _stars
                              ? 'assets/images/star_active.png'
                              : 'assets/images/star_inactive.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (puzzle != null)
                      Image.asset(
                        puzzle,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Text('🧩', style: TextStyle(fontSize: 22)),
                      )
                    else
                      const Text('🧩', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mảnh ${c.name}',
                            style: const TextStyle(
                              color: _kInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _Bar(
                            progress: shards / s.shardsMax,
                            height: 14,
                            color: _kGreen,
                            label: '$shards/${s.shardsMax}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _comingSoon('Tìm mảnh'),
                      child: Image.asset(
                        'assets/images/pet_detail_screen/add_stone.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _SmallSquare(
                          icon: Icons.add_rounded,
                          onTap: () => _comingSoon('Tìm mảnh'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      label: 'Nâng sao',
                      color: _kBlue,
                      badge: true,
                      onTap: () => _comingSoon('Nâng sao'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Thu thập mảnh để tăng sao và mở khóa sức mạnh mới!',
                  style: TextStyle(
                    color: _kInk.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Tag "NÂNG CẤP SAO" đính ở góc trên-trái, đè lên viền panel.
          Positioned(
            top: 2,
            left: 2,
            child: _PanelHeader(
              icon: '⭐',
              iconAsset: 'assets/images/star_active.png',
              title: 'NÂNG CẤP SAO',
              color: const Color(0xFF804887),
              glossy: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tiến hóa ──────────────────────────────────────────────────────────────

  Widget _buildEvolutionPanel() {
    final c = _creature!;
    final s = _stats!;
    final canEvolve = s.stones >= s.stonesMax;
    // Padding trên chừa chỗ cho tag nhô lên, tránh đè vào panel phía trên.
    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chừa chỗ cho tag "TIẾN HÓA" đính ở góc trên-trái.
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    final currentIndex = _stageOrder.indexWhere(
                      (e) => e.$1 == _stage,
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _stageOrder.length; i++) ...[
                          Expanded(
                            child: _EvolutionStage(
                              label: _stageOrder[i].$2,
                              asset: CreatureRepository.imageAsset(
                                c.id,
                                stage: _stageOrder[i].$1,
                              ),
                              highlight: _stageOrder[i].$1 == _stage,
                              // Mờ các giai đoạn nằm sau giai đoạn hiện tại.
                              locked: currentIndex >= 0 && i > currentIndex,
                            ),
                          ),
                          if (i < _stageOrder.length - 1)
                            // Bù phần nhãn nằm dưới → mũi tên canh giữa tâm thẻ.
                            const Padding(
                              padding: EdgeInsets.only(
                                bottom: _EvolutionStage.labelArea,
                              ),
                              child: Icon(
                                Icons.double_arrow_rounded,
                                color: _kGold,
                                size: 26,
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Cần đá tiến hóa: ',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Image.asset(
                      'assets/images/stone_upgrade.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Text('💎', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.stones}/${s.stonesMax}',
                      style: const TextStyle(
                        color: _kRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _comingSoon('Tìm đá tiến hóa'),
                      child: Image.asset(
                        'assets/images/pet_detail_screen/add_stone.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _SmallSquare(
                          icon: Icons.add_rounded,
                          onTap: () => _comingSoon('Tìm đá tiến hóa'),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _ActionButton(
                      label: 'Tiến hóa',
                      color: canEvolve ? _kGreen : const Color(0xFFBFC4CC),
                      textColor: canEvolve
                          ? Colors.white
                          : const Color(0xFF6B7280),
                      onTap: () => _comingSoon('Tiến hóa'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tag "TIẾN HÓA" đính ở góc trên-trái, đè lên viền panel.
          Positioned(
            top: 2,
            left: 2,
            child: _PanelHeader(
              icon: '🌱',
              iconAsset: 'assets/images/pet_detail_screen/upgrade_icon.png',
              title: 'TIẾN HÓA',
              color: const Color(0xFF2a8057),
              glossy: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Kỹ năng đặc biệt ──────────────────────────────────────────────────────

  Widget _buildSkillPanel() {
    final c = _creature!;
    // Kỹ năng đặc biệt = kỹ năng của dạng trưởng thành (mạnh nhất).
    final stage = c.stages['adult'] ?? c.stages['teen'];
    return _Panel(
      child: Row(
        children: [
          Image.asset(
            'assets/images/pet_detail_screen/skill_book.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('📖', style: TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kỹ năng đặc biệt: ${stage?.name ?? c.name}',
                  style: const TextStyle(
                    color: _kBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stage?.skill ?? '',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // const SizedBox(width: 8),
          // Column(
          //   children: [
          //     _CircleButton(
          //       color: _kBlue,
          //       icon: Icons.play_arrow_rounded,
          //       onTap: () => _comingSoon('Xem thử kỹ năng'),
          //     ),
          //     const SizedBox(height: 2),
          //     const Text(
          //       'Xem thử',
          //       style: TextStyle(
          //         color: _kInk,
          //         fontSize: 10,
          //         fontWeight: FontWeight.w700,
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.iconAsset,
    this.glossy = false,
  });
  final String icon;
  final String title;
  final Color color;

  /// Nếu có → dùng ảnh asset thay cho emoji [icon].
  final String? iconAsset;

  /// true → tô gradient dọc (sáng→tối) sinh từ [color] + lớp bóng phía trên,
  /// viền sáng và bóng đổ để trông như một nút nổi bóng.
  final bool glossy;

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconAsset != null)
          Image.asset(
            iconAsset!,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Text(icon, style: const TextStyle(fontSize: 14)),
          )
        else
          Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            shadows: glossy
                ? const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );

    if (!glossy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: _radius),
        child: row,
      );
    }

    // Nút nổi bóng: gradient sáng→tối + viền sáng + bóng đổ + ánh sáng trên.
    final top = Color.lerp(color, Colors.white, 0.2)!;
    final bottom = Color.lerp(color, Colors.black, 0.1)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: _radius.topLeft,
          bottomRight: _radius.bottomRight,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, color, bottom],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          // Lớp bóng sáng phủ nửa trên tạo cảm giác bề mặt bóng.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: row,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.progress,
    required this.height,
    required this.color,
    this.label,
  });
  final double progress;
  final double height;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD8CBA8),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xFFBCA87E)),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
          if (label != null)
            Center(
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFeed7b5), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.color,
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });
  final Color color;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    );
  }
}

/// Khung hiển thị độ hiếm: khung trang trí lấy từ assets (chia theo từng cấp
/// độ hiếm) với chữ "Độ hiếm" đè lên, kèm thẻ kem ghi tên độ hiếm bên dưới.
class _RarityFrame extends StatelessWidget {
  const _RarityFrame({required this.rarity});

  /// Một trong: common | rare | epic | legendary.
  final String rarity;

  /// Bề rộng cố định của khung trong cột chức năng bên trái thẻ.
  static const double _width = 116;

  static const _frames = <String, String>{
    'common': 'assets/images/pet_detail_screen/frame_ rarity_common.png',
    'rare': 'assets/images/pet_detail_screen/frame_ rarity_rare.png',
    'epic': 'assets/images/pet_detail_screen/frame_ rarity_epic.png',
    'legendary': 'assets/images/pet_detail_screen/frame_ rarity_legendary.png',
  };

  static const _labels = <String, String>{
    'common': 'Phổ thông',
    'rare': 'Hiếm',
    'epic': 'Sử thi',
    'legendary': 'Huyền thoại',
  };

  @override
  Widget build(BuildContext context) {
    final frame = _frames[rarity] ?? _frames['common']!;
    final label = _labels[rarity] ?? _labels['common']!;
    // Dùng Stack để khung độ hiếm đè LÊN TRÊN thẻ kem: thẻ kem vẽ trước (nằm
    // dưới), khung vẽ sau (nổi lên trên), phần đáy khung che mép trên thẻ kem.
    return SizedBox(
      width: _width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Thẻ kem ghi tên độ hiếm — đẩy xuống để mép trên nằm dưới khung.
          // Padding(
          //   padding: const EdgeInsets.only(top: 42),
          //   child: Container(
          //     width: _width - 12,
          //     padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          //     decoration: BoxDecoration(
          //       color: _kCream,
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(color: _kBorder, width: 2.5),
          //       boxShadow: const [
          //         BoxShadow(
          //           color: Colors.black38,
          //           blurRadius: 4,
          //           offset: Offset(0, 2),
          //         ),
          //       ],
          //     ),
          //     child: Text(
          //       label,
          //       textAlign: TextAlign.center,
          //       maxLines: 1,
          //       style: const TextStyle(
          //         color: _kInk,
          //         fontSize: 14,
          //         fontWeight: FontWeight.w900,
          //       ),
          //     ),
          //   ),
          // ),
          // Khung độ hiếm (ảnh asset) + chữ "Độ hiếm" đè ở phần thân khung,
          // canh xuống dưới ngôi sao trang trí phía trên.
          SizedBox(
            width: _width,
            child: AspectRatio(
              aspectRatio: 430 / 205,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    frame,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.42),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallSquare extends StatelessWidget {
  const _SmallSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
    this.badge = false,
  });
  final String label;
  final Color color;
  final Color textColor;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Nút bóng 3D: gradient sáng→tối sinh từ [color], viền tối + bóng đổ,
    // ánh sáng phủ nửa trên.
    final top = Color.lerp(color, Colors.white, 0.40)!;
    final bottom = Color.lerp(color, Colors.black, 0.18)!;
    final outline = Color.lerp(color, Colors.black, 0.30)!;
    final lightText = textColor.computeLuminance() > 0.6;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, color, bottom],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: const Color(0xFFA57649), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Ánh sáng bóng phủ nửa trên.
                Positioned(
                  top: 1.5,
                  left: 1.5,
                  right: 1.5,
                  height: 38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: lightText
                              ? outline
                              : Colors.white.withValues(alpha: 0.6),
                          blurRadius: 1.5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (badge)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvolutionStage extends StatelessWidget {
  const _EvolutionStage({
    required this.label,
    required this.asset,
    this.highlight = false,
    this.locked = false,
  });
  final String label;
  final String asset;

  /// Giai đoạn hiện tại của thú → tô viền vàng nổi bật.
  final bool highlight;

  /// Giai đoạn nằm sau giai đoạn hiện tại → làm mờ + xám ảnh thú.
  final bool locked;

  /// Khoảng cách nhỏ giữa thẻ và nhãn giai đoạn đặt bên dưới.
  static const double labelGap = 6;

  /// Phần chiều cao chiếm bởi khoảng cách + nhãn bên dưới thẻ. Dùng để canh
  /// mũi tên giữa nằm đúng tâm thẻ (bù lại phần nhãn nằm dưới).
  static const double labelArea = 22;

  /// Khi [locked]: làm mờ nhòe (blur) ảnh thú để không nhìn rõ giai đoạn
  /// chưa mở khóa.
  Widget _maybeDim(Widget child) {
    if (!locked) return child;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFBEC), Color(0xFFF1E1B9)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? _kGold : _kBorder,
              width: highlight ? 3 : 2,
            ),
            boxShadow: [
              if (highlight)
                BoxShadow(
                  color: _kGold.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: _maybeDim(
              Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Image.asset(
                  CreatureRepository.defaultImage,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        // Nhãn giai đoạn đặt bên dưới thẻ, cách thẻ 1 khoảng nhỏ.
        const SizedBox(height: labelGap),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: _kInk,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Color(0xFFFFFBEC), blurRadius: 3),
              Shadow(color: Color(0xFFFFFBEC), blurRadius: 3),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banner tiêu đề cầu kỳ (giống màn đội hình): khuôn lục giác dẹt vẽ vector,
/// nền xanh gradient, viền vàng kép, 4 vai gắn hạt kim cương vàng.
class _TitleBanner extends StatelessWidget {
  const _TitleBanner({required this.title});

  final String title;

  static const _gold = Color(0xFFE9B949);
  static const _goldLight = Color(0xFFF6D87A);
  static const _goldDark = Color(0xFFC98A1E);

  /// Độ "nhô" của 2 đầu nhọn (khoảng cách từ mũi nhọn tới mép phẳng trên/dưới).
  static const double _point = 18;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: const _PointedBannerPainter(point: _point),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _point + 16,
              12,
              _point + 16,
              12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pets_rounded,
                  color: Color(0xFFFAD073),
                  size: 28,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFFCE9CA),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 4 hạt kim cương ở vai khuôn (nơi mép phẳng gặp đầu nhọn).
        const Positioned(top: -3, left: _point - 6, child: _BannerDiamond()),
        const Positioned(top: -3, right: _point - 6, child: _BannerDiamond()),
        const Positioned(bottom: -3, left: _point - 6, child: _BannerDiamond()),
        const Positioned(
          bottom: -3,
          right: _point - 6,
          child: _BannerDiamond(),
        ),
      ],
    );
  }
}

/// Vẽ khuôn lục giác dẹt + viền vàng kép cho [_TitleBanner]. Mọi đỉnh được bo
/// cong (bezier) nên 2 đầu nhọn và các vai đều mềm mại.
class _PointedBannerPainter extends CustomPainter {
  const _PointedBannerPainter({required this.point});

  final double point;

  /// Bán kính bo: ở vai (mép phẳng) và ở 2 đầu nhọn (bo nhiều hơn cho mềm).
  static const double _shoulderR = 11;
  static const double _tipR = 17;

  /// Dựng đường viền lục giác đã bo cong tại từng đỉnh.
  static Path _framePath(Rect r, double pt, double sr, double tr) {
    final midY = r.center.dy;
    final pts = <Offset>[
      Offset(r.left + pt, r.top), // vai trên-trái
      Offset(r.right - pt, r.top), // vai trên-phải
      Offset(r.right, midY), // đầu nhọn phải
      Offset(r.right - pt, r.bottom), // vai dưới-phải
      Offset(r.left + pt, r.bottom), // vai dưới-trái
      Offset(r.left, midY), // đầu nhọn trái
    ];
    final radii = <double>[sr, sr, tr, sr, sr, tr];

    final path = Path();
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final cur = pts[i];
      final prev = pts[(i - 1 + n) % n];
      final next = pts[(i + 1) % n];
      final toPrev = prev - cur;
      final toNext = next - cur;
      final rA = math.min(radii[i], toPrev.distance / 2);
      final rB = math.min(radii[i], toNext.distance / 2);
      final a = cur + toPrev / toPrev.distance * rA;
      final b = cur + toNext / toNext.distance * rB;
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = _framePath(rect.deflate(2.5), point, _shoulderR, _tipR);

    // Bóng đổ nhẹ dưới khuôn.
    canvas.drawShadow(outer, Colors.black54, 4, false);

    // Nền xanh gradient.
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3E74E8), Color(0xFF1C40A6)],
        ).createShader(rect),
    );

    // Viền vàng ngoài (dày).
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..color = _TitleBanner._gold,
    );

    // Đường vàng sáng bên trong (viền kép).
    canvas.drawPath(
      _framePath(rect.deflate(8), point - 3.5, _shoulderR - 3, _tipR - 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = _TitleBanner._goldLight,
    );
  }

  @override
  bool shouldRepaint(_PointedBannerPainter oldDelegate) =>
      oldDelegate.point != point;
}

class _BannerDiamond extends StatelessWidget {
  const _BannerDiamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _TitleBanner._goldLight,
          border: Border.all(color: _TitleBanner._goldDark, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
    );
  }
}
