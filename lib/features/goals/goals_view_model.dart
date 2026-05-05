import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_account_request.dart';
import '../../data/models/update_account_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/monthly_plan_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class GoalsState {
  const GoalsState({
    required this.selectedMonth,
    required this.accounts,
    this.monthlyPlan,
    this.currentIncomeCents = 0,
    this.currentExpenseCents = 0,
    this.monthlyExpenseAverageCents = 0,
    this.suggestedEmergencyReserveCents = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  factory GoalsState.initial() {
    final now = DateTime.now();
    return GoalsState(
      selectedMonth: DateTime(now.year, now.month),
      accounts: const [],
      isLoading: true,
    );
  }

  final DateTime selectedMonth;
  final List<AccountPreview> accounts;
  final MonthlyPlan? monthlyPlan;
  final int currentIncomeCents;
  final int currentExpenseCents;
  final int monthlyExpenseAverageCents;
  final int suggestedEmergencyReserveCents;
  final bool isLoading;
  final String? errorMessage;

  String get monthLabel => AppDateUtils.monthYearLabel(selectedMonth);

  AccountPreview? get emergencyReserveAccount {
    for (final account in accounts) {
      if (!account.isGoal && account.emergencyReserveTargetCents != null) {
        return account;
      }
    }

    for (final account in accounts) {
      if (!account.isGoal && account.isEmergencyReserve) {
        return account;
      }
    }

    return null;
  }

  int get emergencyReserveBalanceCents {
    return emergencyReserveAccount?.balanceCents ?? 0;
  }

  int get emergencyReserveTargetCents {
    return emergencyReserveAccount?.emergencyReserveTargetCents ??
        suggestedEmergencyReserveCents;
  }

  int get emergencyReserveRemainingCents {
    final target = emergencyReserveTargetCents;
    return (target - emergencyReserveBalanceCents).clamp(0, target).toInt();
  }

  double get emergencyReserveProgress {
    final target = emergencyReserveTargetCents;
    if (target <= 0) {
      return 0;
    }
    return (emergencyReserveBalanceCents / target).clamp(0.0, 1.0).toDouble();
  }

  int get plannedExpenseCents => monthlyPlan?.plannedExpense ?? 0;

  int get plannedIncomeCents => monthlyPlan?.plannedIncome ?? 0;

  int get availableBudgetCents => plannedExpenseCents - currentExpenseCents;

  double get budgetUsageProgress {
    if (plannedExpenseCents <= 0) {
      return 0;
    }
    return (currentExpenseCents / plannedExpenseCents)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get budgetHealthScore {
    if (plannedExpenseCents <= 0) {
      return 0;
    }
    if (currentExpenseCents <= plannedExpenseCents) {
      return 1;
    }
    return (plannedExpenseCents / currentExpenseCents)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int get monthlySavingsCents => currentIncomeCents - currentExpenseCents;

  int get monthlySavingsTargetCents => (currentIncomeCents * 0.10).round();

  double get monthlySavingsProgress {
    final target = monthlySavingsTargetCents;
    if (target <= 0) {
      return 0;
    }
    return (monthlySavingsCents / target).clamp(0.0, 1.0).toDouble();
  }

  double get savingsRate {
    if (currentIncomeCents <= 0) {
      return 0;
    }
    return monthlySavingsCents / currentIncomeCents;
  }

  int get activeGoalsCount {
    var count = goalAccounts.length;
    if (emergencyReserveTargetCents > 0) {
      count++;
    }
    if (plannedExpenseCents > 0) {
      count++;
    }
    if (monthlySavingsTargetCents > 0) {
      count++;
    }
    return count;
  }

  double get overallProgress {
    final scores = <double>[
      for (final goal in goalAccounts)
        if ((goal.emergencyReserveTargetCents ?? 0) > 0)
          (goal.balanceCents / goal.emergencyReserveTargetCents!)
              .clamp(0.0, 1.0)
              .toDouble(),
      if (emergencyReserveTargetCents > 0) emergencyReserveProgress,
      if (plannedExpenseCents > 0) budgetHealthScore,
      if (monthlySavingsTargetCents > 0) monthlySavingsProgress,
    ];

    if (scores.isEmpty) {
      return 0;
    }

    return scores.fold<double>(0, (total, score) => total + score) /
        scores.length;
  }

  List<AccountPreview> get goalAccounts {
    return accounts.where((account) => account.isGoal).toList();
  }

  int get goalBalanceCents {
    return goalAccounts.fold<int>(
      0,
      (total, account) => total + account.balanceCents,
    );
  }

  int get goalTargetCents {
    return goalAccounts.fold<int>(
      0,
      (total, account) => total + (account.emergencyReserveTargetCents ?? 0),
    );
  }

  double get goalProgress {
    final target = goalTargetCents;
    if (target <= 0) {
      return 0;
    }
    return (goalBalanceCents / target).clamp(0.0, 1.0).toDouble();
  }

  GoalsState copyWith({
    DateTime? selectedMonth,
    List<AccountPreview>? accounts,
    MonthlyPlan? monthlyPlan,
    bool clearMonthlyPlan = false,
    int? currentIncomeCents,
    int? currentExpenseCents,
    int? monthlyExpenseAverageCents,
    int? suggestedEmergencyReserveCents,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GoalsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      accounts: accounts ?? this.accounts,
      monthlyPlan: clearMonthlyPlan ? null : monthlyPlan ?? this.monthlyPlan,
      currentIncomeCents: currentIncomeCents ?? this.currentIncomeCents,
      currentExpenseCents: currentExpenseCents ?? this.currentExpenseCents,
      monthlyExpenseAverageCents:
          monthlyExpenseAverageCents ?? this.monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          suggestedEmergencyReserveCents ?? this.suggestedEmergencyReserveCents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class GoalsViewModel extends StateNotifier<GoalsState> {
  GoalsViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required MonthlyPlanRepository monthlyPlanRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _monthlyPlanRepository = monthlyPlanRepository,
        _transactionRepository = transactionRepository,
        super(GoalsState.initial()) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final MonthlyPlanRepository _monthlyPlanRepository;
  final TransactionRepository _transactionRepository;

  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<MonthlyPlan?>? _monthlyPlanSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;

  List<AccountPreview> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  MonthlyPlan? _monthlyPlan;

  Future<void> createGoal({
    required String name,
    required int targetCents,
    required int initialBalanceCents,
    required bool includeInTotalBalance,
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.createAccount(
        CreateAccountRequest(
          userId: userId,
          name: name,
          type: 'goal',
          bankName: 'Meta financeira',
          initialBalance: initialBalanceCents,
          emergencyReserveTarget: targetCents,
          includeInTotalBalance: includeInTotalBalance,
          color: color,
          icon: 'flag',
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateGoal({
    required AccountPreview goal,
    required String name,
    required int targetCents,
    required bool includeInTotalBalance,
    String? color,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.updateAccount(
        UpdateAccountRequest(
          id: goal.id,
          userId: userId,
          name: name,
          type: 'goal',
          bankName: goal.bankName,
          initialBalance: goal.balanceCents,
          currentBalance: goal.balanceCents,
          currencyCode: goal.currencyCode,
          emergencyReserveTarget: targetCents,
          includeInTotalBalance: includeInTotalBalance,
          color: color ?? goal.colorHex,
          icon: 'flag',
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = GoalsState.initial().copyWith(isLoading: false);
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts.map(_mapAccount).toList();
        _publishState();
      },
      onError: _publishError,
    );

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState();
      },
      onError: _publishError,
    );

    _monthlyPlanSubscription = _monthlyPlanRepository
        .watchPlan(
      userId: userId,
      month: state.selectedMonth.month,
      year: state.selectedMonth.year,
    )
        .listen(
      (plan) {
        _monthlyPlan = plan;
        _publishState();
      },
      onError: _publishError,
    );
  }

  void _publishState() {
    final firstDay = AppDateUtils.firstDayOfMonth(state.selectedMonth);
    final lastDay = AppDateUtils.lastDayOfMonth(state.selectedMonth);
    final monthTransactions = _transactions.where((transaction) {
      final referenceDate = _referenceDate(transaction);
      return !referenceDate.isBefore(firstDay) &&
          !referenceDate.isAfter(lastDay);
    }).toList();

    final currentIncomeCents = monthTransactions
        .where(
          (transaction) =>
              transaction.type == 'income' &&
              transaction.paymentMethod != 'credit_card',
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final currentExpenseCents = monthTransactions
        .where((transaction) => transaction.type == 'expense')
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final monthlyExpenseAverageCents = _calculateMonthlyExpenseAverageCents();

    state = state.copyWith(
      accounts: _accounts,
      monthlyPlan: _monthlyPlan,
      clearMonthlyPlan: _monthlyPlan == null,
      currentIncomeCents: currentIncomeCents,
      currentExpenseCents: currentExpenseCents,
      monthlyExpenseAverageCents: monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          _reserveTargetFor(monthlyExpenseAverageCents),
      isLoading: false,
      clearError: true,
    );
  }

  int _calculateMonthlyExpenseAverageCents() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 2);
    final end = DateTime(now.year, now.month + 1);
    final totalsByMonth = <int, int>{};

    for (final transaction in _transactions) {
      if (transaction.type != 'expense' || !transaction.isPaid) {
        continue;
      }

      final referenceDate = _referenceDate(transaction);
      if (referenceDate.isBefore(start) || !referenceDate.isBefore(end)) {
        continue;
      }

      final monthKey = referenceDate.year * 12 + referenceDate.month;
      totalsByMonth.update(
        monthKey,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    if (totalsByMonth.isEmpty) {
      return 0;
    }

    final total =
        totalsByMonth.values.fold<int>(0, (sum, value) => sum + value);
    return (total / totalsByMonth.length).round();
  }

  int _reserveTargetFor(int monthlyExpenseAverageCents) {
    if (monthlyExpenseAverageCents <= 0) {
      return 0;
    }

    const roundingUnit = 10000;
    final sixMonthTarget = monthlyExpenseAverageCents * 6;
    return ((sixMonthTarget + roundingUnit - 1) ~/ roundingUnit) * roundingUnit;
  }

  DateTime _referenceDate(FinanceTransaction transaction) {
    if (transaction.paymentMethod == 'credit_card' &&
        transaction.invoiceMonth != null &&
        transaction.invoiceYear != null) {
      return DateTime(transaction.invoiceYear!, transaction.invoiceMonth!);
    }

    return transaction.dueDate ?? transaction.date;
  }

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      balanceCents: account.currentBalance,
      currencyCode: account.currencyCode,
      includeInTotalBalance: account.includeInTotalBalance,
      emergencyReserveTargetCents: account.emergencyReserveTarget,
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  void _publishError(Object error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: error.toString(),
    );
  }

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _monthlyPlanSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final goalsViewModelProvider =
    StateNotifierProvider.autoDispose<GoalsViewModel, GoalsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return GoalsViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    monthlyPlanRepository: ref.watch(monthlyPlanRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
