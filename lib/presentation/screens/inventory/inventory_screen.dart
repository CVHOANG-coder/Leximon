import 'package:flutter/material.dart';

import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../egg_hatch/egg_hatch_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kInk = Color(0xFF1E3A5F);
const _kBlue = Color(0xFF2F6BFF);
const _kCream = Color(0xFFFFF6DE);
const _kCreamBorder = Color(0xFFE7D9B0);
const _kBrown = Color(0xFF8B5A2B);
const _kMuted = Color(0xFF8A8174);

enum _Tab { all, items, pieces }

class _InvItem {
  const _InvItem(this.name, this.desc, this.count, this.asset, {this.eggType});
  final String name;
  final String desc;
  final int count;
  final String asset;

  /// 'common' | 'rare' nếu vật phẩm là trứng (bấm để mở), null nếu không.
  final String? eggType;
}

class _PieceItem {
  const _PieceItem(this.name, this.rarity, this.owned, this.required, this.asset);
  final String name;
  final String rarity; // common/rare/epic/legendary
  final int owned;
  final int required;
  final String asset;
}

const _kItemSlotsMax = 50;
const _kPieceSlotsMax = 80;

/// Số mảnh ghép cần để triệu hồi 1 creature.
const _kShardsPerSummon = 20;

class _RarityStyle {
  const _RarityStyle(this.label, this.bg, this.text, this.bar);
  final String label;
  final Color bg;
  final Color text;
  final Color bar;
}

const _rarity = <String, _RarityStyle>{
  'common':
      _RarityStyle('Thường', Color(0xFFEDEDED), Color(0xFF555555), Color(0xFF9DD06A)),
  'rare':
      _RarityStyle('Hiếm', Color(0xFFDFEEFF), Color(0xFF2563EB), Color(0xFF3F90F5)),
  'epic':
      _RarityStyle('Sử thi', Color(0xFFEBDDFB), Color(0xFF7C3AED), Color(0xFF9B66E6)),
  'legendary': _RarityStyle(
      'Huyền thoại', Color(0xFFFFE9A8), Color(0xFFB07A0F), Color(0xFFEAB13A)),
};

/// Màn "Túi đồ" — kho vật phẩm + mảnh ghép thú.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  _Tab _tab = _Tab.all;

  bool _loading = true;
  List<_InvItem> _items = const [];
  List<_PieceItem> _pieces = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProgressRepository.instance.getProfile();
    final creatures = await CreatureRepository.instance.loadCreatures();
    final owned = await InventoryRepository.instance.getAllCreatures();
    final byId = {for (final c in creatures) c.id: c};

    final items = <_InvItem>[
      _InvItem('Rương quà', 'Mở để nhận phần thưởng\nngẫu nhiên.',
          profile.chest, 'assets/images/task/chess_stage.png'),
      _InvItem('Đá tiến hóa', 'Dùng để tiến hóa thú\nlên cấp cao hơn.',
          profile.evolutionStone, 'assets/images/stone_upgrade.png'),
      _InvItem('Trứng thường', 'Dùng để ấp thú\nngẫu nhiên.',
          profile.commonEgg, 'assets/images/eggs/common_egg.png',
          eggType: 'common'),
      _InvItem('Trứng hiếm', 'Có cơ hội nở ra\nthú quý hiếm hơn.',
          profile.rareEgg, 'assets/images/eggs/rare_egg.png', eggType: 'rare'),
    ];

    final pieces = <_PieceItem>[
      for (final inv in owned)
        if (inv.shards > 0 && byId[inv.creatureId] != null)
          _PieceItem(
            'Mảnh ${byId[inv.creatureId]!.name}',
            byId[inv.creatureId]!.rarity,
            inv.shards,
            _kShardsPerSummon,
            _puzzleAsset(inv.creatureId),
          ),
    ];

    if (!mounted) return;
    setState(() {
      _items = items;
      _pieces = pieces;
      _loading = false;
    });
  }

  /// Mở màn ấp trứng; nếu ấp thành công thì tải lại kho để cập nhật số trứng.
  Future<void> _openEgg(String eggType) async {
    final hatched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EggHatchScreen(eggType: eggType),
      ),
    );
    if (hatched == true && mounted) _load();
  }

  static String _puzzleAsset(String creatureId) =>
      CreatureRepository.puzzleAsset(creatureId) ??
      CreatureRepository.defaultImage;

  int get _itemSlots => _items.where((i) => i.count > 0).length;
  int get _pieceTotal => _pieces.fold<int>(0, (s, p) => s + p.owned);
  bool get _hasAnyItem => _itemSlots > 0;
  bool get _hasAnyPiece => _pieces.isNotEmpty;

  bool get _showItems => _tab != _Tab.pieces;
  bool get _showPieces => _tab != _Tab.items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bags/background.png',
              fit: BoxFit.fill,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RoundButton(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: _kInk, size: 26),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Image.asset(
                            'assets/images/bags/frame.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(color: _kBlue))
                            : Column(
                                children: [
                                  _buildTitle(),
                                  const SizedBox(height: 14),
                                  _buildTabs(),
                                  const SizedBox(height: 10),
                                  _buildCounters(),
                                  const SizedBox(height: 12),
                                  Expanded(child: _buildBody()),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.only(top: 22, bottom: 4),
      child: Text(
        'Túi đồ',
        style: TextStyle(
          color: _kInk,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(_Tab t, String label) {
      final selected = _tab == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = t),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4FA0FF), Color(0xFF2F6BFF)],
                    )
                  : null,
              color: selected ? null : _kCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFF1E4FBE) : _kCreamBorder,
                width: 2,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x552F6BFF),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...const [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : _kBrown,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          tab(_Tab.all, 'Tất cả'),
          tab(_Tab.items, 'Vật phẩm'),
          tab(_Tab.pieces, 'Mảnh ghép thú'),
        ],
      ),
    );
  }

  Widget _buildCounters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCreamBorder, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: _CounterCell(
                asset: 'assets/images/bags/bag_icon.png',
                label: 'ô vật phẩm',
                current: _itemSlots,
                total: _kItemSlotsMax,
              ),
            ),
            Container(width: 1, height: 36, color: _kCreamBorder),
            Expanded(
              child: _CounterCell(
                asset: 'assets/images/bags/puzzle_icon.png',
                label: 'Mảnh ghép đã thu thập',
                current: _pieceTotal,
                total: _kPieceSlotsMax,
                stacked: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showItems) _buildItemsSection(),
          if (_showItems && _showPieces) const SizedBox(height: 14),
          if (_showPieces) _buildPiecesSection(),
          const SizedBox(height: 14),
          _buildTip(),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    if (!_hasAnyItem) {
      return const _EmptyCard(
        asset: 'assets/images/bags/empty_item.png',
        title: 'Chưa có vật phẩm nào',
        subtitle: 'Hoàn thành màn chơi, mở rương\nhoặc ấp trứng để nhận vật phẩm.',
      );
    }
    final visible = [for (final i in _items) if (i.count > 0) i];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, i) => _ItemCard(
        item: visible[i],
        onTap: visible[i].eggType != null
            ? () => _openEgg(visible[i].eggType!)
            : null,
      ),
    );
  }

  Widget _buildPiecesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionDivider(label: 'Mảnh ghép thú'),
        const SizedBox(height: 10),
        if (!_hasAnyPiece)
          const _EmptyCard(
            asset: 'assets/images/bags/empty_puzzle.png',
            title: 'Chưa có mảnh ghép thú nào',
            subtitle: 'Thu thập mảnh ghép để triệu hồi thú mới.',
          )
        else
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: _pieces.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PieceCard(piece: _pieces[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCreamBorder, width: 2),
      ),
      child: const Row(
        children: [
          Text('💡', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mẹo: Thu thập đủ mảnh ghép để triệu hồi thú mới!',
              style: TextStyle(
                color: _kBrown,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Components ───────────────────────────────────────────────────────────────

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
          color: _kCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCreamBorder, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }
}


class _CounterCell extends StatelessWidget {
  const _CounterCell({
    required this.asset,
    required this.label,
    required this.current,
    required this.total,
    this.stacked = false,
  });
  final String asset;
  final String label;
  final int current;
  final int total;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final numbers = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _kBrown,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$current',
                    style: const TextStyle(
                      color: _kBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: '/$total',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ]),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$current',
                    style: const TextStyle(
                      color: _kBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: ' $label',
                    style: const TextStyle(
                      color: _kBrown,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
              ),
              Text(
                '$current/$total',
                style: const TextStyle(
                  color: Color(0xFF6B8E2C),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Image.asset(asset, width: 34, height: 34, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(child: numbers),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.onTap});
  final _InvItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kCreamBorder, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _CountBadge(count: item.count),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Image.asset(item.asset, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              style: const TextStyle(
                color: _kInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              onTap != null ? 'Chạm để mở' : item.desc,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: onTap != null ? _kBlue : _kMuted,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: onTap != null ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FA0FF), Color(0xFF2F6BFF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        'x$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.piece});
  final _PieceItem piece;
  @override
  Widget build(BuildContext context) {
    final style = _rarity[piece.rarity] ?? _rarity['common']!;
    final progress = (piece.owned / piece.required).clamp(0.0, 1.0);
    return SizedBox(
      width: 132,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCreamBorder, width: 2),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _CountBadge(count: piece.owned),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Image.asset(piece.asset, fit: BoxFit.contain),
            ),
            const SizedBox(height: 4),
            Text(
              piece.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                style.label,
                style: TextStyle(
                  color: style.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('🧩', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation(style.bar),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${piece.owned}/${piece.required}',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _kCreamBorder, thickness: 1.5)),
        const SizedBox(width: 8),
        const Text('🧩', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _kBrown,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: _kCreamBorder, thickness: 1.5)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.asset,
    required this.title,
    required this.subtitle,
  });
  final String asset;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCreamBorder, width: 2),
      ),
      child: Column(
        children: [
          Image.asset(asset, height: 130, fit: BoxFit.contain),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _kInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kMuted,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
