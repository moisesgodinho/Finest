import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/create_transaction_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class TransactionListItem {
  const TransactionListItem({
    required this.id,
    required this.title,
    required this.accountName,
    required this.categoryName,
    required this.amountCents,
    required this.date,
    required this.type,
    required this.icon,
    required this.iconColor,
  });

  final int id;
  final String title;
  final String accountName;
  final String categoryName;
  final int amountCents;
  final DateTime date;
  final String type;
  final IconData icon;
  final Color iconColor;

  bool get isIncome => type == 'income';
}

class TransactionsState {
  const TransactionsState({
    this.selectedType = 'all',
    this.transactions = const [],
    this.accounts = const [],
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final String selectedType;
  final List<TransactionListItem> transactions;
  final List<AccountPreview> accounts;
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? errorMessage;

  List<TransactionListItem> get filteredTransactions {
    if (selectedType == 'all') {
      return transactions;
    }
    return transactions
        .where((transaction) => transaction.type == selectedType)
        .toList();
  }

  List<CategoryModel> categoriesForType(String type) {
    return categories.where((category) => category.type == type).toList();
  }

  TransactionsState copyWith({
    String? selectedType,
    List<TransactionListItem>? transactions,
    List<AccountPreview>? accounts,
    List<CategoryModel>? categories,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransactionsState(
      selectedType: selectedType ?? this.selectedType,
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TransactionsViewModel extends StateNotifier<TransactionsState> {
  TransactionsViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _transactionRepository = transactionRepository,
        super(const TransactionsState(isLoading: true)) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<Account> _rawAccounts = [];
  List<CategoryModel> _rawCategories = [];
  List<FinanceTransaction> _rawTransactions = [];

  void selectType(String type) {
    state = state.copyWith(selectedType: type);
  }

  Future<void> createTransaction({
    required int accountId,
    required int categoryId,
    required String type,
    required String description,
    required int amountCents,
    required DateTime date,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _transactionRepository.createTransaction(
        CreateTransactionRequest(
          userId: userId,
          accountId: accountId,
          categoryId: categoryId,
          type: type,
          description: description,
          amountCents: amountCents,
          date: date,
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

  Future<void> deleteTransaction(TransactionListItem transaction) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _transactionRepository.deleteTransaction(
        userId: userId,
        transactionId: transaction.id,
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
      state = const TransactionsState();
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _rawAccounts = accounts;
        _publishState();
      },
      onError: _publishError,
    );

    _categoriesSubscription =
        _categoryRepository.watchCategories(userId).listen(
      (categories) {
        _rawCategories = categories;
        _publishState();
      },
      onError: _publishError,
    );

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _rawTransactions = transactions;
        _publishState();
      },
      onError: _publishError,
    );
  }

  void _publishState() {
    final accounts = _rawAccounts.map(_mapAccount).toList();
    final accountNames = {
      for (final account in _rawAccounts) account.id: account.name,
    };
    final categoryMap = {
      for (final category in _rawCategories) category.id: category,
    };

    state = state.copyWith(
      accounts: accounts,
      categories: _rawCategories,
      transactions: [
        for (final transaction in _rawTransactions)
          _mapTransaction(
            transaction,
            accountNames: accountNames,
            categoryMap: categoryMap,
          ),
      ],
      isLoading: false,
      clearError: true,
    );
  }

  void _publishError(Object error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: error.toString(),
    );
  }

  TransactionListItem _mapTransaction(
    FinanceTransaction transaction, {
    required Map<int, String> accountNames,
    required Map<int, CategoryModel> categoryMap,
  }) {
    final category = categoryMap[transaction.categoryId];

    return TransactionListItem(
      id: transaction.id,
      title: transaction.description,
      accountName: accountNames[transaction.accountId] ?? 'Conta removida',
      categoryName: category?.name ?? 'Sem categoria',
      amountCents: transaction.amount,
      date: transaction.date,
      type: transaction.type,
      icon: category?.icon ?? Icons.category_rounded,
      iconColor: category?.color ?? Colors.grey,
    );
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
    return parsed == null ? Colors.green : Color(parsed);
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
    _categoriesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final transactionsViewModelProvider =
    StateNotifierProvider<TransactionsViewModel, TransactionsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return TransactionsViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
