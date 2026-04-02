import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/home/how_to_play_screen.dart';
import '../screens/game_setup/game_setup_screen.dart';
import '../screens/game_play/role_reveal_screen.dart';
import '../screens/game_play/round_start_screen.dart';
import '../screens/game_play/game_play_screen.dart';
import '../screens/game_play/vote_screen.dart';
import '../screens/game_play/impostor_guess_screen.dart';
import '../screens/game_play/classic_impostor_choice_screen.dart';
import '../screens/game_play/action_reveal_screen.dart';
import '../screens/game_results/game_results_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/groups/group_detail_screen.dart';
import '../screens/rankings/rankings_screen.dart';
import '../screens/rankings/game_history_screen.dart';
import '../models/action_reveal.dart';
import '../features/online/presentation/create_room_screen.dart';
import '../features/online/presentation/display_name_screen.dart';
import '../features/online/presentation/join_room_screen.dart';
import '../features/online/presentation/online_home_screen.dart';
import '../features/online/presentation/room_lobby_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildPage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/how-to-play',
        pageBuilder: (context, state) =>
            _buildPage(state, const HowToPlayScreen()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) {
          final groupId = state.extra as int?;
          return _buildPage(state, GameSetupScreen(groupId: groupId));
        },
      ),
      GoRoute(
        path: '/role-reveal',
        pageBuilder: (context, state) =>
            _buildPage(state, const RoleRevealScreen()),
      ),
      GoRoute(
        path: '/round-start',
        builder: (context, state) => const RoundStartScreen(),
      ),
      GoRoute(
        path: '/play',
        pageBuilder: (context, state) =>
            _buildPage(state, const GamePlayScreen()),
      ),
      GoRoute(
        path: '/vote',
        pageBuilder: (context, state) => _buildPage(state, const VoteScreen()),
      ),
      GoRoute(
        path: '/impostor-guess',
        pageBuilder: (context, state) =>
            _buildPage(state, const ImpostorGuessScreen()),
      ),
      GoRoute(
        path: '/classic-impostor-choice',
        pageBuilder: (context, state) =>
            _buildPage(state, const ClassicImpostorChoiceScreen()),
      ),
      GoRoute(
        path: '/action-reveal',
        builder: (context, state) {
          final reveal = state.extra as ActionRevealData;
          return ActionRevealScreen(reveal: reveal);
        },
      ),
      GoRoute(
        path: '/results',
        pageBuilder: (context, state) =>
            _buildPage(state, const GameResultsScreen()),
      ),
      GoRoute(
        path: '/online',
        pageBuilder: (context, state) =>
            _buildPage(state, const OnlineHomeScreen()),
      ),
      GoRoute(
        path: '/online/create-room',
        pageBuilder: (context, state) =>
            _buildPage(state, const CreateRoomScreen()),
      ),
      GoRoute(
        path: '/online/join-room',
        pageBuilder: (context, state) =>
            _buildPage(state, const JoinRoomScreen()),
      ),
      GoRoute(
        path: '/online/room/:roomId',
        pageBuilder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return _buildPage(state, RoomLobbyScreen(roomId: roomId));
        },
      ),
      GoRoute(
        path: '/online/display-name',
        pageBuilder: (context, state) =>
            _buildPage(state, const DisplayNameScreen()),
      ),
      GoRoute(
        path: '/groups',
        pageBuilder: (context, state) =>
            _buildPage(state, const GroupsScreen()),
      ),
      GoRoute(
        path: '/groups/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _buildPage(state, GroupDetailScreen(groupId: id));
        },
      ),
      GoRoute(
        path: '/rankings/:groupId',
        pageBuilder: (context, state) {
          final groupId = int.parse(state.pathParameters['groupId']!);
          return _buildPage(state, RankingsScreen(groupId: groupId));
        },
      ),
      GoRoute(
        path: '/history/:groupId',
        pageBuilder: (context, state) {
          final groupId = int.parse(state.pathParameters['groupId']!);
          return _buildPage(state, GameHistoryScreen(groupId: groupId));
        },
      ),
    ],
  );

  static CustomTransitionPage<void> _buildPage(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, _, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
