import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/investments/investments_page.dart';
import '../../features/pet/pet_page.dart';
import '../../features/transactions/transactions_page.dart';
import '../auth/auth_service.dart';

class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const login = '/login';
  static const home = '/home';
  static const transactions = '/transactions';
  static const investments = '/investments';
  static const pet = '/pet';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation:
        authState.isAuthenticated ? AppRoutes.home : AppRoutes.login,
    redirect: (context, state) {
      final isGoingToLogin = state.matchedLocation == AppRoutes.login;

      if (!authState.isAuthenticated && !isGoingToLogin) {
        return AppRoutes.login;
      }

      if (authState.isAuthenticated && isGoingToLogin) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) {
          return authState.isAuthenticated ? AppRoutes.home : AppRoutes.login;
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionsPage(),
      ),
      GoRoute(
        path: AppRoutes.investments,
        name: 'investments',
        builder: (context, state) => const InvestmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.pet,
        name: 'pet',
        builder: (context, state) => const PetPage(),
      ),
    ],
  );
});
