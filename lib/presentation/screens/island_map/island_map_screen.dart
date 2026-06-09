import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../game/island_game.dart';
import '../../../shared/providers/mock_data.dart';

class IslandMapScreen extends StatefulWidget {
  const IslandMapScreen({super.key, required this.islandId});

  final String islandId;

  @override
  State<IslandMapScreen> createState() => _IslandMapScreenState();
}

class _IslandMapScreenState extends State<IslandMapScreen> {
  late final IslandGame _game = IslandGame(islandId: widget.islandId);

  @override
  Widget build(BuildContext context) {
    final island = MockData.islands.firstWhere(
      (i) => i.id == widget.islandId,
      orElse: () => MockData.islands.first,
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(island.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Wrap(
              spacing: 8,
              children: [
                for (final tid in island.topicIds)
                  ActionChip(
                    label: Text('Learn $tid'),
                    onPressed: () => context.push('/lesson/$tid'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}
