import 'package:equatable/equatable.dart';

/// Enemy của một chặng, đọc từ object `enemy` trong
/// `topics_with_stage_difficulty.json`. Cơ chế chi tiết xem
/// `lib/data/sample/enemy_battle_mechanism.md`.
class Enemy extends Equatable {
  const Enemy({
    required this.id,
    required this.name,
    required this.enemyType,
    required this.rank,
    required this.element,
    required this.level,
    required this.maxHp,
    required this.hp,
    required this.shield,
    this.assetKey = '',
    this.introText = '',
    this.skillName = '',
    this.skillDescription = '',
  });

  final String id;
  final String name;

  /// minion / guardian / elite / topic_boss / elite_topic_boss.
  final String enemyType;
  final String rank;
  final String element;
  final int level;
  final int maxHp;

  /// HP ban đầu (thường bằng [maxHp]).
  final int hp;

  /// Giáp ban đầu, chặn damage trước khi trừ HP.
  final int shield;
  final String assetKey;
  final String introText;
  final String skillName;
  final String skillDescription;

  factory Enemy.fromJson(Map<String, dynamic> json) {
    final skill = json['skill'] as Map<String, dynamic>?;
    final maxHp = (json['maxHp'] as num?)?.toInt() ?? 100;
    return Enemy(
      id: json['id'] as String? ?? 'enemy',
      name: json['name'] as String? ?? 'Enemy',
      enemyType: json['enemyType'] as String? ?? 'minion',
      rank: json['rank'] as String? ?? 'minion',
      element: json['element'] as String? ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      maxHp: maxHp,
      hp: (json['hp'] as num?)?.toInt() ?? maxHp,
      shield: (json['shield'] as num?)?.toInt() ?? 0,
      assetKey: json['assetKey'] as String? ?? '',
      introText: json['introText'] as String? ?? '',
      skillName: skill?['name'] as String? ?? '',
      skillDescription: skill?['description'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        enemyType,
        rank,
        element,
        level,
        maxHp,
        hp,
        shield,
      ];
}
