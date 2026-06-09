import 'package:equatable/equatable.dart';

class Island extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<String> topicIds;
  final bool unlocked;

  const Island({
    required this.id,
    required this.name,
    required this.description,
    required this.topicIds,
    this.unlocked = false,
  });

  @override
  List<Object?> get props => [id, name, description, topicIds, unlocked];
}
