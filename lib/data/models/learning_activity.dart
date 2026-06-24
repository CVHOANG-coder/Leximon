import 'package:equatable/equatable.dart';

import 'user_profile.dart';

class DailyLearningActivity extends Equatable {
  const DailyLearningActivity({
    required this.date,
    required this.xpEarned,
    required this.correctAnswers,
    required this.questionsAnswered,
    required this.stagesPlayed,
    required this.stagesCompleted,
  });

  final DateTime date;
  final int xpEarned;
  final int correctAnswers;
  final int questionsAnswered;
  final int stagesPlayed;
  final int stagesCompleted;

  factory DailyLearningActivity.fromMap(Map<String, dynamic> map) =>
      DailyLearningActivity(
        date: DateTime.parse(map['activity_date'] as String),
        xpEarned: map['xp_earned'] as int,
        correctAnswers: map['correct_answers'] as int,
        questionsAnswered: map['questions_answered'] as int,
        stagesPlayed: map['stages_played'] as int,
        stagesCompleted: map['stages_completed'] as int,
      );

  @override
  List<Object?> get props => [
    date,
    xpEarned,
    correctAnswers,
    questionsAnswered,
    stagesPlayed,
    stagesCompleted,
  ];
}

class PlayerProgressOverview extends Equatable {
  const PlayerProgressOverview({
    required this.profile,
    required this.xpToNextLevel,
    required this.activities,
  });

  final UserProfile profile;
  final int? xpToNextLevel;
  final List<DailyLearningActivity> activities;

  @override
  List<Object?> get props => [profile, xpToNextLevel, activities];
}
