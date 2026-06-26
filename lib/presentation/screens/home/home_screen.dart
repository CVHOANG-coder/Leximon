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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: Row(
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: _PlayerProgressHud(
                  profile: profile,
                  xpToNextLevel: xpToNextLevel,
                ),
              ),
              const SizedBox(width: 18),
              _CurrencyChip(
                asset: 'assets/images/coin.png',
                value: '${profile?.coins ?? 0}',
                iconSize: 58,
              ),
              const SizedBox(width: 14),
              _CurrencyChip(
                asset: 'assets/images/food.png',
                value: '${profile?.food ?? 0}',
                iconSize: 58,
              ),
            ],
          ),
        ),
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
      width: 304,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 1,
            top: 2,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF6A3), Color(0xFFFFB725)],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF086CC2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/profileInfo/avatar_default.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(left: 77, top: 12, child: _NamePlate(name: 'Lexi')),
          Positioned(
            left: 86,
            top: 46,
            child: _XpBar(progress: progress, text: xpText),
          ),
          Positioned(left: 64, top: 30, child: _HomeLevelBadge(level: level)),
        ],
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF287FE3), Color(0xFF0B4FB3)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF83C7FF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x6636A9FF),
            blurRadius: 6,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Text(
        name,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          height: 1,
          shadows: [
            Shadow(
              color: Color(0xAA09256A),
              blurRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
        ),
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
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/profileInfo/star_level.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Text(
            '$level',
            style: const TextStyle(
              color: Color(0xFFFFD24A),
              fontSize: 23,
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
      width: 216,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF17355A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD34C), width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
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
                      colors: [Color(0xFF95F53C), Color(0xFF34B915)],
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
              color: Colors.white,
              fontSize: 16,
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
      width: 142,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 23,
            right: 0,
            top: 11,
            child: Container(
              height: 38,
              padding: const EdgeInsets.fromLTRB(38, 0, 38, 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF17356D),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 8,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF78E755), Color(0xFF27A826)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 34,
                weight: 900,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Image.asset(
              asset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
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
