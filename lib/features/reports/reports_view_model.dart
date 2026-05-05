import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/currency/exchange_rate_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';

const _unset = Object();

class ReportsState {
  const ReportsState({
    required this.selectedMonth,
    this.selectedType = 'expense',
    this.selectedCategoryId,
    this.selectedSubcategoryId,
    this.currencyCode = 'BRL',
    this.summary = const MonthlyReportSummary(),
    this.cashFlow = const [],
    this.comparison = const MonthComparisonReport(),
    this.categoryItems = const [],
    this.categories = const [],
    this.subcategories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  factory ReportsState.initial() {
    final now = DateTime.now();
    return ReportsState(
      selectedMonth: DateTime(now.year, now.month),
      isLoading: true,
    );
  }

  final DateTime selectedMonth;
  final String selectedType;
  final int? selectedCategoryId;
  final int? selectedSubcategoryId;
  final String currencyCode;
  final MonthlyReportSummary summary;
  final List<CashFlowMonthReport> cashFlow;
  final MonthComparisonReport comparison;
  final List<CategoryBreakdownReport> categoryItems;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final bool isLoading;
  final String? errorMessage;

  List<CategoryModel> get filterCategories {
    return categories
        .where((category) => category.type == selectedType)
        .toList();
  }

  List<SubcategoryModel> get filterSubcategories {
    final categoryId = selectedCategoryId;
    if (categoryId == null) {
      return const [];
    }
    return subcategories
        .where((subcategory) => subcategory.categoryId == categoryId)
        .toList();
  }

  ReportsState copyWith({
    DateTime? selectedMonth,
    String? selectedType,
    Object? selectedCategoryId = _unset,
    Object? selectedSubcategoryId = _unset,
    String? currencyCode,
    MonthlyReportSummary? summary,
    List<CashFlowMonthReport>? cashFlow,
    MonthComparisonReport? comparison,
    List<CategoryBreakdownReport>? categoryItems,
    List<CategoryModel>? categories,
    List<SubcategoryModel>? subcategories,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedType: selectedType ?? this.selectedType,
      selectedCategoryId: identical(selectedCategoryId, _unset)
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      selectedSubcategoryId: identical(selectedSubcategoryId, _unset)
          ? this.selectedSubcategoryId
          : selectedSubcategoryId as int?,
      currencyCode: currencyCode ?? this.currencyCode,
      summary: summary ?? this.summary,
      cashFlow: cashFlow ?? this.cashFlow,
      comparison: comparison ?? this.comparison,
      categoryItems: categoryItems ?? this.categoryItems,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ReportsViewModel extends StateNotifier<ReportsState> {
  ReportsViewModel({
    required int? userId,
    required CategoryRepository categoryRepository,
    required TransactionRepository transactionRepository,
    required ExchangeRateService exchangeRateService,
    required String currencyCode,
  })  : _userId = userId,
        _categoryRepository = categoryRepository,
        _transactionRepository = transactionRepository,
        _exchangeRateService = exchangeRateService,
        _currencyCode = currencyCode,
        super(ReportsState.initial()) {
    _watchData();
  }

  final int? _userId;
  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;
  final ExchangeRateService _exchangeRateService;
  final String _currencyCode;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<SubcategoryModel>>? _subcategoriesSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<CategoryModel> _categories = [];
  List<SubcategoryModel> _subcategories = [];
  List<FinanceTransaction> _transactions = [];

  void selectPreviousMonth() {
    final month = state.selectedMonth;
    state = state.copyWith(
      selectedMonth: DateTime(month.year, month.month - 1),
    );
    _publishState();
  }

  void selectNextMonth() {
    final month = state.selectedMonth;
    state = state.copyWith(
      selectedMonth: DateTime(month.year, month.month + 1),
    );
    _publishState();
  }

  void selectType(String type) {
    state = state.copyWith(
      selectedType: type,
      selectedCategoryId: null,
      selectedSubcategoryId: null,
    );
    _publishState();
  }

  void selectCategory(int? categoryId) {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      selectedSubcategoryId: null,
    );
    _publishState();
  }

  void selectSubcategory(int? subcategoryId) {
    state = state.copyWith(selectedSubcategoryId: subcategoryId);
    _publishState();
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = ReportsState.initial().copyWith(isLoading: false);
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

    _subcategoriesSubscription =
        _categoryRepository.watchSubcategories(userId).listen(
      (subcategories) {
        _subcategories = subcategories;
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
  }

  Future<void> _publishState() async {
    final ratesToBrl = await _exchangeRateService.ratesToBrlSnapshot();
    final summary = _summaryFor(state.selectedMonth, ratesToBrl);
    final previousSummary = _summaryFor(
      DateTime(state.selectedMonth.year, state.selectedMonth.month - 1),
      ratesToBrl,
    );

    state = state.copyWith(
      currencyCode: _currencyCode,
      categories: _categories,
      subcategories: _subcategories,
      summary: summary,
      comparison: MonthComparisonReport(
        current: summary,
        previous: previousSummary,
      ),
      cashFlow: _cashFlow(ratesToBrl),
      categoryItems: _categoryBreakdown(ratesToBrl),
      isLoading: false,
      clearError: true,
    );
  }

  MonthlyReportSummary _summaryFor(
    DateTime month,
    Map<String, double> ratesToBrl,
  ) {
    var incomeCents = 0;
    var accountExpenseCents = 0;
    var cardExpenseCents = 0;
    var paidCents = 0;
    var pendingCents = 0;
    var transactionCount = 0;

    for (final transaction in _transactions) {
      if (!_sameMonth(_referenceDate(transaction), month)) {
        continue;
      }

      final amount = _convertTransactionAmount(transaction, ratesToBrl);
      transactionCount += 1;

      if (transaction.isPaid) {
        paidCents += amount;
      } else {
        pendingCents += amount;
      }

      if (transaction.type == 'income') {
        incomeCents += amount;
      } else if (transaction.paymentMethod == 'credit_card') {
        cardExpenseCents += amount;
      } else {
        accountExpenseCents += amount;
      }
    }

    return MonthlyReportSummary(
      month: DateTime(month.year, month.month),
      incomeCents: incomeCents,
      accountExpenseCents: accountExpenseCents,
      cardExpenseCents: cardExpenseCents,
      paidCents: paidCents,
      pendingCents: pendingCents,
      transactionCount: transactionCount,
    );
  }

  List<CashFlowMonthReport> _cashFlow(Map<String, double> ratesToBrl) {
    final months = [
      for (var index = 5; index >= 0; index--)
        DateTime(state.selectedMonth.year, state.selectedMonth.month - index),
    ];

    return [
      for (final month in months)
        CashFlowMonthReport(
          month: month,
          summary: _summaryFor(month, ratesToBrl),
        ),
    ];
  }

  List<CategoryBreakdownReport> _categoryBreakdown(
    Map<String, double> ratesToBrl,
  ) {
    final categoriesById = {
      for (final category in _categories) category.id: category,
    };
    final subcategoriesById = {
      for (final subcategory in _subcategories) subcategory.id: subcategory,
    };
    final totalsByCategory = <int, _MutableCategoryBreakdown>{};

    for (final transaction in _transactions) {
      if (transaction.type != state.selectedType) {
        continue;
      }
      if (!_sameMonth(_referenceDate(transaction), state.selectedMonth)) {
        continue;
      }
      if (state.selectedCategoryId != null &&
          transaction.categoryId != state.selectedCategoryId) {
        continue;
      }
      if (state.selectedSubcategoryId != null &&
          transaction.subcategoryId != state.selectedSubcategoryId) {
        continue;
      }

      final category = categoriesById[transaction.categoryId] ??
          CategoryModel(
            id: transaction.categoryId,
            name: 'Sem categoria',
            type: transaction.type,
            icon: Icons.category_rounded,
            color: AppColors.primary,
            colorHex: '#006B4F',
          );
      final report = totalsByCategory.putIfAbsent(
        category.id,
        () => _MutableCategoryBreakdown(category),
      );
      final amount = _convertTransactionAmount(transaction, ratesToBrl);
      final subcategory = transaction.subcategoryId == null
          ? null
          : subcategoriesById[transaction.subcategoryId];
      report.add(
        transaction: transaction,
        subcategory: subcategory,
        amountCents: amount,
      );
    }

    final totalCents = totalsByCategory.values.fold<int>(
      0,
      (total, item) => total + item.totalCents,
    );

    return totalsByCategory.values
        .map((item) => item.toReport(totalCents))
        .toList()
      ..sort((left, right) => right.totalCents.compareTo(left.totalCents));
  }

  DateTime _referenceDate(FinanceTransaction transaction) {
    if (transaction.paymentMethod == 'credit_card' &&
        transaction.invoiceMonth != null &&
        transaction.invoiceYear != null) {
      return DateTime(transaction.invoiceYear!, transaction.invoiceMonth!);
    }

    return transaction.dueDate ?? transaction.date;
  }

  int _convertTransactionAmount(
    FinanceTransaction transaction,
    Map<String, double> ratesToBrl,
  ) {
    return _exchangeRateService.convertCentsWithRates(
      amountCents: transaction.amount,
      fromCurrency: transaction.currencyCode,
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  bool _sameMonth(DateTime left, DateTime right) {
    return left.month == right.month && left.year == right.year;
  }

  void _publishError(Object error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: error.toString().replaceFirst('Exception: ', ''),
    );
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final reportsViewModelProvider =
    StateNotifierProvider<ReportsViewModel, ReportsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return ReportsViewModel(
    userId: userId,
    categoryRepository: ref.watch(categoryRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
  );
});

class MonthlyReportSummary {
  const MonthlyReportSummary({
    this.month,
    this.incomeCents = 0,
    this.accountExpenseCents = 0,
    this.cardExpenseCents = 0,
    this.paidCents = 0,
    this.pendingCents = 0,
    this.transactionCount = 0,
  });

  final DateTime? month;
  final int incomeCents;
  final int accountExpenseCents;
  final int cardExpenseCents;
  final int paidCents;
  final int pendingCents;
  final int transactionCount;

  int get totalExpenseCents => accountExpenseCents + cardExpenseCents;
  int get netCents => incomeCents - totalExpenseCents;
  int get totalVolumeCents => incomeCents + totalExpenseCents;
}

class CashFlowMonthReport {
  const CashFlowMonthReport({
    required this.month,
    required this.summary,
  });

  final DateTime month;
  final MonthlyReportSummary summary;
}

class MonthComparisonReport {
  const MonthComparisonReport({
    this.current = const MonthlyReportSummary(),
    this.previous = const MonthlyReportSummary(),
  });

  final MonthlyReportSummary current;
  final MonthlyReportSummary previous;
}

class CategoryBreakdownReport {
  const CategoryBreakdownReport({
    required this.category,
    required this.totalCents,
    required this.paidCents,
    required this.pendingCents,
    required this.transactionCount,
    required this.percent,
    required this.subcategories,
  });

  final CategoryModel category;
  final int totalCents;
  final int paidCents;
  final int pendingCents;
  final int transactionCount;
  final double percent;
  final List<SubcategoryBreakdownReport> subcategories;
}

class SubcategoryBreakdownReport {
  const SubcategoryBreakdownReport({
    required this.name,
    required this.totalCents,
    required this.transactionCount,
    required this.percent,
  });

  final String name;
  final int totalCents;
  final int transactionCount;
  final double percent;
}

class _MutableCategoryBreakdown {
  _MutableCategoryBreakdown(this.category);

  final CategoryModel category;
  final Map<String, _MutableSubcategoryBreakdown> subcategories = {};
  int totalCents = 0;
  int paidCents = 0;
  int pendingCents = 0;
  int transactionCount = 0;

  void add({
    required FinanceTransaction transaction,
    required SubcategoryModel? subcategory,
    required int amountCents,
  }) {
    totalCents += amountCents;
    transactionCount += 1;
    if (transaction.isPaid) {
      paidCents += amountCents;
    } else {
      pendingCents += amountCents;
    }

    final name = subcategory?.name ?? 'Sem subcategoria';
    subcategories
        .putIfAbsent(
          name,
          () => _MutableSubcategoryBreakdown(name),
        )
        .add(amountCents);
  }

  CategoryBreakdownReport toReport(int reportTotalCents) {
    final subcategoryItems = subcategories.values
        .map((subcategory) => subcategory.toReport(totalCents))
        .toList()
      ..sort((left, right) => right.totalCents.compareTo(left.totalCents));

    return CategoryBreakdownReport(
      category: category,
      totalCents: totalCents,
      paidCents: paidCents,
      pendingCents: pendingCents,
      transactionCount: transactionCount,
      percent: reportTotalCents == 0 ? 0 : totalCents / reportTotalCents,
      subcategories: subcategoryItems,
    );
  }
}

class _MutableSubcategoryBreakdown {
  _MutableSubcategoryBreakdown(this.name);

  final String name;
  int totalCents = 0;
  int transactionCount = 0;

  void add(int amountCents) {
    totalCents += amountCents;
    transactionCount += 1;
  }

  SubcategoryBreakdownReport toReport(int categoryTotalCents) {
    return SubcategoryBreakdownReport(
      name: name,
      totalCents: totalCents,
      transactionCount: transactionCount,
      percent: categoryTotalCents == 0 ? 0 : totalCents / categoryTotalCents,
    );
  }
}
