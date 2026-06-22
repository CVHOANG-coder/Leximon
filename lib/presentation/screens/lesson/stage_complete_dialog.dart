import 'package:flutter/material.dart';

import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';

const _kInk = Color(0xFF1E3A5F);
const _kCream = Color(0xFFFFF6DE);
const _kCreamBorder = Color(0xFFE7D9B0);
const _kBrown = Color(0xFF8B5A2B);
const _kGold = Color(0xFFE8A93B);
const _kGoldDeep = Color(0xFFB87411);
const _kBlue = Color(0xFF2F6BFF);

/// Popup "Hoàn thành chặng!" — hiển thị kết quả + danh sách vật phẩm,
/// và bấm "Nhận thưởng" sẽ gọi [InventoryRepository.grantReward] để ghi
/// vào SQLite. Trả về `true` khi người dùng bấm "Học lại", false khi
/// "Nhận thưởng".
class StageCompleteDialog extends StatefulWidget {
  const StageCompleteDialog({
    super.key,
    required this.score,
    required this.total,
    required this.stars,
    required this.reward,
    required this.topicId,
    required this.stage,
    required this.difficulty,
  });

  final int score;
  final int total;
  final int stars;
  final RewardPayload reward;
  final int topicId;
  final int stage;
  final String difficulty;

  @override
  State<StageCompleteDialog> createState() => _StageCompleteDialogState();
}

class _StageCompleteDialogState extends State<StageCompleteDialog> {
  bool _claiming = false;

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    await InventoryRepository.instance.grantReward(
      widget.reward,
      topicId: widget.topicId,
      stage: widget.stage,
      difficulty: widget.difficulty,
      stageStars: widget.stars,
    );
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  // Ảnh mảnh ghép lấy tập trung từ CreatureRepository
  // (assets/images/pets/puzzles/).
  static String _puzzleAsset(String creatureId) =>
      CreatureRepository.puzzleAsset(creatureId) ??
      CreatureRepository.defaultImage;

  List<_RewardTile> get _tiles {
    final r = widget.reward;
    return [
      if (r.coin > 0)
        _RewardTile('Vàng', r.coin, 'assets/images/coin.png'),
      if (r.food > 0)
        _RewardTile('Thức ăn', r.food, 'assets/images/food.png'),
      if (r.chest > 0)
        _RewardTile('Rương quà', r.chest,
            'assets/images/task/chess_stage.png'),
      if (r.commonEgg > 0)
        _RewardTile('Trứng thường', r.commonEgg,
            'assets/images/eggs/common_egg.png'),
      if (r.rareEgg > 0)
        _RewardTile('Trứng hiếm', r.rareEgg,
            'assets/images/eggs/rare_egg.png'),
      if (r.evolutionStone > 0)
        _RewardTile('Đá tiến hóa', r.evolutionStone,
            'assets/images/stone_upgrade.png'),
      // Mỗi creature 1 tile riêng — user thấy rõ đã nhận mảnh của thú nào.
      for (final entry in r.creatureShards.entries)
        if (entry.value > 0)
          _RewardTile(
            _creatureName(entry.key),
            entry.value,
            _puzzleAsset(entry.key),
          ),
    ];
  }

  String _creatureName(String creatureId) {
    // Tên người dùng đọc — không cần await CreatureRepository ở đây vì popup
    // được mở từ lesson đã load creatures rồi (cache trong repo).
    final cached = CreatureRepository.instance.cachedById(creatureId);
    if (cached != null) return 'Mảnh ${cached.name}';
    return 'Mảnh ${creatureId.replaceAll('_', ' ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Stack(
        children: [
          // Khung popup (đã có sao + nút X vẽ sẵn trong ảnh).
          Positioned.fill(
            child: Image.asset(
              'assets/images/popup_gift/frame_popup.png',
              fit: BoxFit.fill,
            ),
          ),
            // Nội dung: chừa header (~12%) trên cho sao + border 2 bên + đáy.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 78, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OutlinedTitle(text: 'Hoàn thành chặng!'),
                  const SizedBox(height: 14),
                  _DividerLabel('Kết quả màn chơi'),
                  const SizedBox(height: 10),
                  _ScoreChip(score: widget.score, total: widget.total),
                  const SizedBox(height: 14),
                  _StarRow(stars: widget.stars),
                  const SizedBox(height: 16),
                  _DividerLabel('Phần thưởng nhận được'),
                  const SizedBox(height: 10),
                  _buildRewardGrid(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SoftButton(
                          label: 'Xem lại',
                          onTap: _claiming
                              ? null
                              : () => Navigator.of(context).pop(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PrimaryButton(
                          label: _claiming ? 'Đang lưu...' : 'Nhận thưởng',
                          onTap: _claiming ? null : _claim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Vùng tap đè lên nút X vẽ sẵn trong ảnh khung (góc trên phải).
            Positioned(
              top: 6,
              right: 6,
              width: 44,
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _claiming
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildRewardGrid() {
    final tiles = _tiles;
    if (tiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'Không có vật phẩm đặc biệt lần này.',
          style: TextStyle(
              color: _kBrown, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) => _RewardCard(tile: tiles[i]),
    );
  }
}

class _RewardTile {
  const _RewardTile(this.name, this.count, this.asset);
  final String name;
  final int count;
  final String asset;
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.tile});
  final _RewardTile tile;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCreamBorder, width: 2),
      ),
      child: Column(
        children: [
          Expanded(child: Image.asset(tile.asset, fit: BoxFit.contain)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kCreamBorder, width: 1.5),
            ),
            child: Text(
              'x${tile.count}',
              style: const TextStyle(
                color: _kInk,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedTitle extends StatelessWidget {
  const _OutlinedTitle({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      height: 1.0,
    );
    return Stack(
      children: [
        Text(text,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..color = _kGoldDeep,
            )),
        Text(text, style: style.copyWith(color: _kGold)),
      ],
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _kCreamBorder, thickness: 1.5)),
        const SizedBox(width: 8),
        Text(
          text,
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

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score, required this.total});
  final int score;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCreamBorder, width: 2),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'Trả lời đúng ',
              style: TextStyle(
                color: _kInk,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: '$score/$total',
              style: const TextStyle(
                color: Color(0xFFE8762B),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const TextSpan(
              text: ' câu',
              style: TextStyle(
                color: _kInk,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});
  final int stars;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.star_rounded,
              size: 56,
              color: i < stars ? _kGold : const Color(0xFFB59A6B),
              shadows: i < stars
                  ? const [
                      Shadow(
                        color: _kGoldDeep,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCreamBorder, width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _kBrown,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4FA0FF), _kBlue],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E4FBE), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x552F6BFF),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
