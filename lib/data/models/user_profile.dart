import 'package:equatable/equatable.dart';

/// Hồ sơ người chơi (bảng `user_profile`, luôn chỉ có 1 dòng).
class UserProfile extends Equatable {
  const UserProfile({
    required this.level,
    required this.xp,
    required this.totalXp,
    required this.coins,
    this.chest = 0,
    this.food = 0,
    this.evolutionStone = 0,
    this.commonEgg = 0,
    this.rareEgg = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.learningDays = 0,
    this.completedStages = 0,
    this.learnedWords = 0,
    this.lastLearningDate,
  });

  final int level;

  /// XP trong cấp hiện tại.
  final int xp;

  /// XP tích lũy toàn bộ.
  final int totalXp;
  final int coins;
  final int chest;
  final int food;
  final int evolutionStone;
  final int commonEgg;
  final int rareEgg;
  final int currentStreak;
  final int longestStreak;
  final int learningDays;
  final int completedStages;
  final int learnedWords;
  final DateTime? lastLearningDate;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    level: map['level'] as int,
    xp: map['xp'] as int,
    totalXp: map['total_xp'] as int,
    coins: map['coins'] as int,
    chest: (map['chest'] as int?) ?? 0,
    food: (map['food'] as int?) ?? 0,
    evolutionStone: (map['evolution_stone'] as int?) ?? 0,
    commonEgg: (map['common_egg'] as int?) ?? 0,
    rareEgg: (map['rare_egg'] as int?) ?? 0,
    currentStreak: (map['current_streak'] as int?) ?? 0,
    longestStreak: (map['longest_streak'] as int?) ?? 0,
    learningDays: (map['learning_days'] as int?) ?? 0,
    completedStages: (map['completed_stages'] as int?) ?? 0,
    learnedWords: (map['learned_words'] as int?) ?? 0,
    lastLearningDate: map['last_learning_date'] == null
        ? null
        : DateTime.parse(map['last_learning_date'] as String),
  );

  @override
  List<Object?> get props => [
    level,
    xp,
    totalXp,
    coins,
    chest,
    food,
    evolutionStone,
    commonEgg,
    rareEgg,
    currentStreak,
    longestStreak,
    learningDays,
    completedStages,
    learnedWords,
    lastLearningDate,
  ];
}
