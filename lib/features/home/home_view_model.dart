import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_expense_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/transaction_preview.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class HomeState {
  const HomeState({
    required this.userName,
    required this.monthLabel,
    required this.currentBalanceCents,
    required this.projectedBalanceCents,
    required this.initialMonthBalanceCents,
    required this.incomeCents,
    required this.expenseCents,
    required this.creditCard,
    required this.categories,
    required this.recentTransactions,
    this.isBalanceVisible = true,
  });

  factory HomeState.initial({required String userName}) {
    return HomeState(
      userName: userName,
      monthLabel: AppDateUtils.monthYearLabel(DateTime.now()),
      currentBalanceCents: 0,
      projectedBalanceCents: 0,
      initialMonthBalanceCents: 0,
      incomeCents: 0,
      expenseCents: 0,
      creditCard: const CreditCardPreview(
        id: 0,
        name: 'Nenhum cartão',
        lastDigits: '0000',
        brand: 'other',
        brandLabel: 'Outra',
        invoiceCents: 0,
        limitCents: 500000,
        usedPercent: 0,
        color: AppColors.primaryDark,
        colorHex: '#004D3A',
        closingDay: 5,
        dueDay: 15,
        isPrimary: false,
      ),
      categories: const [],
      recentTransactions: const [],
    );
  }

  final String userName;
  final String monthLabel;
  final int currentBalanceCents;
  final int projectedBalanceCents;
  final int initialMonthBalanceCents;
  final int incomeCents;
  final int expenseCents;
  final CreditCardPreview creditCard;
  final List<CategoryExpensePreview> categories;
  final List<TransactionPreview> recentTransactions;
  final bool isBalanceVisible;

  double get availableBudgetPercent {
    if (incomeCents == 0) {
      return 0;
    }
    return ((incomeCents - expenseCents) / incomeCents)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  HomeState copyWith({
    int? currentBalanceCents,
    int? projectedBalanceCents,
    int? initialMonthBalanceCents,
    int? incomeCents,
    int? expenseCents,
    CreditCardPreview? creditCard,
    List<CategoryExpensePreview>? categories,
    List<TransactionPreview>? recentTransactions,
    bool? isBalanceVisible,
  }) {
    return HomeState(
      userName: userName,
      monthLabel: monthLabel,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      projectedBalanceCents:
          projectedBalanceCents ?? this.projectedBalanceCents,
      initialMonthBalanceCents:
          initialMonthBalanceCents ?? this.initialMonthBalanceCents,
      incomeCents: incomeCents ?? this.incomeCents,
      expenseCents: expenseCents ?? this.expenseCents,
      creditCard: creditCard ?? this.creditCard,
      categories: categories ?? this.categories,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel({
    required String userName,
    required int? userId,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _creditCardRepository = creditCardRepository,
        _transactionRepository = transactionRepository,
        super(HomeState.initial(userName: userName)) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final TransactionRepository _transactionRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<CreditCard>>? _creditCardsSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<Account> _accounts = [];
  List<CategoryModel> _categories = [];
  List<CreditCard> _creditCards = [];
  List<FinanceTransaction> _transactions = [];

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts;
        _publishState();
      },
    );

    _categoriesSubscription =
        _categoryRepository.watchCategories(userId).listen(
      (categories) {
        _categories = categories;
        _publishState();
      },
    );

    _creditCardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (cards) {
        _creditCards = cards;
        _publishState();
      },
    );

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState();
      },
    );
  }

  void _publishState() {
    final now = DateTime.now();
    final firstDay = AppDateUtils.firstDayOfMonth(now);
    final lastDay = AppDateUtils.lastDayOfMonth(now);
    final monthTransactions = _transactions.where((transaction) {
      return !transaction.date.isBefore(firstDay) &&
          !transaction.date.isAfter(lastDay);
    }).toList();

    final incomeCents = monthTransactions
        .where((transaction) => transaction.type == 'income')
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final expenseCents = monthTransactions
        .where((transaction) => transaction.type == 'expense')
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final currentBalanceCents = _accounts.fold<int>(
      0,
      (total, account) => total + account.currentBalance,
    );
    final initialMonthBalanceCents =
        currentBalanceCents - incomeCents + expenseCents;
    final categoryMap = {
      for (final category in _categories) category.id: category,
    };
    final accountsById = {for (final account in _accounts) account.id: account};

    state = state.copyWith(
      currentBalanceCents: currentBalanceCents,
      projectedBalanceCents: currentBalanceCents,
      initialMonthBalanceCents: initialMonthBalanceCents,
      incomeCents: incomeCents,
      expenseCents: expenseCents,
      creditCard: _buildPrimaryCard(accountsById),
      categories: _buildCategoryPreviews(
        monthTransactions: monthTransactions,
        categoryMap: categoryMap,
        expenseCents: expenseCents,
      ),
      recentTransactions: _buildRecentTransactions(categoryMap),
    );
  }

  CreditCardPreview _buildPrimaryCard(Map<int, Account> accountsById) {
    CreditCard? selectedCard;
    for (final card in _creditCards) {
      if (card.isPrimary) {
        selectedCard = card;
        break;
      }
    }
    selectedCard ??= _creditCards.isEmpty ? null : _creditCards.first;

    if (selectedCard == null) {
      return state.creditCard;
    }

    final defaultAccount = accountsById[selectedCard.defaultPaymentAccountId];
    final usedPercent = selectedCard.limit == 0
        ? 0.0
        : selectedCard.currentInvoice / selectedCard.limit;

    return CreditCardPreview(
      id: selectedCard.id,
      name: selectedCard.name,
      bankName: selectedCard.bankName,
      lastDigits: selectedCard.lastDigits,
      brand: selectedCard.brand,
      brandLabel: _brandLabel(selectedCard.brand),
      invoiceCents: selectedCard.currentInvoice,
      limitCents: selectedCard.limit,
      usedPercent: usedPercent.clamp(0.0, 1.0).toDouble(),
      color: _parseColor(selectedCard.color),
      colorHex: selectedCard.color,
      closingDay: selectedCard.closingDay,
      dueDay: selectedCard.dueDay,
      isPrimary: selectedCard.isPrimary,
      defaultPaymentAccountId: selectedCard.defaultPaymentAccountId,
      defaultPaymentAccountName: defaultAccount?.name,
    );
  }

  List<CategoryExpensePreview> _buildCategoryPreviews({
    required List<FinanceTransaction> monthTransactions,
    required Map<int, CategoryModel> categoryMap,
    required int expenseCents,
  }) {
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

    final entries = totalsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (final entry in entries.take(5))
        CategoryExpensePreview(
          name: categoryMap[entry.key]?.name ?? 'Sem categoria',
          amountCents: entry.value,
          percent: expenseCents == 0 ? 0 : entry.value / expenseCents,
          color: categoryMap[entry.key]?.color ?? AppColors.primary,
          icon: categoryMap[entry.key]?.icon ?? Icons.category_rounded,
        ),
    ];
  }

  List<TransactionPreview> _buildRecentTransactions(
    Map<int, CategoryModel> categoryMap,
  ) {
    final sortedTransactions = [..._transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return [
      for (final transaction in sortedTransactions.take(4))
        TransactionPreview(
          title: transaction.description,
          subtitle:
              '${categoryMap[transaction.categoryId]?.name ?? 'Sem categoria'} • ${_dateLabel(transaction.date)}',
          amountCents: transaction.amount,
          icon: categoryMap[transaction.categoryId]?.icon ??
              Icons.category_rounded,
          iconColor:
              categoryMap[transaction.categoryId]?.color ?? AppColors.primary,
          isIncome: transaction.type == 'income',
        ),
    ];
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) {
      return 'Hoje';
    }
    if (target == today.subtract(const Duration(days: 1))) {
      return 'Ontem';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _brandLabel(String brand) {
    return switch (brand) {
      'visa' => 'Visa',
      'mastercard' => 'Mastercard',
      'elo' => 'Elo',
      'amex' => 'American Express',
      'hipercard' => 'Hipercard',
      _ => 'Outra',
    };
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primaryDark : Color(parsed);
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _creditCardsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final user = ref.watch(authStateProvider.select((state) => state.user));
  return HomeViewModel(
    userName: user?.name ?? 'Camila Souza',
    userId: user?.id,
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
