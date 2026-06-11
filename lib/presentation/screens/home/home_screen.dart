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
        if (island.id == 'learning') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await context.push('/learning-island');
            if (mounted) _loadProfile();
          });
        }
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent,
                    child: const Text('A',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
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
                            fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          const Text(
                            'LVL 5',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
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
            iconSize: 28,
          ),
          const SizedBox(width: 8),
          // Food
          _CurrencyChip(
            asset: 'assets/images/food.png',
            value: '$food',
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
      width: 56,
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

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.asset,
    required this.value,
    this.iconSize = 22,
  });
  final String asset;
  final String value;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: iconSize, height: iconSize),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13),
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
  });
  final VoidCallback onCollectionTap;
  final VoidCallback onInventoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(icon: Icons.map_outlined, label: 'MAP', onTap: () {}),
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
        _NavButton(
          icon: Icons.store_outlined,
          label: 'SHOP',
          onTap: () {},
        ),
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
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
