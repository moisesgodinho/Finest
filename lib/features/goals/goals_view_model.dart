import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_account_request.dart';
import '../../data/models/create_goal_request.dart';
import '../../data/models/goal_preview.dart';
import '../../data/models/update_goal_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/monthly_plan_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transfer_repository.dart';

class GoalsState {
  const GoalsState({
    required this.selectedMonth,
    required this.accounts,
    required this.goals,
    this.monthlyPlan,
    this.currentIncomeCents = 0,
    this.currentExpenseCents = 0,
    this.monthlyExpenseAverageCents = 0,
    this.suggestedEmergencyReserveCents = 0,
    this.balanceSeriesByGoalId = const {},
    this.projectionsByGoalId = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  factory GoalsState.initial() {
    final now = DateTime.now();
    return GoalsState(
      selectedMonth: DateTime(now.year, now.month),
      accounts: const [],
      goals: const [],
      isLoading: true,
    );
  }

  final DateTime selectedMonth;
  final List<AccountPreview> accounts;
  final List<GoalPreview> goals;
  final MonthlyPlan? monthlyPlan;
  final int currentIncomeCents;
  final int currentExpenseCents;
  final int monthlyExpenseAverageCents;
  final int suggestedEmergencyReserveCents;
  final Map<int, List<GoalBalancePoint>> balanceSeriesByGoalId;
  final Map<int, GoalProjection> projectionsByGoalId;
  final bool isLoading;
  final String? errorMessage;

  String get monthLabel => AppDateUtils.monthYearLabel(selectedMonth);

  AccountPreview? get emergencyReserveAccount {
    for (final account in accounts) {
      if (account.emergencyReserveTargetCents != null) {
        return account;
      }
    }

    for (final account in accounts) {
      if (account.isEmergencyReserve) {
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
    return goals.length;
  }

  double get overallProgress {
    return goalProgress;
  }

  List<GoalPreview> get goalAccounts {
    return goals;
  }

  List<AccountPreview> get linkedAccountOptions {
    return accounts;
  }

  AccountPreview? linkedAccountFor(GoalPreview goal) {
    final linkedAccountId = goal.linkedAccountId;
    if (linkedAccountId == null) {
      return null;
    }

    for (final account in accounts) {
      if (account.id == linkedAccountId) {
        return account;
      }
    }
    return null;
  }

  int get goalBalanceCents {
    return goals.fold<int>(
      0,
      (total, goal) => total + goalProgressBalanceCents(goal),
    );
  }

  int get goalTargetCents {
    return goals.fold<int>(
      0,
      (total, goal) => total + goal.targetAmountCents,
    );
  }

  double get goalProgress {
    final target = goalTargetCents;
    if (target <= 0) {
      return 0;
    }
    return (goalBalanceCents / target).clamp(0.0, 1.0).toDouble();
  }

  int goalProgressBalanceCents(GoalPreview goal) {
    return linkedAccountFor(goal)?.balanceCents ?? 0;
  }

  List<GoalBalancePoint> balanceSeriesFor(GoalPreview goal) {
    return balanceSeriesByGoalId[goal.id] ?? const [];
  }

  GoalProjection? projectionFor(GoalPreview goal) {
    return projectionsByGoalId[goal.id];
  }

  GoalPreview? goalById(int goalId) {
    for (final goal in goals) {
      if (goal.id == goalId) {
        return goal;
      }
    }
    return null;
  }

  GoalsState copyWith({
    DateTime? selectedMonth,
    List<AccountPreview>? accounts,
    List<GoalPreview>? goals,
    MonthlyPlan? monthlyPlan,
    bool clearMonthlyPlan = false,
    int? currentIncomeCents,
    int? currentExpenseCents,
    int? monthlyExpenseAverageCents,
    int? suggestedEmergencyReserveCents,
    Map<int, List<GoalBalancePoint>>? balanceSeriesByGoalId,
    Map<int, GoalProjection>? projectionsByGoalId,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GoalsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      accounts: accounts ?? this.accounts,
      goals: goals ?? this.goals,
      monthlyPlan: clearMonthlyPlan ? null : monthlyPlan ?? this.monthlyPlan,
      currentIncomeCents: currentIncomeCents ?? this.currentIncomeCents,
      currentExpenseCents: currentExpenseCents ?? this.currentExpenseCents,
      monthlyExpenseAverageCents:
          monthlyExpenseAverageCents ?? this.monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          suggestedEmergencyReserveCents ?? this.suggestedEmergencyReserveCents,
      balanceSeriesByGoalId:
          balanceSeriesByGoalId ?? this.balanceSeriesByGoalId,
      projectionsByGoalId: projectionsByGoalId ?? this.projectionsByGoalId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class GoalBalancePoint {
  const GoalBalancePoint({
    required this.month,
    required this.balanceCents,
  });

  final DateTime month;
  final int balanceCents;
}

class GoalProjection {
  const GoalProjection({
    required this.currentBalanceCents,
    required this.targetCents,
    required this.remainingCents,
    required this.monthsToTarget,
    required this.requiredMonthlyWithoutYieldCents,
    required this.requiredMonthlyWithYieldCents,
    required this.averageMonthlyYieldRate,
    required this.averageAnnualYieldRate,
    required this.yieldHistoryMonths,
    required this.averageMonthlyContributionCents,
    required this.estimatedMonthlyYieldCents,
    required this.projectedFinalBalanceCents,
    required this.projectedTotalInvestedCents,
    required this.projectedInterestCents,
    required this.projectedMonths,
    required this.targetReachedAt,
    required this.estimatedCompletionWithoutYield,
    required this.estimatedCompletionWithYield,
    required this.points,
    required this.monthlyRows,
    required this.annualRows,
  });

  final int currentBalanceCents;
  final int targetCents;
  final int remainingCents;
  final int monthsToTarget;
  final int requiredMonthlyWithoutYieldCents;
  final int requiredMonthlyWithYieldCents;
  final double averageMonthlyYieldRate;
  final double averageAnnualYieldRate;
  final int yieldHistoryMonths;
  final int averageMonthlyContributionCents;
  final int estimatedMonthlyYieldCents;
  final int projectedFinalBalanceCents;
  final int projectedTotalInvestedCents;
  final int projectedInterestCents;
  final int projectedMonths;
  final DateTime? targetReachedAt;
  final DateTime? estimatedCompletionWithoutYield;
  final DateTime? estimatedCompletionWithYield;
  final List<GoalProjectionPoint> points;
  final List<GoalProjectionMonth> monthlyRows;
  final List<GoalProjectionYear> annualRows;

  bool get hasYieldHistory =>
      yieldHistoryMonths > 0 && averageMonthlyYieldRate > 0;

  bool get hasContributionPace => averageMonthlyContributionCents > 0;
}

class GoalProjectionPoint {
  const GoalProjectionPoint({
    required this.month,
    required this.balanceWithoutYieldCents,
    required this.balanceWithYieldCents,
  });

  final DateTime month;
  final int balanceWithoutYieldCents;
  final int balanceWithYieldCents;
}

class GoalProjectionMonth {
  const GoalProjectionMonth({
    required this.monthNumber,
    required this.month,
    required this.contributionCents,
    required this.monthlyInterestCents,
    required this.accumulatedInterestCents,
    required this.totalInvestedCents,
    required this.projectedBalanceCents,
    required this.reachesTarget,
  });

  final int monthNumber;
  final DateTime month;
  final int contributionCents;
  final int monthlyInterestCents;
  final int accumulatedInterestCents;
  final int totalInvestedCents;
  final int projectedBalanceCents;
  final bool reachesTarget;
}

class GoalProjectionYear {
  const GoalProjectionYear({
    required this.yearNumber,
    required this.month,
    required this.totalInvestedCents,
    required this.accumulatedInterestCents,
    required this.projectedBalanceCents,
  });

  final int yearNumber;
  final DateTime month;
  final int totalInvestedCents;
  final int accumulatedInterestCents;
  final int projectedBalanceCents;
}

class GoalsViewModel extends StateNotifier<GoalsState> {
  GoalsViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CreditCardRepository creditCardRepository,
    required GoalRepository goalRepository,
    required MonthlyPlanRepository monthlyPlanRepository,
    required TransactionRepository transactionRepository,
    required TransferRepository transferRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _creditCardRepository = creditCardRepository,
        _goalRepository = goalRepository,
        _monthlyPlanRepository = monthlyPlanRepository,
        _transactionRepository = transactionRepository,
        _transferRepository = transferRepository,
        super(GoalsState.initial()) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CreditCardRepository _creditCardRepository;
  final GoalRepository _goalRepository;
  final MonthlyPlanRepository _monthlyPlanRepository;
  final TransactionRepository _transactionRepository;
  final TransferRepository _transferRepository;

  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<Goal>>? _goalsSubscription;
  StreamSubscription<List<CreditCardInvoice>>? _invoicesSubscription;
  StreamSubscription<MonthlyPlan?>? _monthlyPlanSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  StreamSubscription<List<AccountTransfer>>? _transfersSubscription;

  List<AccountPreview> _accounts = [];
  List<GoalPreview> _goals = [];
  List<CreditCardInvoice> _invoices = [];
  List<FinanceTransaction> _transactions = [];
  List<AccountTransfer> _transfers = [];
  MonthlyPlan? _monthlyPlan;

  static const _yieldPaymentMethod = 'account_yield';

  Future<void> createGoal({
    required String name,
    required int targetCents,
    required DateTime targetDate,
    required int? linkedAccountId,
    required GoalLinkedAccountDraft? linkedAccountDraft,
    required bool includeInTotalBalance,
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final effectiveLinkedAccountId = linkedAccountId ??
          await _createLinkedAccountIfNeeded(
            userId: userId,
            draft: linkedAccountDraft,
            includeInTotalBalance: includeInTotalBalance,
          );

      if (effectiveLinkedAccountId == null) {
        throw StateError('Escolha ou crie uma conta vinculada.');
      }

      await _accountRepository.updateIncludeInTotalBalance(
        userId: userId,
        accountId: effectiveLinkedAccountId,
        includeInTotalBalance: includeInTotalBalance,
      );

      await _goalRepository.createGoal(
        CreateGoalRequest(
          userId: userId,
          name: name,
          linkedAccountId: effectiveLinkedAccountId,
          targetAmountCents: targetCents,
          targetDate: targetDate,
          color: color,
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
    required GoalPreview goal,
    required String name,
    required int targetCents,
    required DateTime targetDate,
    required int? linkedAccountId,
    required GoalLinkedAccountDraft? linkedAccountDraft,
    required bool includeInTotalBalance,
    String? color,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final effectiveLinkedAccountId = linkedAccountId ??
          await _createLinkedAccountIfNeeded(
            userId: userId,
            draft: linkedAccountDraft,
            includeInTotalBalance: includeInTotalBalance,
          );

      if (effectiveLinkedAccountId == null) {
        throw StateError('Escolha ou crie uma conta vinculada.');
      }

      await _accountRepository.updateIncludeInTotalBalance(
        userId: userId,
        accountId: effectiveLinkedAccountId,
        includeInTotalBalance: includeInTotalBalance,
      );

      await _goalRepository.updateGoal(
        UpdateGoalRequest(
          id: goal.id,
          userId: userId,
          name: name,
          linkedAccountId: effectiveLinkedAccountId,
          targetAmountCents: targetCents,
          targetDate: targetDate,
          color: color ?? goal.colorHex,
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

  Future<void> deleteGoal(GoalPreview goal) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _goalRepository.deleteGoal(
        userId: userId,
        goalId: goal.id,
      );
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<int?> _createLinkedAccountIfNeeded({
    required int userId,
    required GoalLinkedAccountDraft? draft,
    required bool includeInTotalBalance,
  }) async {
    if (draft == null) {
      return null;
    }

    return _accountRepository.createAccount(
      CreateAccountRequest(
        userId: userId,
        name: draft.name,
        type: 'savings',
        bankName: draft.bankName,
        initialBalance: draft.initialBalanceCents,
        includeInTotalBalance: includeInTotalBalance,
        currencyCode: draft.currencyCode,
        color: draft.color,
        icon: 'wallet',
      ),
    );
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

    _goalsSubscription = _goalRepository.watchGoals(userId).listen(
      (goals) {
        _goals = goals.map(_mapGoal).toList();
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

    _transfersSubscription = _transferRepository.watchTransfers(userId).listen(
      (transfers) {
        _transfers = transfers;
        _publishState();
      },
      onError: _publishError,
    );

    _invoicesSubscription = _creditCardRepository.watchInvoices(userId).listen(
      (invoices) {
        _invoices = invoices;
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
    final accounts = [
      for (final account in _accounts)
        _withMonthBalance(
          account,
          balanceCents: _balanceForMonth(account, state.selectedMonth),
        ),
    ];
    final accountsById = {for (final account in accounts) account.id: account};
    final balanceSeriesByGoalId = <int, List<GoalBalancePoint>>{
      for (final goal in _goals)
        goal.id: _balanceSeriesForGoal(goal, accountsById),
    };
    final projectionsByGoalId = <int, GoalProjection>{
      for (final goal in _goals)
        goal.id: _projectionForGoal(
          goal,
          accountsById[goal.linkedAccountId],
        ),
    };
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
      accounts: accounts,
      goals: _goals,
      monthlyPlan: _monthlyPlan,
      clearMonthlyPlan: _monthlyPlan == null,
      currentIncomeCents: currentIncomeCents,
      currentExpenseCents: currentExpenseCents,
      monthlyExpenseAverageCents: monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          _reserveTargetFor(monthlyExpenseAverageCents),
      balanceSeriesByGoalId: balanceSeriesByGoalId,
      projectionsByGoalId: projectionsByGoalId,
      isLoading: false,
      clearError: true,
    );
  }

  GoalProjection _projectionForGoal(
    GoalPreview goal,
    AccountPreview? account,
  ) {
    final currentMonth = _monthOnly(DateTime.now());
    final currentBalanceCents =
        account == null ? 0 : _balanceForMonth(account, currentMonth);
    final targetCents = goal.targetAmountCents;
    final remainingCents =
        (targetCents - currentBalanceCents).clamp(0, targetCents).toInt();
    final monthsToTarget = _monthsToTarget(goal.targetDate);
    final yieldStats =
        account == null ? _GoalYieldStats.empty : _yieldStatsFor(account);
    final averageMonthlyContributionCents =
        account == null ? 0 : _averageMonthlyContributionCents(account);
    final requiredMonthlyWithoutYieldCents =
        _requiredMonthlyWithoutYield(remainingCents, monthsToTarget);
    final requiredMonthlyWithYieldCents = _requiredMonthlyWithYield(
      currentBalanceCents: currentBalanceCents,
      targetCents: targetCents,
      monthsToTarget: monthsToTarget,
      monthlyYieldRate: yieldStats.averageMonthlyRate,
      fallbackCents: requiredMonthlyWithoutYieldCents,
    );
    final compoundProjection = _compoundProjection(
      currentBalanceCents: currentBalanceCents,
      targetCents: targetCents,
      monthsToTarget: monthsToTarget,
      averageMonthlyContributionCents: averageMonthlyContributionCents,
      monthlyYieldRate: yieldStats.averageMonthlyRate,
    );

    return GoalProjection(
      currentBalanceCents: currentBalanceCents,
      targetCents: targetCents,
      remainingCents: remainingCents,
      monthsToTarget: monthsToTarget,
      requiredMonthlyWithoutYieldCents: requiredMonthlyWithoutYieldCents,
      requiredMonthlyWithYieldCents: requiredMonthlyWithYieldCents,
      averageMonthlyYieldRate: yieldStats.averageMonthlyRate,
      averageAnnualYieldRate: yieldStats.averageMonthlyRate <= 0
          ? 0
          : math.pow(1 + yieldStats.averageMonthlyRate, 12).toDouble() - 1,
      yieldHistoryMonths: yieldStats.historyMonths,
      averageMonthlyContributionCents: averageMonthlyContributionCents,
      estimatedMonthlyYieldCents:
          (currentBalanceCents * yieldStats.averageMonthlyRate).round(),
      projectedFinalBalanceCents: compoundProjection.finalBalanceCents,
      projectedTotalInvestedCents: compoundProjection.totalInvestedCents,
      projectedInterestCents: compoundProjection.interestCents,
      projectedMonths: compoundProjection.months,
      targetReachedAt: compoundProjection.targetReachedAt,
      estimatedCompletionWithoutYield: _estimatedCompletionMonth(
        currentBalanceCents: currentBalanceCents,
        targetCents: targetCents,
        monthlyContributionCents: averageMonthlyContributionCents,
        monthlyYieldRate: 0,
      ),
      estimatedCompletionWithYield: _estimatedCompletionMonth(
        currentBalanceCents: currentBalanceCents,
        targetCents: targetCents,
        monthlyContributionCents: averageMonthlyContributionCents,
        monthlyYieldRate: yieldStats.averageMonthlyRate,
      ),
      points: compoundProjection.points,
      monthlyRows: compoundProjection.monthlyRows,
      annualRows: compoundProjection.annualRows,
    );
  }

  _GoalYieldStats _yieldStatsFor(AccountPreview account) {
    final currentMonth = _monthOnly(DateTime.now());
    final firstMonth = DateTime(currentMonth.year, currentMonth.month - 11);
    final rates = <double>[];
    var cursor = firstMonth;

    while (!cursor.isAfter(currentMonth)) {
      final monthEnd = DateTime(cursor.year, cursor.month + 1);
      final monthYieldCents = _transactions
          .where(
            (transaction) =>
                transaction.isPaid &&
                transaction.accountId == account.id &&
                transaction.type == 'income' &&
                transaction.paymentMethod == _yieldPaymentMethod &&
                !transaction.date.isBefore(cursor) &&
                transaction.date.isBefore(monthEnd),
          )
          .fold<int>(0, (total, transaction) => total + transaction.amount);
      final openingBalanceCents = _balanceBeforeDate(account, cursor);

      if (monthYieldCents > 0 && openingBalanceCents > 0) {
        rates.add(
          (monthYieldCents / openingBalanceCents).clamp(0.0, 0.20).toDouble(),
        );
      }

      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    if (rates.isEmpty) {
      return _GoalYieldStats.empty;
    }

    final averageRate =
        rates.fold<double>(0, (total, rate) => total + rate) / rates.length;
    return _GoalYieldStats(
      averageMonthlyRate: averageRate,
      historyMonths: rates.length,
    );
  }

  int _averageMonthlyContributionCents(AccountPreview account) {
    final currentMonth = _monthOnly(DateTime.now());
    final start = DateTime(currentMonth.year, currentMonth.month - 11);
    final end = DateTime(currentMonth.year, currentMonth.month + 1);
    final netContributionsByMonth = <int, int>{};

    void addContribution(DateTime date, int amountCents) {
      if (date.isBefore(start) || !date.isBefore(end)) {
        return;
      }

      final key = date.year * 12 + date.month;
      netContributionsByMonth.update(
        key,
        (value) => value + amountCents,
        ifAbsent: () => amountCents,
      );
    }

    for (final transaction in _transactions) {
      if (!transaction.isPaid ||
          transaction.accountId != account.id ||
          transaction.paymentMethod == 'credit_card' ||
          transaction.paymentMethod == _yieldPaymentMethod) {
        continue;
      }

      addContribution(
        transaction.date,
        transaction.type == 'income' ? transaction.amount : -transaction.amount,
      );
    }

    for (final transfer in _transfers) {
      if (!transfer.isPaid) {
        continue;
      }

      if (transfer.fromAccountId == account.id) {
        addContribution(transfer.date, -transfer.amount);
      }
      if (transfer.toAccountId == account.id) {
        addContribution(
          transfer.date,
          transfer.convertedAmount ?? transfer.amount,
        );
      }
    }

    for (final invoice in _invoices) {
      final paidAt = invoice.paidAt;
      if (invoice.status != 'paid' ||
          invoice.paymentAccountId != account.id ||
          paidAt == null) {
        continue;
      }

      addContribution(paidAt, -invoice.amount);
    }

    final positiveMonths = netContributionsByMonth.values
        .where((amountCents) => amountCents > 0)
        .toList();
    if (positiveMonths.isEmpty) {
      return 0;
    }

    final total =
        positiveMonths.fold<int>(0, (sum, amountCents) => sum + amountCents);
    return (total / positiveMonths.length).round();
  }

  _GoalCompoundProjection _compoundProjection({
    required int currentBalanceCents,
    required int targetCents,
    required int monthsToTarget,
    required int averageMonthlyContributionCents,
    required double monthlyYieldRate,
  }) {
    final currentMonth = _monthOnly(DateTime.now());
    final hasFixedDeadline = monthsToTarget > 0;
    final maxMonths = hasFixedDeadline ? monthsToTarget : 360;
    final points = <GoalProjectionPoint>[
      GoalProjectionPoint(
        month: currentMonth,
        balanceWithoutYieldCents: currentBalanceCents,
        balanceWithYieldCents: currentBalanceCents,
      ),
    ];
    final monthlyRows = <GoalProjectionMonth>[];
    final annualRows = <GoalProjectionYear>[];

    var balance = currentBalanceCents.toDouble();
    var totalInvested = currentBalanceCents.toDouble();
    var targetReachedAt = targetCents > 0 && currentBalanceCents >= targetCents
        ? currentMonth
        : null;

    for (var index = 1; index <= maxMonths; index++) {
      final month = DateTime(currentMonth.year, currentMonth.month + index);
      final contribution = averageMonthlyContributionCents;
      balance += contribution;
      totalInvested += contribution;

      final beforeInterest = balance;
      balance = balance * (1 + monthlyYieldRate);
      final monthlyInterestCents =
          math.max(0, (balance - beforeInterest).round());
      final accumulatedInterestCents =
          math.max(0, (balance - totalInvested).round());
      final projectedBalanceCents = math.max(0, balance.round());
      final totalInvestedCents = math.max(0, totalInvested.round());
      final reachesTarget = targetCents > 0 &&
          targetReachedAt == null &&
          projectedBalanceCents >= targetCents;

      if (reachesTarget) {
        targetReachedAt = month;
      }

      monthlyRows.add(
        GoalProjectionMonth(
          monthNumber: index,
          month: month,
          contributionCents: contribution,
          monthlyInterestCents: monthlyInterestCents,
          accumulatedInterestCents: accumulatedInterestCents,
          totalInvestedCents: totalInvestedCents,
          projectedBalanceCents: projectedBalanceCents,
          reachesTarget: reachesTarget,
        ),
      );
      points.add(
        GoalProjectionPoint(
          month: month,
          balanceWithoutYieldCents: totalInvestedCents,
          balanceWithYieldCents: projectedBalanceCents,
        ),
      );

      final isYearEnd = index % 12 == 0;
      final isLastMonth = index == maxMonths;
      if (isYearEnd || isLastMonth) {
        annualRows.add(
          GoalProjectionYear(
            yearNumber: (index / 12).ceil(),
            month: month,
            totalInvestedCents: totalInvestedCents,
            accumulatedInterestCents: accumulatedInterestCents,
            projectedBalanceCents: projectedBalanceCents,
          ),
        );
      }

      if (!hasFixedDeadline && reachesTarget) {
        break;
      }
    }

    final lastRow = monthlyRows.isEmpty ? null : monthlyRows.last;
    return _GoalCompoundProjection(
      points: points,
      monthlyRows: monthlyRows,
      annualRows: annualRows,
      finalBalanceCents: lastRow?.projectedBalanceCents ?? currentBalanceCents,
      totalInvestedCents: lastRow?.totalInvestedCents ?? currentBalanceCents,
      interestCents: lastRow?.accumulatedInterestCents ?? 0,
      months: monthlyRows.length,
      targetReachedAt: targetReachedAt,
    );
  }

  int _balanceBeforeDate(AccountPreview account, DateTime cutoff) {
    var balanceCents = account.initialBalanceCents;

    for (final transaction in _transactions) {
      if (!transaction.isPaid ||
          transaction.accountId != account.id ||
          !transaction.date.isBefore(cutoff) ||
          transaction.paymentMethod == 'credit_card') {
        continue;
      }

      balanceCents += transaction.type == 'income'
          ? transaction.amount
          : -transaction.amount;
    }

    for (final transfer in _transfers) {
      if (!transfer.isPaid || !transfer.date.isBefore(cutoff)) {
        continue;
      }

      if (transfer.fromAccountId == account.id) {
        balanceCents -= transfer.amount;
      }
      if (transfer.toAccountId == account.id) {
        balanceCents += transfer.convertedAmount ?? transfer.amount;
      }
    }

    for (final invoice in _invoices) {
      if (invoice.status != 'paid' ||
          invoice.paymentAccountId != account.id ||
          invoice.paidAt == null ||
          !invoice.paidAt!.isBefore(cutoff)) {
        continue;
      }

      balanceCents -= invoice.amount;
    }

    return balanceCents;
  }

  int _monthsToTarget(DateTime? targetDate) {
    if (targetDate == null) {
      return 0;
    }

    final currentMonth = _monthOnly(DateTime.now());
    final targetMonth = _monthOnly(targetDate);
    final months = ((targetMonth.year - currentMonth.year) * 12) +
        targetMonth.month -
        currentMonth.month +
        1;
    return months.clamp(1, 360).toInt();
  }

  int _requiredMonthlyWithoutYield(int remainingCents, int monthsToTarget) {
    if (remainingCents <= 0) {
      return 0;
    }
    if (monthsToTarget <= 0) {
      return remainingCents;
    }

    return ((remainingCents + monthsToTarget - 1) / monthsToTarget).floor();
  }

  int _requiredMonthlyWithYield({
    required int currentBalanceCents,
    required int targetCents,
    required int monthsToTarget,
    required double monthlyYieldRate,
    required int fallbackCents,
  }) {
    if (targetCents <= 0 || currentBalanceCents >= targetCents) {
      return 0;
    }
    if (monthsToTarget <= 0 || monthlyYieldRate <= 0) {
      return fallbackCents;
    }

    final growth = math.pow(1 + monthlyYieldRate, monthsToTarget).toDouble();
    final projectedCurrentBalance = currentBalanceCents * growth;
    if (projectedCurrentBalance >= targetCents) {
      return 0;
    }

    final contributionFactor = (growth - 1) / monthlyYieldRate;
    if (contributionFactor <= 0) {
      return fallbackCents;
    }

    final required =
        ((targetCents - projectedCurrentBalance) / contributionFactor).ceil();
    return required.clamp(0, fallbackCents).toInt();
  }

  DateTime? _estimatedCompletionMonth({
    required int currentBalanceCents,
    required int targetCents,
    required int monthlyContributionCents,
    required double monthlyYieldRate,
  }) {
    if (targetCents <= 0 || currentBalanceCents >= targetCents) {
      return _monthOnly(DateTime.now());
    }
    if (monthlyContributionCents <= 0 && monthlyYieldRate <= 0) {
      return null;
    }

    var balance = currentBalanceCents.toDouble();
    var cursor = _monthOnly(DateTime.now());
    for (var index = 0; index < 360; index++) {
      cursor = DateTime(cursor.year, cursor.month + 1);
      balance = (balance + monthlyContributionCents) * (1 + monthlyYieldRate);
      if (balance >= targetCents) {
        return cursor;
      }
    }

    return null;
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

  AccountPreview _withMonthBalance(
    AccountPreview account, {
    required int balanceCents,
  }) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.lastDigits,
      balanceCents: balanceCents,
      initialBalanceCents: account.initialBalanceCents,
      currentBalanceCents: account.currentBalanceCents,
      monthlyIncomeCents: account.monthlyIncomeCents,
      monthlyExpenseCents: account.monthlyExpenseCents,
      monthlyYieldCents: account.monthlyYieldCents,
      currencyCode: account.currencyCode,
      displayBalanceCents: account.displayBalanceCents,
      includeInTotalBalance: account.includeInTotalBalance,
      emergencyReserveTargetCents: account.emergencyReserveTargetCents,
      goalLinkedAccountId: account.goalLinkedAccountId,
      goalTargetDate: account.goalTargetDate,
      createdAt: account.createdAt,
      firstAvailableMonth: account.firstAvailableMonth,
      color: account.color,
      colorHex: account.colorHex,
    );
  }

  int _balanceForMonth(AccountPreview account, DateTime month) {
    final end = DateTime(month.year, month.month + 1);
    var balanceCents = account.initialBalanceCents;

    for (final transaction in _transactions) {
      if (!transaction.isPaid ||
          transaction.accountId != account.id ||
          !transaction.date.isBefore(end) ||
          transaction.paymentMethod == 'credit_card') {
        continue;
      }

      balanceCents += transaction.type == 'income'
          ? transaction.amount
          : -transaction.amount;
    }

    for (final transfer in _transfers) {
      if (!transfer.isPaid || !transfer.date.isBefore(end)) {
        continue;
      }

      if (transfer.fromAccountId == account.id) {
        balanceCents -= transfer.amount;
      }
      if (transfer.toAccountId == account.id) {
        balanceCents += transfer.convertedAmount ?? transfer.amount;
      }
    }

    for (final invoice in _invoices) {
      if (invoice.status != 'paid' ||
          invoice.paymentAccountId != account.id ||
          invoice.paidAt == null ||
          !invoice.paidAt!.isBefore(end)) {
        continue;
      }

      balanceCents -= invoice.amount;
    }

    return balanceCents;
  }

  List<GoalBalancePoint> _balanceSeriesForGoal(
    GoalPreview goal,
    Map<int, AccountPreview> accountsById,
  ) {
    final linkedAccountId = goal.linkedAccountId;
    if (linkedAccountId == null) {
      return const [];
    }

    final account = accountsById[linkedAccountId];
    if (account == null) {
      return const [];
    }

    final firstMonth = _firstAvailableMonthForAccount(account);
    final lastMonth = _monthOnly(state.selectedMonth);
    if (firstMonth.isAfter(lastMonth)) {
      return [
        GoalBalancePoint(
          month: lastMonth,
          balanceCents: _balanceForMonth(account, lastMonth),
        ),
      ];
    }

    final points = <GoalBalancePoint>[];
    var cursor = firstMonth;
    while (!cursor.isAfter(lastMonth)) {
      points.add(
        GoalBalancePoint(
          month: cursor,
          balanceCents: _balanceForMonth(account, cursor),
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return points;
  }

  DateTime _firstAvailableMonthForAccount(AccountPreview account) {
    DateTime? firstRecordMonth;

    for (final transaction in _transactions) {
      if (transaction.accountId != account.id ||
          transaction.paymentMethod == 'credit_card') {
        continue;
      }

      firstRecordMonth = _minNullableMonth(
        firstRecordMonth,
        _monthOnly(transaction.date),
      );
    }

    for (final transfer in _transfers) {
      if (transfer.fromAccountId != account.id &&
          transfer.toAccountId != account.id) {
        continue;
      }

      firstRecordMonth = _minNullableMonth(
        firstRecordMonth,
        _monthOnly(transfer.date),
      );
    }

    for (final invoice in _invoices) {
      final paidAt = invoice.paidAt;
      if (invoice.paymentAccountId != account.id || paidAt == null) {
        continue;
      }

      firstRecordMonth = _minNullableMonth(
        firstRecordMonth,
        _monthOnly(paidAt),
      );
    }

    return firstRecordMonth ?? _monthOnly(account.createdAt ?? DateTime.now());
  }

  DateTime _monthOnly(DateTime date) {
    return DateTime(date.year, date.month);
  }

  DateTime _minNullableMonth(DateTime? current, DateTime candidate) {
    if (current == null || candidate.isBefore(current)) {
      return candidate;
    }
    return current;
  }

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      balanceCents: account.currentBalance,
      initialBalanceCents: account.initialBalance,
      currentBalanceCents: account.currentBalance,
      currencyCode: account.currencyCode,
      includeInTotalBalance: account.includeInTotalBalance,
      emergencyReserveTargetCents: account.emergencyReserveTarget,
      goalLinkedAccountId: account.goalLinkedAccountId,
      goalTargetDate: account.goalTargetDate,
      createdAt: account.createdAt,
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  GoalPreview _mapGoal(Goal goal) {
    return GoalPreview(
      id: goal.id,
      userId: goal.userId,
      name: goal.name,
      linkedAccountId: goal.linkedAccountId,
      targetAmountCents: goal.targetAmount,
      targetDate: goal.targetDate,
      color: _parseColor(goal.color),
      colorHex: goal.color,
      createdAt: goal.createdAt,
      updatedAt: goal.updatedAt,
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
      throw StateError('Usuario nao autenticado.');
    }
    return userId;
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _goalsSubscription?.cancel();
    _invoicesSubscription?.cancel();
    _monthlyPlanSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _transfersSubscription?.cancel();
    super.dispose();
  }
}

class _GoalYieldStats {
  const _GoalYieldStats({
    required this.averageMonthlyRate,
    required this.historyMonths,
  });

  static const empty = _GoalYieldStats(
    averageMonthlyRate: 0,
    historyMonths: 0,
  );

  final double averageMonthlyRate;
  final int historyMonths;
}

class _GoalCompoundProjection {
  const _GoalCompoundProjection({
    required this.points,
    required this.monthlyRows,
    required this.annualRows,
    required this.finalBalanceCents,
    required this.totalInvestedCents,
    required this.interestCents,
    required this.months,
    required this.targetReachedAt,
  });

  final List<GoalProjectionPoint> points;
  final List<GoalProjectionMonth> monthlyRows;
  final List<GoalProjectionYear> annualRows;
  final int finalBalanceCents;
  final int totalInvestedCents;
  final int interestCents;
  final int months;
  final DateTime? targetReachedAt;
}

class GoalLinkedAccountDraft {
  const GoalLinkedAccountDraft({
    required this.name,
    required this.initialBalanceCents,
    this.bankName,
    this.currencyCode = 'BRL',
    this.color = '#006B4F',
  });

  final String name;
  final String? bankName;
  final int initialBalanceCents;
  final String currencyCode;
  final String color;
}

final goalsViewModelProvider =
    StateNotifierProvider.autoDispose<GoalsViewModel, GoalsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return GoalsViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
    monthlyPlanRepository: ref.watch(monthlyPlanRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
  );
});
