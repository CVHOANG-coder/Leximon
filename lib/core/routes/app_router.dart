import 'package:go_router/go_router.dart';

import '../../presentation/screens/collection/collection_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/island_map/island_map_screen.dart';
import '../../presentation/screens/learning_island/learning_island_screen.dart';
import '../../presentation/screens/lesson/lesson_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import 'route_names.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.splash,
  routes: [
    GoRoute(
      path: RouteNames.splash,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: RouteNames.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: RouteNames.islandMap,
      builder: (_, state) => IslandMapScreen(
        islandId: state.pathParameters['id'] ?? 'starter',
      ),
    ),
    GoRoute(
      path: RouteNames.collection,
      builder: (_, __) => const CollectionScreen(),
    ),
    GoRoute(
      path: RouteNames.lesson,
      builder: (_, state) => LessonScreen(
        topicId: int.tryParse(state.pathParameters['topicId'] ?? '') ?? 1,
        islandId: state.uri.queryParameters['islandId'],
      ),
    ),
    GoRoute(
      path: RouteNames.profile,
      builder: (_, __) => const ProfileScreen(),
    ),
    GoRoute(
      path: RouteNames.learningIsland,
      builder: (_, __) => const LearningIslandScreen(),
    ),
  ],
);
