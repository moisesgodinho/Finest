import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/create_transaction_request.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/transaction_name_suggestion.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class ExpenseFormState {
  const ExpenseFormState({
    required this.accounts,
    required this.categories,
    required this.subcategories,
    required this.suggestions,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AccountPreview> accounts;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final List<TransactionNameSuggestion> suggestions;
  final bool isLoading;
  final String? errorMessage;

  List<SubcategoryModel> subcategoriesFor(int categoryId) {
    return subcategories
        .where((subcategory) => subcategory.categoryId == categoryId)
        .toList();
  }

  List<TransactionNameSuggestion> suggestionsForName(String value) {
    final query = _normalize(value);
    if (query.length < 2) {
      return const [];
    }

    return suggestions
        .where(
            (suggestion) => _normalize(suggestion.description).contains(query))
        .take(4)
        .toList();
  }

  ExpenseFormState copyWith({
    List<AccountPreview>? accounts,
    List<CategoryModel>? categories,
    List<SubcategoryModel>? subcategories,
    List<TransactionNameSuggestion>? suggestions,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpenseFormState(
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}

class ExpenseFormViewModel extends StateNotifier<ExpenseFormState> {
  ExpenseFormViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _transactionRepository = transactionRepository,
        super(
          const ExpenseFormState(
            accounts: [],
            categories: [],
            subcategories: [],
            suggestions: [],
            isLoading: true,
          ),
        ) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<SubcategoryModel>>? _subcategoriesSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;

  Future<void> saveExpense({
    required String name,
    required int amountCents,
    required String expenseKind,
    required int accountId,
    required int categoryId,
    required DateTime date,
    int? subcategoryId,
    int? totalInstallments,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _transactionRepository.createTransaction(
        CreateTransactionRequest(
          userId: userId,
          accountId: accountId,
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          type: 'expense',
          description: name,
          amountCents: amountCents,
          date: date,
          paymentMethod: 'account',
          expenseKind: expenseKind,
          installmentNumber: expenseKind == 'installment' ? 1 : null,
          totalInstallments:
              expenseKind == 'installment' ? totalInstallments : null,
          isRecurring: expenseKind == 'fixed_monthly',
        ),
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

  Future<int> createExpenseCategory(String name) async {
    final userId = _requireUserId();
    return _categoryRepository.createExpenseCategory(
      userId: userId,
      name: name,
    );
  }

  Future<int> createSubcategory({
    required int categoryId,
    required String name,
  }) async {
    final userId = _requireUserId();
    return _categoryRepository.createSubcategory(
      userId: userId,
      categoryId: categoryId,
      name: name,
    );
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = const ExpenseFormState(
        accounts: [],
        categories: [],
        subcategories: [],
        suggestions: [],
      );
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        state = state.copyWith(
          accounts: accounts.map(_mapAccount).toList(),
          isLoading: false,
          clearError: true,
        );
      },
      onError: _handleStreamError,
    );

    _categoriesSubscription =
        _categoryRepository.watchCategories(userId).listen(
      (categories) {
        state = state.copyWith(
          categories: categories
              .where((category) => category.type == 'expense')
              .toList(),
          isLoading: false,
          clearError: true,
        );
      },
      onError: _handleStreamError,
    );

    _subcategoriesSubscription =
        _categoryRepository.watchSubcategories(userId).listen(
      (subcategories) {
        state = state.copyWith(
          subcategories: subcategories,
          isLoading: false,
          clearError: true,
        );
      },
      onError: _handleStreamError,
    );

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        state = state.copyWith(
          suggestions: _buildSuggestions(transactions),
          isLoading: false,
          clearError: true,
        );
      },
      onError: _handleStreamError,
    );
  }

  List<TransactionNameSuggestion> _buildSuggestions(
    List<FinanceTransaction> transactions,
  ) {
    final seenDescriptions = <String>{};
    final suggestions = <TransactionNameSuggestion>[];

    for (final transaction in transactions) {
      if (transaction.type != 'expense' ||
          transaction.paymentMethod == 'credit_card') {
        continue;
      }

      final key = _normalize(transaction.description);
      if (key.isEmpty || seenDescriptions.contains(key)) {
        continue;
      }

      seenDescriptions.add(key);
      suggestions.add(
        TransactionNameSuggestion(
          id: transaction.id,
          description: transaction.description,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subcategoryId: transaction.subcategoryId,
        ),
      );
    }

    return suggestions;
  }

  void _handleStreamError(Object error) {
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

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      balanceCents: account.currentBalance,
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final expenseFormViewModelProvider =
    StateNotifierProvider.autoDispose<ExpenseFormViewModel, ExpenseFormState>(
  (ref) {
    final userId = ref.watch(
      authStateProvider.select((state) => state.user?.id),
    );

    return ExpenseFormViewModel(
      userId: userId,
      accountRepository: ref.watch(accountRepositoryProvider),
      categoryRepository: ref.watch(categoryRepositoryProvider),
      transactionRepository: ref.watch(transactionRepositoryProvider),
    );
  },
);
