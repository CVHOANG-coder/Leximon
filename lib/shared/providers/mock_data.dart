import '../../data/models/island.dart';
import '../../data/models/lesson_topic.dart';
import '../../data/models/lexipet.dart';

class MockData {
  MockData._();

  static const List<LessonTopic> topics = [
    LessonTopic(id: 'animals', title: 'Animals', emoji: '🦊', wordCount: 24),
    LessonTopic(id: 'food', title: 'Food', emoji: '🍓', wordCount: 30),
    LessonTopic(id: 'nature', title: 'Nature', emoji: '🌿', wordCount: 20),
    LessonTopic(id: 'travel', title: 'Travel', emoji: '✈️', wordCount: 28),
  ];

  static const List<Island> islands = [
    Island(
      id: 'starter',
      name: 'Verdant Isle',
      description: 'A lush starter island full of friendly Lexipets.',
      topicIds: ['animals', 'nature'],
      unlocked: true,
    ),
    Island(
      id: 'sunberry',
      name: 'Sunberry Coast',
      description: 'Sweet aromas and tasty vocabulary.',
      topicIds: ['food'],
    ),
    Island(
      id: 'skyport',
      name: 'Skyport Atoll',
      description: 'Travel words drift on the trade winds.',
      topicIds: ['travel'],
    ),
  ];

  static const List<Lexipet> lexipets = [
    Lexipet(
      id: 'lx_001',
      name: 'Sprigling',
      spriteAsset: 'assets/sprites/lx_001.png',
      rarity: LexipetRarity.common,
      element: LexipetElement.grass,
      linkedTopicId: 'nature',
    ),
    Lexipet(
      id: 'lx_002',
      name: 'Foxlette',
      spriteAsset: 'assets/sprites/lx_002.png',
      rarity: LexipetRarity.rare,
      element: LexipetElement.spark,
      linkedTopicId: 'animals',
    ),
  ];
}
