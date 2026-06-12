import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/creature.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/progress_repository.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kInk = Color(0xFF1E3A5F);
const _kBlue = Color(0xFF2F6BFF);
const _kSkyTop = Color(0xFF3D8BFF);
const _kSkyBottom = Color(0xFF7FB9F2);
const _kPanel = Color(0xFFF4F7FC);

/// Kiểu hiển thị theo độ hiếm. Khung thẻ là ảnh trong assets (đã vẽ sẵn
/// nền, viền, ô tròn góc trên-trái và badge tên độ hiếm góc dưới-phải).
class _RarityStyle {
  const _RarityStyle(
    this.label,
    this.badge,
    this.frameAsset,
    this.stars,
    this.chipCenterY,
  );

  final String label;
  final Color badge;
  final String frameAsset;
  final int stars; // số sao tô sáng trên thẻ (flair theo độ hiếm)

  /// Tâm dọc của chip độ hiếm in sẵn trong ảnh khung (tỷ lệ chiều cao,
  /// đo từ ảnh) — dùng để căn hàng sao thẳng hàng với chip.
  final double chipCenterY;
}

const _rarityStyles = <String, _RarityStyle>{
  'common': _RarityStyle(
    'Common',
    Color(0xFF7C8B9B),
    'assets/images/card_frame/common_card.png',
    2,
    0.862,
  ),
  'rare': _RarityStyle(
    'Rare',
    Color(0xFF2563EB),
    'assets/images/card_frame/rare_card.png',
    3,
    0.870,
  ),
  'epic': _RarityStyle(
    'Epic',
    Color(0xFF9333EA),
    'assets/images/card_frame/epic_card.png',
    4,
    0.887,
  ),
  'legendary': _RarityStyle(
    'Legendary',
    Color(0xFFE08F00),
    'assets/images/card_frame/legendary_card.png',
    5,
    0.878,
  ),
};

const _islandEmoji = <String, String>{
  'Learning Island': '📖',
  'Home Village': '🏠',
  'Ocean Kingdom': '💧',
  'Nature Island': '🌿',
  'City Island': '🪙',
  'Adventure Island': '🧭',
  'Life Island': '❤️',
  'Entertainment Island': '🎬',
  'Festival Island': '✨',
};

enum _SortMode { number, name, rarity }

const _rarityOrder = ['legendary', 'epic', 'rare', 'common'];

/// Màn hình bộ sưu tập thú cưng (theo mockup; chưa gồm bottom bar).
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Creature> _creatures = const [];
  UserProfile? _profile;

  /// creature_id → số sao, cho các thú người chơi đang sở hữu (đọc từ DB).
  Map<String, int> _ownedStars = const {};

  String _rarityTab = 'all';
  String? _islandFilter;
  _SortMode _sort = _SortMode.number;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final creatures = await CreatureRepository.instance.loadCreatures();
    final profile = await ProgressRepository.instance.getProfile();
    final owned = await InventoryRepository.instance.getAllCreatures();
    if (!mounted) return;
    setState(() {
      _creatures = creatures;
      _profile = profile;
      _ownedStars = {
        for (final e in owned)
          if (e.hatched) e.creatureId: e.stars,
      };
      _loading = false;
    });
  }

  int get _unlockedCount => _ownedStars.length;

  List<(int, Creature)> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    final items = [
      for (var i = 0; i < _creatures.length; i++)
        if (_rarityTab == 'all' || _creatures[i].rarity == _rarityTab)
          if (_islandFilter == null || _creatures[i].island == _islandFilter)
            if (query.isEmpty ||
                _creatures[i].name.toLowerCase().contains(query))
              (i, _creatures[i]),
    ];
    switch (_sort) {
      case _SortMode.number:
        break; // giữ thứ tự trong JSON
      case _SortMode.name:
        items.sort((a, b) => a.$2.name.compareTo(b.$2.name));
      case _SortMode.rarity:
        items.sort((a, b) => _rarityOrder
            .indexOf(a.$2.rarity)
            .compareTo(_rarityOrder.indexOf(b.$2.rarity)));
    }
    return items;
  }

  void _cycleSort() {
    setState(() {
      _sort = _SortMode
          .values[(_sort.index + 1) % _SortMode.values.length];
    });
  }

  void _pickIsland() {
    final islands = {for (final c in _creatures) c.island}.toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final island in [null, ...islands])
              ListTile(
                leading: Text(
                  island == null ? '🌏' : _islandEmoji[island] ?? '🏝️',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  island ?? 'All Islands',
                  style: const TextStyle(
                    color: _kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: _islandFilter == island
                    ? const Icon(Icons.check_rounded, color: _kBlue)
                    : null,
                onTap: () {
                  setState(() => _islandFilter = island);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Creature c) {
    context.push('/creature/${c.id}');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kSkyTop, _kSkyBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _kPanel,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(26)),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            _buildRarityTabs(),
                            const SizedBox(height: 10),
                            _buildToolbar(),
                            const SizedBox(height: 4),
                            Expanded(child: _buildGrid()),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundButton(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Collection ✨',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              Text(
                '🃏 $_unlockedCount / ${_creatures.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          _CoinChip(coins: _profile?.coins ?? 0),
        ],
      ),
    );
  }

  Widget _buildRarityTabs() {
    const tabs = [
      ('all', 'All', _kBlue),
      ('common', 'Common', Color(0xFF7C8B9B)),
      ('rare', 'Rare', Color(0xFF2563EB)),
      ('epic', 'Epic', Color(0xFF9333EA)),
      ('legendary', 'Legendary', Color(0xFFE08F00)),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (key, label, color) = tabs[i];
          final selected = _rarityTab == key;
          return GestureDetector(
            onTap: () => setState(() => _rarityTab = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _kBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _kBlue : const Color(0xFFD8E0EA),
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: const Color(0xFFD8E0EA), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _kInk, size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search creatures...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9AA7B5),
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: Icons.filter_alt_rounded,
            label: 'Filter',
            active: _islandFilter != null,
            onTap: _pickIsland,
          ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: Icons.swap_vert_rounded,
            label: switch (_sort) {
              _SortMode.number => 'Sort',
              _SortMode.name => 'A-Z',
              _SortMode.rarity => 'Rarity',
            },
            active: _sort != _SortMode.number,
            onTap: _cycleSort,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final items = _visible;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No creatures found 😢',
          style: TextStyle(
            color: _kInk,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Khớp tỷ lệ ảnh khung thẻ (1086×1448).
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (_, creature) = items[i];
        final owned = _ownedStars.containsKey(creature.id);
        return _CreatureCard(
          creature: creature,
          unlocked: owned,
          stars: _ownedStars[creature.id] ?? 0,
          onTap: () => _showDetail(creature),
        );
      },
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _CreatureCard extends StatelessWidget {
  const _CreatureCard({
    required this.creature,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final Creature creature;
  final bool unlocked;

  /// Số sao thực tế của thú (từ DB); 0 nếu chưa sở hữu.
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _rarityStyles[creature.rarity] ?? _rarityStyles['common']!;

    // Khung ảnh + nội dung đặt theo tỷ lệ khung (ô tròn trên-trái và badge
    // độ hiếm dưới-phải đã vẽ sẵn trong ảnh khung).
    Widget card = LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(style.frameAsset, fit: BoxFit.fill),
            // Icon đảo trong ô tròn của khung (ô tròn đo từ ảnh khung:
            // trái ≈7.5%w, trên ≈5.2%h, đường kính ≈11.5%w).
            Positioned(
              left: w * 0.075,
              top: h * 0.052,
              width: w * 0.115,
              height: w * 0.115,
              child: Center(
                child: Text(
                  _islandEmoji[creature.island] ?? '🏝️',
                  style: TextStyle(fontSize: w * 0.062),
                ),
              ),
            ),
            // Ảnh thú ở giữa khung.
            Positioned(
              left: w * 0.14,
              right: w * 0.14,
              top: h * 0.16,
              bottom: h * 0.27,
              child: Image.asset(
                CreatureRepository.imageAsset(creature.id),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Image.asset(
                    CreatureRepository.defaultImage,
                    fit: BoxFit.contain),
              ),
            ),
            // Tên: ngay trên hàng sao, tự co chữ để luôn hiện đầy đủ.
            Positioned(
              left: w * 0.09,
              right: w * 0.09,
              bottom: h * (1 - style.chipCenterY) + w * 0.036 + h * 0.012,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    creature.name,
                    maxLines: 1,
                    style: TextStyle(
                      color: _kInk,
                      fontSize: w * 0.078,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            // Hàng sao: căn tâm dọc trùng với chip độ hiếm in sẵn của khung.
            Positioned(
              left: w * 0.09,
              top: h * style.chipCenterY - w * 0.036,
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: EdgeInsets.only(right: w * 0.008),
                      child: Image.asset(
                        unlocked && i < stars
                            ? 'assets/images/star_active.png'
                            : 'assets/images/star_inactive.png',
                        width: w * 0.072,
                        height: w * 0.072,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (!unlocked) {
      // Khóa: thẻ chuyển xám, phủ lớp đen mờ và đặt ổ khóa lớn ở giữa.
      card = Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: card,
          ),
          // Lớp phủ đen mờ.
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          // Ổ khóa ở giữa thẻ.
          Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: const Icon(Icons.lock_rounded,
                  color: Colors.white, size: 32),
            ),
          ),
        ],
      );
    }

    return GestureDetector(onTap: onTap, child: card);
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.child, required this.onTap});
  final Widget child;
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
          color: _kBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1D3557).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 5),
          Text(
            '$coins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: active ? _kBlue : const Color(0xFFD8E0EA),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : _kBlue),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _kInk,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
