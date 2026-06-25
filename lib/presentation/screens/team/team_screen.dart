import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/creature.dart';
import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/team_repository.dart';
import '../../../data/services/creature_stats.dart';

// ─── Palette (parchment / cartoon game style) ─────────────────────────────────

const _kCream = Color(0xFFFEE5BB);
const _kCreamDark = Color(0xFFEFDDB2);
const _kBorder = Color(0xFFC9A05E);
const _kInk = Color(0xFF1E3A5F);
const _kBlue = Color(0xFF2F6BFF);
const _kGold = Color(0xFFF5B91E);
const _kMuted = Color(0xFF9C8B66);

const _bgAsset = 'assets/images/your_team/background.png';
const _titleHeaderAsset = 'assets/images/your_team/title_header.png';
const _buttonAsset = 'assets/images/your_team/button.png';
const _frameAllAsset = 'assets/images/your_team/frame_all.png';
const _labelFrameAsset = 'assets/images/your_team/label_frame.png';
const _emptyFrameAsset = 'assets/images/your_team/frame_empty_pet.png';
const _powerIconAsset = 'assets/images/your_team/icon_power.png';
const _noPetAsset = 'assets/images/your_team/no_pet.png';

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

class _RarityStyle {
  const _RarityStyle(this.label, this.color);
  final String label;
  final Color color;
}

const _rarity = <String, _RarityStyle>{
  'common': _RarityStyle('Thường', Color(0xFF7C8B9B)),
  'rare': _RarityStyle('Hiếm', Color(0xFF2563EB)),
  'epic': _RarityStyle('Sử thi', Color(0xFF7C3AED)),
  'legendary': _RarityStyle('Huyền thoại', Color(0xFFE08F00)),
};

_RarityStyle _rarityOf(Creature c) => _rarity[c.rarity] ?? _rarity['common']!;

/// Màn chọn đội hình thú để hỗ trợ vượt màn học (tối đa 3 thú).
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;

  /// Thú người chơi đang sở hữu (đã ấp).
  List<Creature> _owned = const [];

  /// Dữ liệu kho theo creature_id (sao, giai đoạn, mảnh) — lấy từ SQLite.
  Map<String, CreatureInventoryEntry> _inv = const {};

  /// creature_id trong đội hình, theo thứ tự ô.
  List<String> _selected = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creatures = await CreatureRepository.instance.loadCreatures();
    final entries = await InventoryRepository.instance.getAllCreatures();
    final savedTeam = await TeamRepository.instance.getTeam();
    if (!mounted) return;
    // Chỉ giữ thú đã ấp / sở hữu, tra cứu nhanh theo id.
    final inv = <String, CreatureInventoryEntry>{
      for (final e in entries)
        if (e.hatched) e.creatureId: e,
    };
    final owned = [
      for (final c in creatures)
        if (inv.containsKey(c.id)) c,
    ];
    // Bỏ khỏi đội hình các thú không còn sở hữu.
    final selected = [
      for (final id in savedTeam)
        if (inv.containsKey(id)) id,
    ];
    setState(() {
      _inv = inv;
      _owned = owned;
      _selected = selected;
      _loading = false;
    });
  }

  Creature? _byId(String id) {
    for (final c in _owned) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Giai đoạn tiến hóa của thú [id] theo kho ('baby' nếu chưa rõ).
  String _stageOf(String id) => _inv[id]?.stage ?? 'baby';

  /// Thú sở hữu chưa nằm trong đội hình (hiện ở lưới "Thú sở hữu").
  List<Creature> get _available => [
    for (final c in _owned)
      if (!_selected.contains(c.id)) c,
  ];

  int get _totalPower {
    var sum = 0;
    for (final id in _selected) {
      final c = _byId(id);
      if (c != null) sum += creaturePower(c);
    }
    return sum;
  }

  void _persist() => TeamRepository.instance.saveTeam(_selected);

  void _add(Creature c) {
    if (_selected.contains(c.id)) return;
    if (_selected.length >= TeamRepository.maxSlots) {
      _toast('Đội hình đã đủ ${TeamRepository.maxSlots} thú');
      return;
    }
    setState(() => _selected = [..._selected, c.id]);
    _persist();
  }

  void _remove(String id) {
    setState(
      () => _selected = [
        for (final e in _selected)
          if (e != id) e,
      ],
    );
    _persist();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kInk,
        ),
      );
  }

  Future<void> _enterLevel() async {
    if (_selected.isEmpty) return;
    await context.push('/learning-island');
    // Thú có thể đã tiến hóa / đổi giai đoạn trong màn chơi → nạp lại để ảnh
    // luôn khớp giai đoạn hiện tại.
    if (mounted) _load();
  }

  Future<void> _goLearn() async {
    await context.push('/learning-island');
    if (mounted) _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _bgAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF1B3A2A)),
          ),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                          child: _buildPanel(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _RoundBackButton(onTap: () => Navigator.of(context).pop()),
          const Expanded(child: Center(child: _TitleBanner())),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _frameAllAsset,
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFEE5BB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorder, width: 3),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: _Section(
                  title: 'Đội hình ra trận',
                  framed: false,
                  child: _buildLineup(),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Column(
                  children: [
                    _buildPowerBar(),
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Thú sở hữu',
                      child: _owned.isEmpty
                          ? _buildEmptyOwned()
                          : _buildOwnedGrid(),
                    ),
                    const SizedBox(height: 12),
                    _buildFooterHint(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineup() {
    return SizedBox(
      height: 186,
      child: Row(
        children: [
          for (var i = 0; i < TeamRepository.maxSlots; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _LineupSlot(
                slotNumber: i + 1,
                creature: i < _selected.length ? _byId(_selected[i]) : null,
                stage: i < _selected.length ? _stageOf(_selected[i]) : 'baby',
                onRemove: i < _selected.length
                    ? () => _remove(_selected[i])
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPowerBar() {
    final canEnter = _selected.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 2),
      ),
      child: Row(
        children: [
          Image.asset(
            _powerIconAsset,
            width: 40,
            height: 40,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.shield_rounded, color: _kGold, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tổng sức mạnh',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _kInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatThousands(_totalPower),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFC0392B),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(width: 1.5, height: 32, color: _kCreamDark),
                const SizedBox(width: 4),
                Image.asset(
                  'assets/images/your_team/pet_icon.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, _, _) =>
                      const Text('🐾', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 3),
                Text(
                  '${_selected.length}/${TeamRepository.maxSlots}',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _GoldButton(label: 'Vào màn', enabled: canEnter, onTap: _enterLevel),
        ],
      ),
    );
  }

  Widget _buildOwnedGrid() {
    final items = _available;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Tất cả thú đã ở trong đội hình 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        // mainAxisSpacing: 0,
        crossAxisSpacing: 2,
        // Chiều cao pixel cố định → mọi thẻ cao bằng nhau, không phụ thuộc nội dung.
        mainAxisExtent: 188,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _OwnedCard(
        creature: items[i],
        stage: _stageOf(items[i].id),
        onChoose: () => _add(items[i]),
      ),
    );
  }

  Widget _buildEmptyOwned() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Image.asset(
            _noPetAsset,
            height: 150,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('🥚', style: TextStyle(fontSize: 90)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn chưa sở hữu thú nào',
            style: TextStyle(
              color: _kInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hoàn thành màn học, nhận trứng\nvà ấp trứng để mở khóa thú đầu tiên.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _goLearn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                '📖  Đi học ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterHint() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('💡 ', style: TextStyle(fontSize: 14)),
        Flexible(
          child: Text(
            'Chọn tối đa 3 thú để hỗ trợ vượt màn chơi.',
            style: TextStyle(
              color: _kMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section frame with overlapping title chip ────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.framed = true,
  });
  final String title;
  final Widget child;

  /// true → có khung viền + nền kem riêng; false → trong suốt, hòa vào panel.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(6, 24, 6, 12),
          decoration: framed
              ? BoxDecoration(
                  color: _kCream,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kBorder, width: 2),
                )
              : null,
          child: Column(children: [SizedBox(height: 8), child]),
        ),
        Positioned(
          top: -7,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 220,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      _labelFrameAsset,
                      fit: BoxFit.fill,
                      errorBuilder: (_, _, _) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7D39B),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _kBorder, width: 2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 52),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Lineup slot ──────────────────────────────────────────────────────────────

class _LineupSlot extends StatelessWidget {
  const _LineupSlot({
    required this.slotNumber,
    required this.creature,
    required this.stage,
    required this.onRemove,
  });

  final int slotNumber;
  final Creature? creature;

  /// Giai đoạn tiến hóa ('baby' | 'teen' | 'adult') lấy từ kho.
  final String stage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = creature;
    if (c == null) return _buildEmpty();

    final r = _rarityOf(c);
    return GestureDetector(
      onTap: onRemove,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF3B0),
                  Color(0xFFF5C84B),
                  Color(0xFFD9A21F),
                  Color(0xFFFFE588),
                ],
                stops: [0.0, 0.4, 0.7, 1.0],
              ),
              boxShadow: [
                // Glow vàng tạo cảm giác neon/lấp lánh.
                BoxShadow(
                  color: const Color(0xFFFFD24D).withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Nửa trên: nền gradient theo độ hiếm + ảnh thú.
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(r.color, Colors.white, 0.90)!,
                                Color.lerp(r.color, Colors.white, 0.52)!,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                          child: Image.asset(
                            CreatureRepository.imageAsset(c.id, stage: stage),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Image.asset(
                              CreatureRepository.defaultImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Đáy: nền kem #FDE5BF + chip + sức mạnh.
                      Container(
                        width: double.infinity,
                        height: 58,
                        color: const Color(0xFFFDE5BF),
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _RarityChip(style: r, small: true),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  _powerIconAsset,
                                  width: 15,
                                  height: 15,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: _kGold,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  formatThousands(creaturePower(c)),
                                  style: const TextStyle(
                                    color: _kInk,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Tên đè lên đường ngăn cách 2 vùng.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 44,
                    child: Center(child: _namePlate(c.name)),
                  ),
                ],
              ),
            ),
          ),
          _SlotNumberBadge(number: slotNumber),
          // Nút bỏ chọn (góc phải).
          const Positioned(top: -2, right: -2, child: _CheckBadge()),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Khung frame_empty_pet làm ảnh nền phủ cả ô; chữ đặt đè lên phía dưới.
        DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_emptyFrameAsset),
              fit: BoxFit.fill,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Chưa có thú',
                  maxLines: 1,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ấp trứng để mở khóa',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        _SlotNumberBadge(number: slotNumber),
      ],
    );
  }

  Widget _namePlate(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1D5EB4),
        borderRadius: BorderRadius.circular(9),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          name,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Owned creature card ──────────────────────────────────────────────────────

class _OwnedCard extends StatelessWidget {
  const _OwnedCard({
    required this.creature,
    required this.stage,
    required this.onChoose,
  });

  final Creature creature;

  /// Giai đoạn tiến hóa ('baby' | 'teen' | 'adult') lấy từ kho.
  final String stage;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final r = _rarityOf(creature);
    final islandVi = _islandShortVi[creature.island] ?? 'Bí Ẩn';
    final frameAsset = 'assets/images/card_frame/${creature.rarity}_card.png';

    return GestureDetector(
      onTap: onChoose,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            children: [
              // Khung thẻ theo độ hiếm — phủ kín ô để mọi thẻ cùng kích thước.
              Positioned.fill(
                child: Image.asset(
                  frameAsset,
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => Container(
                    decoration: BoxDecoration(
                      color: _kCream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: r.color, width: 2),
                    ),
                  ),
                ),
              ),
              // Ảnh thú nằm gọn nửa trên khung.
              Positioned(
                top: 0,
                left: w * 0.10,
                right: w * 0.10,
                height: h * 0.6,
                child: Image.asset(
                  CreatureRepository.imageAsset(creature.id, stage: stage),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Image.asset(
                    CreatureRepository.defaultImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Container nội dung — đè lên phần dưới ảnh thú.
              Positioned(
                left: w * 0.06,
                right: w * 0.06,
                bottom: h * 0.05,
                child: _contentPanel(r, islandVi),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contentPanel(_RarityStyle r, String islandVi) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 6),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.color.withValues(alpha: 0.55), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              creature.name,
              maxLines: 1,
              style: const TextStyle(
                color: _kInk,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 3),
          _RarityChip(style: r, small: true),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏝️', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  'Đảo $islandVi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.style, this.small = false});
  final _RarityStyle style;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        style.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9.5 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SlotNumberBadge extends StatelessWidget {
  const _SlotNumberBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -10,
      left: -10,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 34,
              color: Color(0xFFF2A93B),
              shadows: [
                Shadow(
                  color: Color(0x66000000),
                  blurRadius: 1.5,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF6E4A22),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF2470D9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB47B33), width: 2),
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 15,
        fontWeight: FontWeight(900),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: SizedBox(
          width: 78,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  _buttonAsset,
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: enabled ? _kGold : const Color(0xFFC9C2B0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: enabled ? _kInk : const Color(0xFF8A8474),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      shadows: enabled
                          ? const [
                              Shadow(
                                color: Colors.white70,
                                blurRadius: 1.5,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBanner extends StatelessWidget {
  const _TitleBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 246,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              _titleHeaderAsset,
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 34),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets_rounded, color: Color(0xFFFAD073), size: 27),
                SizedBox(width: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Đội hình thú',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFFFCE9CA),
                        fontSize: 20,
                        fontWeight: FontWeight(900),
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
        ],
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
