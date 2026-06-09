import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/mock_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final islands = MockData.islands;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leximon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.catching_pokemon),
            onPressed: () => context.push('/collection'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: islands.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final island = islands[i];
          return _IslandCard(
            title: island.name,
            subtitle: island.description,
            locked: !island.unlocked,
            onTap: island.unlocked
                ? () => context.push('/island/${island.id}')
                : null,
          );
        },
      ),
    );
  }
}

class _IslandCard extends StatelessWidget {
  const _IslandCard({
    required this.title,
    required this.subtitle,
    required this.locked,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: locked ? AppColors.divider : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.grass.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(locked ? '🔒' : '🏝️',
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
