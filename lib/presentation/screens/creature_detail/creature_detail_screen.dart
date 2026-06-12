import 'package:flutter/material.dart';

import 'package:lottie/lottie.dart';

import '../../../core/lottie/dotlottie_decoder.dart';
import '../../../data/models/creature.dart';
import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';

// ─── Palette (parchment / cartoon game style) ─────────────────────────────────

const _kCream = Color(0xFFFFF6DE);
const _kCreamDark = Color(0xFFEAD9AE);
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
    power = (300 + seed % 200) * mult ~/ 1;
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
        // Nền rừng huyền ảo (chưa có ảnh nền riêng cho màn này).
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF1B3A4B)],
          ),
        ),
        child: SafeArea(
          child: _loading || _creature == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        child: Column(
                          children: [
                            _buildHero(),
                            const SizedBox(height: 12),
                            _buildStatsPanel(),
                            const SizedBox(height: 12),
                            _buildStarPanel(),
                            const SizedBox(height: 12),
                            _buildEvolutionPanel(),
                            const SizedBox(height: 12),
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
          _CircleButton(
            color: _kBlue,
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: const Text(
                'Thú cưng',
                style: TextStyle(
                  color: _kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
              const Text('Thông tin',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────

  /// Hiển thị thú: hoạt ảnh lottie nếu có file, không thì ảnh tĩnh.
  Widget _buildCreatureVisual(Creature c, double height) {
    final image = Image.asset(
      CreatureRepository.imageAsset(c.id, stage: _stage),
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Image.asset(CreatureRepository.defaultImage, height: height),
    );
    final lottiePath = CreatureRepository.lottieAsset(c.id, stage: _stage);
    if (lottiePath == null) return image;
    return Lottie.asset(
      lottiePath,
      height: height,
      fit: BoxFit.contain,
      decoder: dotLottieDecoder,
      // Không có file lottie cho giai đoạn này → rơi về ảnh tĩnh.
      errorBuilder: (_, _, _) => image,
    );
  }

  Widget _buildHero() {
    final c = _creature!;
    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hào quang sau lưng thú.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kGold.withValues(alpha: 0.55),
                  _kGold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Thú theo giai đoạn hiện tại: ưu tiên hoạt ảnh lottie, nếu không
          // có file lottie thì hiện ảnh tĩnh.
          _buildCreatureVisual(c, 230),

          // Tên + chip đảo + nút chức năng (góc trên-trái).
          Positioned(
            left: 4,
            top: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _comingSoon('Đổi tên'),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Chip đảo (nền kem, icon đảo + tên đảo rút gọn).
                _Pill(
                  color: _kCream,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏝️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        'Đảo ${_islandShortVi[c.island] ?? c.island}',
                        style: const TextStyle(
                            color: _kInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HeroActionButton(
                  emoji: '📕',
                  label: 'Học tập',
                  onTap: () => _comingSoon('Học tập'),
                ),
                const SizedBox(height: 12),
                _HeroActionButton(
                  emoji: '🎓',
                  label: 'Ghi nhớ',
                  onTap: () => _comingSoon('Ghi nhớ'),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStatsPanel() {
    final s = _stats!;
    return _Panel(
      child: Row(
        children: [
          // Đảo của thú.
          Column(
            children: [
              const Text('Đảo',
                  style: TextStyle(
                      color: _kInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('🏝️', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _islandShortVi[_creature!.island] ?? _creature!.island,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('⚔️', 'Sức mạnh', s.power, s.powerGain),
                _stat('❤️', 'HP', s.hp, s.hpGain),
                _stat('🛡️', 'Phòng thủ', s.defense, s.defenseGain),
                _stat('🪽', 'Tốc độ', s.speed, s.speedGain),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _comingSoon('Chi tiết chỉ số'),
            child: Icon(Icons.info_outline_rounded,
                color: _kInk.withValues(alpha: 0.6), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String label, int value, int gain) {
    String fmt(int v) => v >= 1000
        ? (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 3)
        : '$v';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: _kInk, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(fmt(value),
            style: const TextStyle(
                color: _kInk, fontSize: 14, fontWeight: FontWeight.w900)),
        Text('+$gain',
            style: const TextStyle(
                color: _kGreen, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ── Nâng cấp sao ────────────────────────────────────────────────────────

  Widget _buildStarPanel() {
    final c = _creature!;
    final s = _stats!;
    final shards = _inventory?.shards ?? 0;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: '⭐',
            title: 'NÂNG CẤP SAO',
            color: _kGold,
          ),
          const SizedBox(height: 10),
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
                    width: 30,
                    height: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('🧩', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mảnh ${c.name}',
                        style: const TextStyle(
                            color: _kInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
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
              _SmallSquare(
                  icon: Icons.add_rounded,
                  onTap: () => _comingSoon('Tìm mảnh')),
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
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Tiến hóa ──────────────────────────────────────────────────────────────

  Widget _buildEvolutionPanel() {
    final c = _creature!;
    final s = _stats!;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(icon: '🌱', title: 'TIẾN HÓA', color: _kGreen),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _stageOrder.length; i++) ...[
                Expanded(
                  child: _EvolutionStage(
                    label: _stageOrder[i].$2,
                    asset: CreatureRepository.imageAsset(c.id,
                        stage: _stageOrder[i].$1),
                  ),
                ),
                if (i < _stageOrder.length - 1)
                  const Icon(Icons.arrow_forward_rounded,
                      color: _kGold, size: 24),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Cần đá tiến hóa: ',
                  style: TextStyle(
                      color: _kInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const Text('💎', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text('${s.stones}/${s.stonesMax}',
                  style: const TextStyle(
                      color: _kRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              _SmallSquare(
                  icon: Icons.add_rounded,
                  onTap: () => _comingSoon('Tìm đá tiến hóa')),
              const Spacer(),
              _ActionButton(
                label: 'Tiến hóa',
                color: s.stones >= s.stonesMax ? _kGreen : _kCreamDark,
                textColor: s.stones >= s.stonesMax ? Colors.white : _kInk,
                onTap: () => _comingSoon('Tiến hóa'),
              ),
            ],
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
          const Text('📖', style: TextStyle(fontSize: 34)),
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
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  stage?.skill ?? '',
                  style: const TextStyle(
                      color: _kInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _CircleButton(
                color: _kBlue,
                icon: Icons.play_arrow_rounded,
                onTap: () => _comingSoon('Xem thử kỹ năng'),
              ),
              const SizedBox(height: 2),
              const Text('Xem thử',
                  style: TextStyle(
                      color: _kInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
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
  const _PanelHeader(
      {required this.icon, required this.title, required this.color});
  final String icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
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
              child: Text(label!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white70, width: 1.5),
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

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton(
      {required this.emoji, required this.label, required this.onTap});
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
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
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
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
                child: const Text('!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvolutionStage extends StatelessWidget {
  const _EvolutionStage({required this.label, required this.asset});
  final String label;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: _kInk, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCreamDark, width: 2),
          ),
          child: Image.asset(
            asset,
            height: 56,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Image.asset(CreatureRepository.defaultImage, height: 56),
          ),
        ),
      ],
    );
  }
}
