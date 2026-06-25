import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/services/level_progression_service.dart';
import '../../../game/components/island_data.dart';
import '../../../game/world_map_game.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final WorldMapGame _game;
  UserProfile? _profile;
  int? _xpToNextLevel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _game = WorldMapGame(
      islands: IslandData.defaults,
      // currentIslandIndex omitted — defaults to the last unlocked island
      onIslandTapped: (island) {
        // Mọi đảo đã mở khóa đều vào được: đảo Học tập có màn riêng,
        // các đảo khác dùng màn bản đồ đảo chung (/island/:id).
        final location = switch (island.id) {
          'learning' => '/learning-island',
          'ocean_kingdom' => '/ocean-kingdom',
          'nature' => '/nature-island',
          'home' => '/home-village',
          _ => '/island/${island.id}',
        };
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await context.push(location);
          if (mounted) _loadProfile();
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProgressRepository.instance.getProfile();
    final progression = await LevelProgressionService.instance.load();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _xpToNextLevel = progression.xpToNextLevel(profile.level);
    });
  }

  Future<void> _pushAndRefresh(String location) async {
    await context.push(location);
    if (mounted) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Flame world map ──────────────────────────────────────────────
          GameWidget(game: _game),

          // ── Top HUD bar ──────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top,
            child: _TopHud(
              profile: _profile,
              xpToNextLevel: _xpToNextLevel,
              onProfileTap: () => _pushAndRefresh('/profile'),
            ),
          ),

          // ── Right-side navigation buttons ───────────────────────────────
          Positioned(
            right: 10,
            top: MediaQuery.of(context).padding.top + 90,
            child: _SideNav(
              onCollectionTap: () => _pushAndRefresh('/collection'),
              onInventoryTap: () => _pushAndRefresh('/inventory'),
              onTeamTap: () => _pushAndRefresh('/team'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top HUD ─────────────────────────────────────────────────────────────────

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.onProfileTap,
    required this.profile,
    required this.xpToNextLevel,
  });
  final VoidCallback onProfileTap;
  final UserProfile? profile;
  final int? xpToNextLevel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onProfileTap,
                  child: _PlayerProgressHud(
                    profile: profile,
                    xpToNextLevel: xpToNextLevel,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Coins
          _CurrencyChip(
            asset: 'assets/images/coin.png',
            value: '${profile?.coins ?? 0}',
            // Ảnh coin có nhiều khoảng trong suốt nên cần lớn hơn cho cân.
            iconSize: 34,
          ),
          const SizedBox(width: 6),
          // Food
          _CurrencyChip(
            asset: 'assets/images/food.png',
            value: '${profile?.food ?? 0}',
            iconSize: 36,
          ),
        ],
      ),
    );
  }
}

class _PlayerProgressHud extends StatelessWidget {
  const _PlayerProgressHud({
    required this.profile,
    required this.xpToNextLevel,
  });

  final UserProfile? profile;
  final int? xpToNextLevel;

  @override
  Widget build(BuildContext context) {
    final level = profile?.level ?? 1;
    final currentXp = profile?.xp ?? 0;
    final requiredXp = xpToNextLevel;
    final isMaxLevel = profile != null && requiredXp == null;
    final progress = isMaxLevel
        ? 1.0
        : requiredXp == null || requiredXp <= 0
        ? 0.0
        : (currentXp / requiredXp).clamp(0.0, 1.0);
    final xpText = isMaxLevel
        ? '$currentXp / MAX'
        : '${requiredXp == null ? 0 : currentXp} / ${requiredXp ?? 0}';

    return SizedBox(
      width: 232,
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF143151),
                border: Border.all(color: const Color(0xFF9B7A27), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/profileInfo/avatar_default.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.person, color: Colors.white, size: 34),
                ),
              ),
            ),
          ),
          Positioned(
            left: 58,
            top: 2,
            child: Container(
              height: 19,
              constraints: const BoxConstraints(minWidth: 54),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF061629).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'Lexi',
                maxLines: 1,
                style: TextStyle(
                  color: Color(0xFFC5DAF2),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: 66,
            top: 28,
            child: _XpBar(progress: progress, text: xpText),
          ),
          Positioned(left: 48, top: 15, child: _HomeLevelBadge(level: level)),
        ],
      ),
    );
  }
}

class _HomeLevelBadge extends StatelessWidget {
  const _HomeLevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/profileInfo/star_level.png',
            width: 46,
            height: 46,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Text(
            '$level',
            style: const TextStyle(
              color: Color(0xFFFFD24A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [
                Shadow(
                  color: Color(0xFF1E1304),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.progress, required this.text});

  final double progress;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 164,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF04101C).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.black.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF9E8618), Color(0xFF5F520A)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            text,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFD7D3C8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip tiền tệ kiểu game: pill nền tối, icon tròn nhô ra trái và nút "+"
/// tròn xanh lá nhô ra phải (theo mockup).
class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.asset,
    required this.value,
    this.iconSize = 30,
  });
  final String asset;
  final String value;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Thân pill — chừa chỗ bên trái cho icon nhô ra; số và nút "+"
          // nằm inline cùng một hàng.
          Container(
            height: 32,
            margin: const EdgeInsets.only(left: 18),
            padding: const EdgeInsets.fromLTRB(22, 0, 4, 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF12325C).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Nút "+" tròn xanh lá — cùng hàng với số.
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF5CD65C), Color(0xFF2EA82E)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          // Icon tiền tệ nhô ra bên trái, căn giữa theo chiều dọc với pill.
          Positioned(
            left: 0,
            child: Image.asset(asset, width: iconSize, height: iconSize),
          ),
        ],
      ),
    );
  }
}

// ─── Right-side navigation ────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.onCollectionTap,
    required this.onInventoryTap,
    required this.onTeamTap,
  });
  final VoidCallback onCollectionTap;
  final VoidCallback onInventoryTap;
  final VoidCallback onTeamTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(icon: Icons.map_outlined, label: 'MAP', onTap: () {}),
        const SizedBox(height: 8),
        _NavButton(
          icon: Icons.groups_2_outlined,
          label: 'TEAM',
          onTap: onTeamTap,
        ),
        const SizedBox(height: 8),
        _NavButton(
          icon: Icons.catching_pokemon,
          label: 'PETS',
          onTap: onCollectionTap,
        ),
        const SizedBox(height: 8),
        _NavButton(
          icon: Icons.backpack_outlined,
          label: 'BAG',
          onTap: onInventoryTap,
        ),
        const SizedBox(height: 8),
        _NavButton(icon: Icons.store_outlined, label: 'SHOP', onTap: () {}),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
