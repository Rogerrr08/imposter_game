import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/game_setup/game_setup_screen.dart';
import '../screens/game_play/role_reveal_screen.dart';
import '../screens/game_play/game_play_screen.dart';
import '../screens/game_play/vote_screen.dart';
import '../screens/game_play/impostor_guess_screen.dart';
import '../screens/game_results/game_results_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/groups/group_detail_screen.dart';
import '../screens/rankings/rankings_screen.dart';
import '../screens/rankings/game_history_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          final groupId = state.extra as int?;
          return GameSetupScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/role-reveal',
        builder: (context, state) => const RoleRevealScreen(),
      ),
      GoRoute(
        path: '/play',
        builder: (context, state) => const GamePlayScreen(),
      ),
      GoRoute(
        path: '/vote',
        builder: (context, state) => const VoteScreen(),
      ),
      GoRoute(
        path: '/impostor-guess',
        builder: (context, state) => const ImpostorGuessScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const GameResultsScreen(),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return GroupDetailScreen(groupId: id);
        },
      ),
      GoRoute(
        path: '/rankings/:groupId',
        builder: (context, state) {
          final groupId = int.parse(state.pathParameters['groupId']!);
          return RankingsScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/history/:groupId',
        builder: (context, state) {
          final groupId = int.parse(state.pathParameters['groupId']!);
          return GameHistoryScreen(groupId: groupId);
        },
      ),
    ],
  );
}
