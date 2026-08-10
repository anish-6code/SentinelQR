import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/verdict/presentation/verdict_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/home/presentation/home_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/verdict',
        name: 'verdict',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return VerdictScreen(analysisResult: extra);
        },
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
