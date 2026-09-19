import 'package:go_router/go_router.dart';

import '../models/sport_type.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/group/chat_list_screen.dart';
import '../screens/group/group_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/matches/matches_hub_screen.dart';
import '../screens/matches/matches_screen.dart';
import '../screens/plan/new_activity_screen.dart';
import '../screens/plan/plan_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/supabase_service.dart';
import 'go_router_refresh_stream.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      SupabaseService.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final loggedIn = SupabaseService.currentUserId != null;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/plan', builder: (_, _) => const PlanScreen()),
      GoRoute(
        path: '/new-activity',
        builder: (context, state) => NewActivityScreen(
          initialSport: SportType.values.firstWhere(
            (s) => s.name == state.uri.queryParameters['sport'],
            orElse: () => SportType.laufen,
          ),
        ),
      ),
      GoRoute(path: '/matches', builder: (_, _) => const MatchesHubScreen()),
      GoRoute(
        path: '/matches/:activityId',
        builder: (context, state) => MatchesScreen(
          activityId: state.pathParameters['activityId']!,
        ),
      ),
      GoRoute(path: '/chat', builder: (_, _) => const ChatListScreen()),
      GoRoute(
        path: '/group/:id',
        builder: (context, state) =>
            GroupScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    ],
  );
}
