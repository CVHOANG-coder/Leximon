import 'package:equatable/equatable.dart';

/// Một dạng tiến hóa của sinh vật (baby / teen / adult).
class CreatureStage extends Equatable {
  const CreatureStage({required this.name, required this.skill});

  final String name;
  final String skill;

  factory CreatureStage.fromJson(Map<String, dynamic> json) => CreatureStage(
        name: json['name'] as String? ?? '',
        skill: json['skill'] as String? ?? '',
      );

  @override
  List<Object?> get props => [name, skill];
}

/// Một sinh vật trong lib/data/sample/animals.json.
class Creature extends Equatable {
  const Creature({
    required this.id,
    required this.name,
    required this.island,
    required this.theme,
    required this.rarity,
    required this.eggType,
    required this.stages,
  });

  final String id;
  final String name;
  final String island;
  final String theme;

  /// common | rare | epic | legendary.
  final String rarity;
  final String eggType;

  /// Theo khóa "baby" / "teen" / "adult".
  final Map<String, CreatureStage> stages;

  factory Creature.fromJson(Map<String, dynamic> json) => Creature(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        island: json['island'] as String? ?? '',
        theme: json['theme'] as String? ?? '',
        rarity: json['rarity'] as String? ?? 'common',
        eggType: json['eggType'] as String? ?? '',
        stages: {
          for (final e
              in (json['stages'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: CreatureStage.fromJson(e.value as Map<String, dynamic>),
        },
      );

  @override
  List<Object?> get props => [id, name, island, theme, rarity, eggType];
}
