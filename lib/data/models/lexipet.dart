import 'package:equatable/equatable.dart';

enum LexipetRarity { common, rare, epic, legendary }

enum LexipetElement { grass, water, fire, spark, mystic }

class Lexipet extends Equatable {
  final String id;
  final String name;
  final String spriteAsset;
  final LexipetRarity rarity;
  final LexipetElement element;
  final String linkedTopicId;

  const Lexipet({
    required this.id,
    required this.name,
    required this.spriteAsset,
    required this.rarity,
    required this.element,
    required this.linkedTopicId,
  });

  @override
  List<Object?> get props =>
      [id, name, spriteAsset, rarity, element, linkedTopicId];
}
