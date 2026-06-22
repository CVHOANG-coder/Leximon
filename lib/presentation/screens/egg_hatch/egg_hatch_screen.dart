import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/creature.dart';
import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _kInk = Color(0xFF1E3A5F);
const _kGold = Color(0xFFFFC542);

enum _Phase { opening, flash, reveal }

/// Màn "mở trứng": chạy hoạt ảnh mở trứng → ánh sáng lóa hết màn hình → hiện
/// pet nhận được kèm nút "Nhận". Bấm "Nhận" sẽ trừ trứng, thêm pet vào kho và
/// quay về màn hình trước đó (pop `true`).
class EggHatchScreen extends StatefulWidget {
  const EggHatchScreen({super.key, required this.eggType});

  /// 'common' | 'rare'.
  final String eggType;

  @override
  State<EggHatchScreen> createState() => _EggHatchScreenState();
}

class _EggHatchScreenState extends State<EggHatchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _egg;
  late final AnimationController _flash;
  late final AnimationController _reveal;

  /// Số mảnh ghép nhận được khi trùng thú đã sở hữu.
  static const _kDuplicateShards = 10;

  _Phase _phase = _Phase.opening;
  Creature? _result;

  /// Đã sở hữu thú bốc trúng → sẽ đổi thành mảnh ghép thay vì ấp thú mới.
  bool _isDuplicate = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _egg = AnimationController(vsync: this);
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_onFlashTick);
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _pickResult();

    // Dự phòng: nếu hoạt ảnh mở trứng tải lỗi / quá lâu thì vẫn chuyển tiếp.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _phase == _Phase.opening) _startFlash();
    });
  }

  @override
  void dispose() {
    _egg.dispose();
    _flash.dispose();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _pickResult() async {
    final creatures = await CreatureRepository.instance.loadCreatures();
    final owned = await InventoryRepository.instance.getOwnedCreatureIds();
    // Chỉ chọn trong các thú đã có bộ ảnh riêng để luôn hiện được ảnh pet.
    final pool = [
      for (final c in creatures)
        if (CreatureRepository.hasOwnImage(c.id)) c,
    ];
    if (pool.isEmpty || !mounted) return;
    final picked = pool[Random().nextInt(pool.length)];
    setState(() {
      _result = picked;
      _isDuplicate = owned.contains(picked.id);
    });
  }

  void _startFlash() {
    if (!mounted || _phase != _Phase.opening) return;
    setState(() => _phase = _Phase.flash);
    _flash.forward();
  }

  void _onFlashTick() {
    // Khi ánh sáng đạt đỉnh (giữa chừng) thì hé lộ pet phía sau lớp sáng.
    if (_phase == _Phase.flash && _flash.value >= 0.5) {
      setState(() => _phase = _Phase.reveal);
      _reveal.forward();
    }
  }

  Future<void> _claim() async {
    final result = _result;
    if (result == null || _claiming) return;
    setState(() => _claiming = true);
    await InventoryRepository.instance.hatchEgg(
      eggType: widget.eggType,
      creatureId: result.id,
      duplicateShards: _kDuplicateShards,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1830),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nền hào quang.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: [Color(0xFF20335C), Color(0xFF0E1830)],
              ),
            ),
          ),
          _buildCenter(),
          // Mây trang trí ở mép trên và dưới màn hình.
          _buildClouds(),
          // Lớp ánh sáng lóa hết màn hình.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, _) {
                final v = _flash.value;
                // 0 → 0.5 → 1 cho opacity 0 → 1 → 0 (đỉnh sáng ở giữa).
                final opacity = (1 - (v * 2 - 1).abs()).clamp(0.0, 1.0);
                return Opacity(
                  opacity: _phase == _Phase.opening ? 0 : opacity,
                  child: const ColoredBox(color: Colors.white),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Mây trang trí (assets/images/homeScreen/clouds). Mây có đỉnh bồng bềnh và
  /// đáy phẳng, nên dải trên được lật dọc để phần bồng bềnh hướng xuống. Nền
  /// đặc cùng tông mây (#ECEEFB) lấp kín, mép tua mây che đường viền nền.
  Widget _buildClouds() {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    const cloudColor = Color(0xFFECEEFB);

    Widget cloud(String name, double width, {bool flip = false}) {
      final img = Image.asset(
        'assets/images/homeScreen/clouds/$name',
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
      return flip ? Transform.scale(scaleY: -1, child: img) : img;
    }

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dải mây trên: nền đặc lấp kín mép trên + mây lật xuống ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.12,
            child: const ColoredBox(color: cloudColor),
          ),
          Positioned(
            top: h * 0.02,
            left: -w * 0.12,
            child: cloud('clouds_1.png', w * 0.82, flip: true),
          ),
          Positioned(
            top: h * 0.03,
            right: -w * 0.14,
            child: cloud('clouds_5.png', w * 0.85, flip: true),
          ),
          Positioned(
            top: h * 0.05,
            left: w * 0.26,
            child: cloud('clouds_2.png', w * 0.5, flip: true),
          ),

          // ── Dải mây dưới (đã dịch lên): nền đặc ở đáy + mây hướng lên ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: h * 0.06,
            child: const ColoredBox(color: cloudColor),
          ),
          Positioned(
            bottom: h * 0.04,
            left: -w * 0.12,
            child: cloud('clouds_4.png', w * 0.64),
          ),
          Positioned(
            bottom: h * 0.05,
            right: -w * 0.12,
            child: cloud('clouds_1.png', w * 0.62),
          ),
          Positioned(
            bottom: h * 0.10,
            left: w * 0.28,
            child: cloud('clouds_2.png', w * 0.48),
          ),
        ],
      ),
    );
  }

  Widget _buildCenter() {
    if (_phase == _Phase.reveal) return Center(child: _buildReveal());
    return _buildEgg();
  }

  Widget _buildEgg() {
    // Phủ toàn màn hình, căn giữa; BoxFit.contain để thấy trọn animation và
    // luôn nằm chính giữa (không lệch về một phía).
    return Positioned.fill(
      child: Lottie.asset(
        // Hoạt ảnh mở trứng JSON theo loại trứng (assets/lotties/egg).
        'assets/lotties/egg/egg_${widget.eggType}.json',
        controller: _egg,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        onLoaded: (composition) {
          _egg
            ..duration = composition.duration
            ..forward().whenComplete(_startFlash);
        },
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/eggs/${widget.eggType}_egg.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildReveal() {
    final result = _result;
    if (result == null) {
      return const CircularProgressIndicator(color: _kGold);
    }
    final image = CreatureRepository.imageAsset(result.id, stage: 'baby');
    final scale = CurvedAnimation(parent: _reveal, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _reveal, curve: Curves.easeOut);

    return FadeTransition(
      opacity: fade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Chúc mừng!',
            style: TextStyle(
              color: _kGold,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isDuplicate ? 'Bạn đã sở hữu thú này' : 'Bạn nhận được thú mới',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ScaleTransition(
            scale: scale,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              height: MediaQuery.of(context).size.width * 0.5,
              child: Image.asset(
                image,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Image.asset(
                  CreatureRepository.defaultImage,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_isDuplicate) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  CreatureRepository.puzzleAsset(result.id) ??
                      CreatureRepository.defaultImage,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
                Text(
                  '+$_kDuplicateShards mảnh ghép',
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          _ClaimButton(onTap: _claiming ? null : _claim),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD873), _kGold],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66FFC542),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Nhận',
          style: TextStyle(
            color: _kInk,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
