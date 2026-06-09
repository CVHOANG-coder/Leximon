import 'package:equatable/equatable.dart';

import 'lexipet.dart';

class Egg extends Equatable {
  final String id;
  final LexipetRarity rarity;
  final int wordsToHatch;
  final int wordsLearned;

  const Egg({
    required this.id,
    required this.rarity,
    required this.wordsToHatch,
    this.wordsLearned = 0,
  });

  bool get isReady => wordsLearned >= wordsToHatch;

  double get progress =>
      wordsToHatch == 0 ? 0 : (wordsLearned / wordsToHatch).clamp(0, 1);

  @override
  List<Object?> get props => [id, rarity, wordsToHatch, wordsLearned];
}
