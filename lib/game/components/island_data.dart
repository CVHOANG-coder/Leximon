/// Immutable config for one island node on the world map.
class IslandData {
  const IslandData({
    required this.id,
    required this.name,
    required this.assetName,
    this.unlocked = false,
    this.completed = false,
  });

  final String id;
  final String name;
  final String assetName;
  final bool unlocked;
  final bool completed;

  IslandData copyWith({bool? unlocked, bool? completed}) => IslandData(
        id: id,
        name: name,
        assetName: assetName,
        unlocked: unlocked ?? this.unlocked,
        completed: completed ?? this.completed,
      );

  /// Default island roster — index 0 is at the bottom of the map (Đảo 1).
  static const List<IslandData> defaults = [
    IslandData(
      id: 'learning',
      name: 'Learning Island',
      assetName: 'Learning_Island.png',
      unlocked: true,
    ),
    IslandData(
      id: 'home',
      name: 'Home Village',
      assetName: 'Home_Village.png',
    ),
    IslandData(
      id: 'ocean_kingdom',
      name: 'Ocean Kingdom',
      assetName: 'Ocean_Kingdom.png',
    ),
    IslandData(
      id: 'nature',
      name: 'Nature Island',
      assetName: 'nature_island.png',
    ),
    IslandData(
      id: 'city',
      name: 'City Island',
      assetName: 'City_Island.png',
    ),
    IslandData(
      id: 'adventure',
      name: 'Adventure Island',
      assetName: 'adventure_island.png',
    ),
    IslandData(
      id: 'entertainment',
      name: 'Entertainment Island',
      assetName: 'Entertainment_Island.png',
    ),
    IslandData(
      id: 'life',
      name: 'Life Island',
      assetName: 'life_island.png',
    ),
    IslandData(
      id: 'festival',
      name: 'Festival Island',
      assetName: 'festival_island.png',
    ),
    IslandData(
      id: 'master',
      name: 'Master Island',
      assetName: 'master_island.png',
    ),
  ];
}
