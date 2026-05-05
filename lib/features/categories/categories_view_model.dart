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

class CategoriesState {
  const CategoriesState({
    required this.selectedMonth,
    this.reportSummary = const CategoryReportSummary(),
    this.reportItems = const [],
    this.selectedType = 'expense',
    this.currencyCode = 'BRL',
    this.categories = const [],
    this.subcategories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  factory CategoriesState.initial() {
    final now = DateTime.now();
    return CategoriesState(
      selectedMonth: DateTime(now.year, now.month),
      isLoading: true,
    );
  }

  final DateTime selectedMonth;
  final CategoryReportSummary reportSummary;
  final List<CategoryReportItem> reportItems;
  final String selectedType;
  final String currencyCode;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final bool isLoading;
  final String? errorMessage;

  List<CategoryModel> get visibleCategories {
    return categories
        .where((category) => category.type == selectedType)
        .toList();
  }

  List<SubcategoryModel> subcategoriesFor(int categoryId) {
    return subcategories
        .where((subcategory) => subcategory.categoryId == categoryId)
        .toList();
  }

  CategoriesState copyWith({
    DateTime? selectedMonth,
    CategoryReportSummary? reportSummary,
    List<CategoryReportItem>? reportItems,
    String? selectedType,
    String? currencyCode,
    List<CategoryModel>? categories,
    List<SubcategoryModel>? subcategories,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CategoriesState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      reportSummary: reportSummary ?? this.reportSummary,
      reportItems: reportItems ?? this.reportItems,
      selectedType: selectedType ?? this.selectedType,
      currencyCode: currencyCode ?? this.currencyCode,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CategoriesViewModel extends StateNotifier<CategoriesState> {
  CategoriesViewModel({
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
        super(CategoriesState.initial()) {
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

  void selectType(String type) {
    state = state.copyWith(selectedType: type);
  }

  void selectPreviousMonth() {
    final selectedMonth = state.selectedMonth;
    state = state.copyWith(
      selectedMonth: DateTime(selectedMonth.year, selectedMonth.month - 1),
    );
    _publishState();
  }

  void selectNextMonth() {
    final selectedMonth = state.selectedMonth;
    state = state.copyWith(
      selectedMonth: DateTime(selectedMonth.year, selectedMonth.month + 1),
    );
    _publishState();
  }

  Future<void> createCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _categoryRepository.createCategory(
        userId: userId,
        name: name,
        type: type,
        icon: icon,
        color: color,
      );
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  Future<void> updateCategory({
    required int categoryId,
    required String name,
    required String icon,
    required String color,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _categoryRepository.updateCategory(
        userId: userId,
        categoryId: categoryId,
        name: name,
        icon: icon,
        color: color,
      );
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _categoryRepository.deleteCategory(
        userId: userId,
        categoryId: categoryId,
      );
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  Future<void> createSubcategory({
    required int categoryId,
    required String name,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _categoryRepository.createSubcategory(
        userId: userId,
        categoryId: categoryId,
        name: name,
      );
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  Future<void> updateSubcategory({
    required int subcategoryId,
    required String name,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _categoryRepository.updateSubcategory(
        userId: userId,
        subcategoryId: subcategoryId,
        name: name,
      );
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  Future<void> deleteSubcategory(int subcategoryId) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _categoryRepository.deleteSubcategory(
        userId: userId,
        subcategoryId: subcategoryId,
      );
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = CategoriesState.initial().copyWith(isLoading: false);
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
    final report = _buildReport(ratesToBrl);

    state = state.copyWith(
      categories: _categories,
      subcategories: _subcategories,
      currencyCode: _currencyCode,
      reportSummary: report.summary,
      reportItems: report.items,
      isLoading: false,
      clearError: true,
    );
  }

  _CategoryReport _buildReport(Map<String, double> ratesToBrl) {
    final selectedMonth = state.selectedMonth;
    final categoriesById = {
      for (final category in _categories) category.id: category,
    };
    final subcategoriesById = {
      for (final subcategory in _subcategories) subcategory.id: subcategory,
    };
    final totalsByCategory = <int, _MutableCategoryReport>{};

    for (final transaction in _transactions) {
      if (transaction.type != 'expense') {
        continue;
      }

      final referenceDate = _referenceDate(transaction);
      if (referenceDate.month != selectedMonth.month ||
          referenceDate.year != selectedMonth.year) {
        continue;
      }

      final category = categoriesById[transaction.categoryId] ??
          CategoryModel(
            id: transaction.categoryId,
            name: 'Sem categoria',
            type: 'expense',
            icon: Icons.category_rounded,
            color: AppColors.primary,
            colorHex: '#006B4F',
          );
      final categoryReport = totalsByCategory.putIfAbsent(
        transaction.categoryId,
        () => _MutableCategoryReport(category),
      );
      final amountCents = _convertTransactionAmount(transaction, ratesToBrl);
      categoryReport.add(transaction, amountCents);

      final subcategoryId = transaction.subcategoryId;
      final subcategory =
          subcategoryId == null ? null : subcategoriesById[subcategoryId];
      categoryReport.addSubcategory(subcategory, amountCents);
    }

    final totalExpenseCents = totalsByCategory.values.fold<int>(
      0,
      (total, item) => total + item.totalCents,
    );
    final paidExpenseCents = totalsByCategory.values.fold<int>(
      0,
      (total, item) => total + item.paidCents,
    );
    final pendingExpenseCents = totalsByCategory.values.fold<int>(
      0,
      (total, item) => total + item.pendingCents,
    );
    final transactionCount = totalsByCategory.values.fold<int>(
      0,
      (total, item) => total + item.transactionCount,
    );

    final items = totalsByCategory.values
        .map((item) => item.toReportItem(totalExpenseCents))
        .toList()
      ..sort((a, b) => b.totalCents.compareTo(a.totalCents));

    return _CategoryReport(
      summary: CategoryReportSummary(
        totalExpenseCents: totalExpenseCents,
        paidExpenseCents: paidExpenseCents,
        pendingExpenseCents: pendingExpenseCents,
        transactionCount: transactionCount,
        categoryCount: items.length,
        biggestCategory: items.isEmpty ? null : items.first,
      ),
      items: items,
    );
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

  void _publishError(Object error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: _friendlyError(error),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('FOREIGN KEY') ||
        message.contains('constraint failed')) {
      return 'Não foi possível excluir porque existem lançamentos usando este item.';
    }
    return message.replaceFirst('Exception: ', '');
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
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final categoriesViewModelProvider =
    StateNotifierProvider<CategoriesViewModel, CategoriesState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return CategoriesViewModel(
    userId: userId,
    categoryRepository: ref.watch(categoryRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
  );
});

class CategoryReportSummary {
  const CategoryReportSummary({
    this.totalExpenseCents = 0,
    this.paidExpenseCents = 0,
    this.pendingExpenseCents = 0,
    this.transactionCount = 0,
    this.categoryCount = 0,
    this.biggestCategory,
  });

  final int totalExpenseCents;
  final int paidExpenseCents;
  final int pendingExpenseCents;
  final int transactionCount;
  final int categoryCount;
  final CategoryReportItem? biggestCategory;

  bool get hasData => totalExpenseCents > 0;
}

class CategoryReportItem {
  const CategoryReportItem({
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
  final List<SubcategoryReportItem> subcategories;
}

class SubcategoryReportItem {
  const SubcategoryReportItem({
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

class _CategoryReport {
  const _CategoryReport({
    required this.summary,
    required this.items,
  });

  final CategoryReportSummary summary;
  final List<CategoryReportItem> items;
}

class _MutableCategoryReport {
  _MutableCategoryReport(this.category);

  final CategoryModel category;
  final Map<String, _MutableSubcategoryReport> subcategories = {};
  int totalCents = 0;
  int paidCents = 0;
  int pendingCents = 0;
  int transactionCount = 0;

  void add(FinanceTransaction transaction, int amountCents) {
    totalCents += amountCents;
    transactionCount += 1;
    if (transaction.isPaid) {
      paidCents += amountCents;
    } else {
      pendingCents += amountCents;
    }
  }

  void addSubcategory(
    SubcategoryModel? subcategory,
    int amountCents,
  ) {
    final name = subcategory?.name ?? 'Sem subcategoria';
    final report = subcategories.putIfAbsent(
      name,
      () => _MutableSubcategoryReport(name),
    );
    report.add(amountCents);
  }

  CategoryReportItem toReportItem(int totalExpenseCents) {
    final subcategoryItems = subcategories.values
        .map((subcategory) => subcategory.toReportItem(totalCents))
        .toList()
      ..sort((a, b) => b.totalCents.compareTo(a.totalCents));

    return CategoryReportItem(
      category: category,
      totalCents: totalCents,
      paidCents: paidCents,
      pendingCents: pendingCents,
      transactionCount: transactionCount,
      percent: totalExpenseCents == 0 ? 0 : totalCents / totalExpenseCents,
      subcategories: subcategoryItems,
    );
  }
}

class _MutableSubcategoryReport {
  _MutableSubcategoryReport(this.name);

  final String name;
  int totalCents = 0;
  int transactionCount = 0;

  void add(int amountCents) {
    totalCents += amountCents;
    transactionCount += 1;
  }

  SubcategoryReportItem toReportItem(int categoryTotalCents) {
    return SubcategoryReportItem(
      name: name,
      totalCents: totalCents,
      transactionCount: transactionCount,
      percent: categoryTotalCents == 0 ? 0 : totalCents / categoryTotalCents,
    );
  }
}

@immutable
class CategoryIconOption {
  const CategoryIconOption({
    required this.name,
    required this.icon,
    required this.label,
  });

  final String name;
  final IconData icon;
  final String label;
}

const categoryIconOptions = [
  CategoryIconOption(
    name: 'category',
    icon: Icons.category_rounded,
    label: 'Geral',
  ),
  CategoryIconOption(
    name: 'salary',
    icon: Icons.payments_rounded,
    label: 'Salário',
  ),
  CategoryIconOption(
    name: 'income',
    icon: Icons.trending_up_rounded,
    label: 'Receita',
  ),
  CategoryIconOption(
    name: 'food',
    icon: Icons.restaurant_rounded,
    label: 'Alimentação',
  ),
  CategoryIconOption(
    name: 'transport',
    icon: Icons.directions_bus_rounded,
    label: 'Transporte',
  ),
  CategoryIconOption(
    name: 'home',
    icon: Icons.home_work_rounded,
    label: 'Moradia',
  ),
  CategoryIconOption(
    name: 'health',
    icon: Icons.favorite_rounded,
    label: 'Saúde',
  ),
  CategoryIconOption(
    name: 'leisure',
    icon: Icons.local_activity_rounded,
    label: 'Lazer',
  ),
  CategoryIconOption(
    name: 'investment',
    icon: Icons.savings_rounded,
    label: 'Investimento',
  ),
  CategoryIconOption(
    name: 'education',
    icon: Icons.school_rounded,
    label: 'Educação',
  ),
  CategoryIconOption(
    name: 'shopping',
    icon: Icons.shopping_bag_rounded,
    label: 'Compras',
  ),
  CategoryIconOption(
    name: 'travel',
    icon: Icons.flight_takeoff_rounded,
    label: 'Viagem',
  ),
  CategoryIconOption(
    name: 'gift',
    icon: Icons.card_giftcard_rounded,
    label: 'Presente',
  ),
  CategoryIconOption(
    name: 'business',
    icon: Icons.work_rounded,
    label: 'Trabalho',
  ),
  CategoryIconOption(
    name: 'bonus',
    icon: Icons.stars_rounded,
    label: 'Bônus',
  ),
];

const categoryColorOptions = [
  '#006B4F',
  '#0A8F4D',
  '#19A974',
  '#2F80ED',
  '#7C3AED',
  '#EC4899',
  '#F59E0B',
  '#D93025',
  '#0F766E',
  '#475569',
];
