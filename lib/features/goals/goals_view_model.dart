import 'dart:async';

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
