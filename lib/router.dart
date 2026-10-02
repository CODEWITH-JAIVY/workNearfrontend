import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/select_role_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/customer/job_detail_screen.dart';
import 'features/customer/post_job_screen.dart';
import 'features/shell/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/login',
    redirect: (ctx, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;
      final s = auth.value;
      final loc = state.matchedLocation;
      if (s == null) return loc == '/login' ? null : '/login';
      if (s.needsRole) return loc == '/select-role' ? null : '/select-role';
      if (loc == '/login' || loc == '/select-role') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/select-role', builder: (_, __) => const SelectRoleScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) {
          final s = ref.read(authProvider).value;
          if (s?.userType == 'ADMIN') {
            return const Scaffold(body: Center(child: Text('Admins: please use the web dashboard')));
          }
          return Shell(labour: s?.isLabour ?? false);
        },
      ),
      GoRoute(path: '/post', builder: (_, __) => const PostJobScreen()),
      GoRoute(path: '/job/:id', builder: (_, s) => JobDetailScreen(jobId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(jobId: int.parse(s.pathParameters['id']!))),
    ],
  );
});
