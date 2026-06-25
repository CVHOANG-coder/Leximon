import 'package:flutter/material.dart';

/// Thanh tiến độ của chủ đề đang mở trên bản đồ đảo.
class IslandTopicProgressBar extends StatelessWidget {
  const IslandTopicProgressBar({
    super.key,
    required this.learnedWords,
    required this.totalWords,
  });

  final int learnedWords;
  final int totalWords;

  @override
  Widget build(BuildContext context) {
    final progress = totalWords == 0
        ? 0.0
        : (learnedWords / totalWords).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6DE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC9A05E), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/eggs/scholar_egg.png',
              width: 44,
              height: 44,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        const TextSpan(text: 'Tiến độ chủ đề '),
                        TextSpan(
                          text: '$learnedWords/$totalWords',
                          style: const TextStyle(color: Color(0xFF2196F3)),
                        ),
                        const TextSpan(text: ' từ'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8D9B5),
                        border: Border.all(
                          color: const Color(0xFFC9A05E),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: const ColoredBox(color: Color(0xFF3CB54A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Image.asset(
              'assets/images/task/chess_stage.png',
              width: 46,
              height: 46,
            ),
          ],
        ),
      ),
    );
  }
}
