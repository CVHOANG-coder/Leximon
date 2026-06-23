import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/progress_repository.dart';
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
    if (!mounted) return;
    setState(() => _profile = profile);
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
          SafeArea(
            child: _TopHud(
              coins: _profile?.coins ?? 0,
              food: _profile?.food ?? 0,
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
    required this.coins,
    required this.food,
  });
  final VoidCallback onProfileTap;
  final int coins;
  final int food;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Player avatar + level
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white38),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent,
                    child: const Text(
                      'A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PLAYER: ALEX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'LVL 5',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _LevelBar(progress: 0.6),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Coins
          _CurrencyChip(
            asset: 'assets/images/coin.png',
            value: '$coins',
            // Ảnh coin có nhiều khoảng trong suốt nên cần lớn hơn cho cân.
            iconSize: 34,
          ),
          const SizedBox(width: 6),
          // Food
          _CurrencyChip(
            asset: 'assets/images/food.png',
            value: '$food',
            iconSize: 36,
          ),
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        widthFactor: progress,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
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
