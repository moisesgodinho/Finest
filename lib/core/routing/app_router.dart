import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/accounts_page.dart';
import '../../features/auth/login/login_page.dart';
import '../../features/cards/credit_card_invoice_page.dart';
import '../../features/categories/categories_page.dart';
import '../../features/goals/goals_page.dart';
import '../../features/home/home_page.dart';
import '../../features/investments/investments_page.dart';
import '../../features/pet/pet_page.dart';
import '../../features/quotes/quotes_page.dart';
import '../../features/reports/reports_page.dart';
import '../../features/transactions/transactions_page.dart';
import '../../features/transactions/transactions_view_model.dart';
import '../auth/auth_service.dart';

class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const login = '/login';
  static const home = '/home';
  static const accountDetails = '/accounts/:accountId';
  static const categories = '/categories';
  static const goals = '/goals';
  static const goalDetails = '/goals/:goalId';
  static const transactions = '/transactions';
  static const transactionDetails = '/transactions/:kind/:transactionId';
  static const cardTransactionDetails = '/card-transactions/:transactionId';
  static const investments = '/investments';
  static const pet = '/pet';
  static const quotes = '/quotes';
  static const reports = '/reports';
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
        path: AppRoutes.accountDetails,
        name: 'accountDetails',
        builder: (context, state) {
          final accountId = int.tryParse(
                state.pathParameters['accountId'] ?? '',
              ) ??
              -1;
          return AccountDetailPage(accountId: accountId);
        },
      ),
      GoRoute(
        path: AppRoutes.categories,
        name: 'categories',
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.goals,
        name: 'goals',
        builder: (context, state) => const GoalsPage(),
        routes: [
          GoRoute(
            path: ':goalId',
            name: 'goalDetails',
            builder: (context, state) {
              final goalId = int.tryParse(
                    state.pathParameters['goalId'] ?? '',
                  ) ??
                  -1;
              return GoalDetailPage(goalId: goalId);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionsPage(),
      ),
      GoRoute(
        path: AppRoutes.transactionDetails,
        name: 'transactionDetails',
        builder: (context, state) {
          final kind = switch (state.pathParameters['kind']) {
            'transfer' => TransactionEntryKind.transfer,
            _ => TransactionEntryKind.transaction,
          };
          final transactionId = int.tryParse(
                state.pathParameters['transactionId'] ?? '',
              ) ??
              -1;
          return TransactionDetailPage(
            kind: kind,
            transactionId: transactionId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.cardTransactionDetails,
        name: 'cardTransactionDetails',
        builder: (context, state) {
          final transactionId = int.tryParse(
                state.pathParameters['transactionId'] ?? '',
              ) ??
              -1;
          return CreditCardTransactionDetailPage(
            transactionId: transactionId,
          );
        },
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
      GoRoute(
        path: AppRoutes.quotes,
        name: 'quotes',
        builder: (context, state) => const QuotesPage(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (context, state) => const ReportsPage(),
      ),
    ],
  );
});
