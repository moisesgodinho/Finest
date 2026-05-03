import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/monthly_plan_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class BudgetLimitPreview {
  const BudgetLimitPreview({
    required this.name,
    required this.usedCents,
    required this.limitCents,
    required this.color,
    required this.icon,
  });

  final String name;
  final int usedCents;
  final int limitCents;
  final Color color;
  final IconData icon;

  double get percent => limitCents == 0 ? 0 : usedCents / limitCents;
}

class PlannedBillPreview {
  const PlannedBillPreview({
    required this.name,
    required this.dueLabel,
    required this.amountCents,
    required this.icon,
    required this.dueDate,
  });

  final String name;
  final String dueLabel;
  final int amountCents;
  final IconData icon;
  final DateTime dueDate;
}

class PlanningState {
  const PlanningState({
    required this.selectedMonth,
    required this.plannedIncomeCents,
    required this.plannedExpenseCents,
    required this.initialMonthBalanceCents,
    required this.currentIncomeCents,
    required this.currentExpenseCents,
    required this.upcomingBillsCents,
    required this.budgets,
    required this.upcomingBills,
    this.hasPlan = false,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  factory PlanningState.initial() {
    final now = DateTime.now();
    return PlanningState(
      selectedMonth: DateTime(now.year, now.month),
      plannedIncomeCents: 0,
      plannedExpenseCents: 0,
      initialMonthBalanceCents: 0,
      currentIncomeCents: 0,
      currentExpenseCents: 0,
      upcomingBillsCents: 0,
      budgets: const [],
      upcomingBills: const [],
      isLoading: true,
    );
  }

  final DateTime selectedMonth;
  final int plannedIncomeCents;
  final int plannedExpenseCents;
  final int initialMonthBalanceCents;
  final int currentIncomeCents;
  final int currentExpenseCents;
  final int upcomingBillsCents;
  final List<BudgetLimitPreview> budgets;
  final List<PlannedBillPreview> upcomingBills;
  final bool hasPlan;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  String get monthLabel => AppDateUtils.monthYearLabel(selectedMonth);

  double get completionPercent {
    if (plannedExpenseCents == 0) {
      return 0;
    }
    return currentExpenseCents / plannedExpenseCents;
  }

  int get availableBudgetCents => plannedExpenseCents - currentExpenseCents;

  int get plannedFinalBalanceCents {
    return initialMonthBalanceCents + plannedIncomeCents - plannedExpenseCents;
  }

  int get projectedFinalBalanceCents {
    return initialMonthBalanceCents + currentIncomeCents - currentExpenseCents;
  }

  PlanningState copyWith({
    DateTime? selectedMonth,
    int? plannedIncomeCents,
    int? plannedExpenseCents,
    int? initialMonthBalanceCents,
    int? currentIncomeCents,
    int? currentExpenseCents,
    int? upcomingBillsCents,
    List<BudgetLimitPreview>? budgets,
    List<PlannedBillPreview>? upcomingBills,
    bool? hasPlan,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlanningState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      plannedIncomeCents: plannedIncomeCents ?? this.plannedIncomeCents,
      plannedExpenseCents: plannedExpenseCents ?? this.plannedExpenseCents,
      initialMonthBalanceCents:
          initialMonthBalanceCents ?? this.initialMonthBalanceCents,
      currentIncomeCents: currentIncomeCents ?? this.currentIncomeCents,
      currentExpenseCents: currentExpenseCents ?? this.currentExpenseCents,
      upcomingBillsCents: upcomingBillsCents ?? this.upcomingBillsCents,
      budgets: budgets ?? this.budgets,
      upcomingBills: upcomingBills ?? this.upcomingBills,
      hasPlan: hasPlan ?? this.hasPlan,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PlanningViewModel extends StateNotifier<PlanningState> {
  PlanningViewModel({
    required int? userId,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required MonthlyPlanRepository monthlyPlanRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _categoryRepository = categoryRepository,
        _creditCardRepository = creditCardRepository,
        _monthlyPlanRepository = monthlyPlanRepository,
        _transactionRepository = transactionRepository,
        super(PlanningState.initial()) {
    _watchData();
  }

  final int? _userId;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final MonthlyPlanRepository _monthlyPlanRepository;
  final TransactionRepository _transactionRepository;

  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<CreditCard>>? _creditCardsSubscription;
  StreamSubscription<List<CreditCardInvoice>>? _invoicesSubscription;
  StreamSubscription<MonthlyPlan?>? _monthlyPlanSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;

  List<CategoryModel> _categories = [];
  List<CreditCard> _creditCards = [];
  List<CreditCardInvoice> _invoices = [];
  List<FinanceTransaction> _transactions = [];
  MonthlyPlan? _monthlyPlan;

  void selectMonth(DateTime month) {
    final selectedMonth = DateTime(month.year, month.month);
    if (selectedMonth.year == state.selectedMonth.year &&
        selectedMonth.month == state.selectedMonth.month) {
      return;
    }

    state = state.copyWith(
      selectedMonth: selectedMonth,
      isLoading: true,
      clearError: true,
    );
    _watchMonthlyPlan();
    _publishState();
  }

  void previousMonth() {
    selectMonth(
        DateTime(state.selectedMonth.year, state.selectedMonth.month - 1));
  }

  void nextMonth() {
    selectMonth(
        DateTime(state.selectedMonth.year, state.selectedMonth.month + 1));
  }

  Future<void> savePlan({
    required int plannedIncomeCents,
    required int plannedExpenseCents,
    required int initialMonthBalanceCents,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _monthlyPlanRepository.savePlan(
        userId: userId,
        month: state.selectedMonth.month,
        year: state.selectedMonth.year,
        plannedIncomeCents: plannedIncomeCents,
        plannedExpenseCents: plannedExpenseCents,
        initialMonthBalanceCents: initialMonthBalanceCents,
      );
      state = state.copyWith(isSaving: false);
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = PlanningState.initial().copyWith(isLoading: false);
      return;
    }

    _categoriesSubscription =
        _categoryRepository.watchCategories(userId).listen(
      (categories) {
        _categories = categories;
        _publishState();
      },
      onError: _publishError,
    );

    _creditCardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (cards) {
        _creditCards = cards;
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

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState();
      },
      onError: _publishError,
    );

    _watchMonthlyPlan();
  }

  void _watchMonthlyPlan() {
    final userId = _userId;
    _monthlyPlanSubscription?.cancel();
    _monthlyPlan = null;

    if (userId == null) {
      return;
    }

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
    final plan = _monthlyPlan;
    final plannedExpenseCents = plan?.plannedExpense ?? 0;
    final upcomingBills = _buildUpcomingBills(monthTransactions);

    state = state.copyWith(
      plannedIncomeCents: plan?.plannedIncome ?? 0,
      plannedExpenseCents: plannedExpenseCents,
      initialMonthBalanceCents: plan?.initialMonthBalance ?? 0,
      currentIncomeCents: currentIncomeCents,
      currentExpenseCents: currentExpenseCents,
      upcomingBillsCents: _upcomingBillsTotal(upcomingBills),
      budgets: _buildBudgetPreviews(
        monthTransactions,
        plannedExpenseCents: plannedExpenseCents,
      ),
      upcomingBills: upcomingBills,
      hasPlan: plan != null,
      isLoading: false,
      clearError: true,
    );
  }

  int _upcomingBillsTotal(List<PlannedBillPreview> upcomingBills) {
    return upcomingBills.fold<int>(
      0,
      (total, bill) => total + bill.amountCents,
    );
  }

  List<BudgetLimitPreview> _buildBudgetPreviews(
    List<FinanceTransaction> monthTransactions, {
    required int plannedExpenseCents,
  }) {
    final expenseCategories = {
      for (final category
          in _categories.where((category) => category.type == 'expense'))
        category.id: category,
    };
    final totalsByCategory = <int, int>{};

    for (final transaction in monthTransactions) {
      if (transaction.type != 'expense') {
        continue;
      }
      totalsByCategory.update(
        transaction.categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final visibleCategoryIds = totalsByCategory.keys.toList()
      ..sort((a, b) =>
          (totalsByCategory[b] ?? 0).compareTo(totalsByCategory[a] ?? 0));

    if (visibleCategoryIds.isEmpty && plannedExpenseCents > 0) {
      visibleCategoryIds.addAll(expenseCategories.keys.take(5));
    }

    final selectedIds = visibleCategoryIds.take(5).toList();
    final totalWeight = selectedIds.fold<double>(
      0,
      (total, id) => total + _categoryWeight(expenseCategories[id]?.name),
    );

    return [
      for (final id in selectedIds)
        BudgetLimitPreview(
          name: expenseCategories[id]?.name ?? 'Sem categoria',
          usedCents: totalsByCategory[id] ?? 0,
          limitCents: plannedExpenseCents == 0 || totalWeight == 0
              ? 0
              : (plannedExpenseCents *
                      (_categoryWeight(expenseCategories[id]?.name) /
                          totalWeight))
                  .round(),
          color: expenseCategories[id]?.color ?? AppColors.primary,
          icon: expenseCategories[id]?.icon ?? Icons.category_rounded,
        ),
    ];
  }

  List<PlannedBillPreview> _buildUpcomingBills(
    List<FinanceTransaction> monthTransactions,
  ) {
    final bills = <PlannedBillPreview>[];

    for (final transaction in monthTransactions) {
      if (transaction.isPaid ||
          transaction.type != 'expense' ||
          transaction.paymentMethod == 'credit_card') {
        continue;
      }

      final dueDate = transaction.dueDate ?? transaction.date;
      bills.add(
        PlannedBillPreview(
          name: transaction.description,
          dueLabel: 'Vencimento: ${_shortDate(dueDate)}',
          amountCents: transaction.amount,
          icon: Icons.event_available_rounded,
          dueDate: dueDate,
        ),
      );
    }

    final cardNames = {for (final card in _creditCards) card.id: card.name};
    for (final card in _creditCards) {
      final invoice = _invoiceForCardMonth(
        cardId: card.id,
        month: state.selectedMonth.month,
        year: state.selectedMonth.year,
      );
      if (invoice?.status == 'paid') {
        continue;
      }

      final invoiceTransactions = monthTransactions
          .where(
            (transaction) =>
                transaction.paymentMethod == 'credit_card' &&
                transaction.creditCardId == card.id,
          )
          .toList();
      final transactionTotal = invoiceTransactions.fold<int>(
        0,
        (total, transaction) => total + _invoiceAmountDelta(transaction),
      );
      final amount = invoiceTransactions.isNotEmpty
          ? transactionTotal.clamp(0, 1 << 31).toInt()
          : invoice?.amount ?? 0;
      if (amount <= 0) {
        continue;
      }

      final dueDate = invoice?.dueDate ??
          _creditCardDueDate(
            month: state.selectedMonth.month,
            year: state.selectedMonth.year,
            dueDay: card.dueDay,
          );
      bills.add(
        PlannedBillPreview(
          name: 'Fatura ${cardNames[card.id] ?? card.name}',
          dueLabel: 'Vencimento: ${_shortDate(dueDate)}',
          amountCents: amount,
          icon: Icons.credit_card_rounded,
          dueDate: dueDate,
        ),
      );
    }

    bills.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return bills.take(6).toList();
  }

  CreditCardInvoice? _invoiceForCardMonth({
    required int cardId,
    required int month,
    required int year,
  }) {
    for (final invoice in _invoices) {
      if (invoice.creditCardId == cardId &&
          invoice.month == month &&
          invoice.year == year) {
        return invoice;
      }
    }
    return null;
  }

  DateTime _referenceDate(FinanceTransaction transaction) {
    if (transaction.paymentMethod == 'credit_card' &&
        transaction.invoiceMonth != null &&
        transaction.invoiceYear != null) {
      return DateTime(transaction.invoiceYear!, transaction.invoiceMonth!);
    }

    return transaction.dueDate ?? transaction.date;
  }

  int _invoiceAmountDelta(FinanceTransaction transaction) {
    return transaction.type == 'income'
        ? -transaction.amount
        : transaction.amount;
  }

  DateTime _creditCardDueDate({
    required int month,
    required int year,
    required int dueDay,
  }) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dueDay.clamp(1, lastDay));
  }

  double _categoryWeight(String? categoryName) {
    final normalized = (categoryName ?? '').toLowerCase();
    if (normalized.contains('moradia') || normalized.contains('aluguel')) {
      return 0.35;
    }
    if (normalized.contains('aliment')) {
      return 0.25;
    }
    if (normalized.contains('transporte')) {
      return 0.15;
    }
    if (normalized.contains('saude') || normalized.contains('saúde')) {
      return 0.10;
    }
    if (normalized.contains('lazer')) {
      return 0.10;
    }
    if (normalized.contains('invest')) {
      return 0.10;
    }
    return 0.08;
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  void _publishError(Object error) {
    state = state.copyWith(
      isLoading: false,
      isSaving: false,
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
    _categoriesSubscription?.cancel();
    _creditCardsSubscription?.cancel();
    _invoicesSubscription?.cancel();
    _monthlyPlanSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final planningViewModelProvider =
    StateNotifierProvider<PlanningViewModel, PlanningState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return PlanningViewModel(
    userId: userId,
    categoryRepository: ref.watch(categoryRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    monthlyPlanRepository: ref.watch(monthlyPlanRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
