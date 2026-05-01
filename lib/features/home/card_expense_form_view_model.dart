import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/models/create_transaction_request.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/transaction_name_suggestion.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class CardExpenseFormState {
  const CardExpenseFormState({
    required this.cards,
    required this.categories,
    required this.subcategories,
    required this.suggestions,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<CreditCardPreview> cards;
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

  CardExpenseFormState copyWith({
    List<CreditCardPreview>? cards,
    List<CategoryModel>? categories,
    List<SubcategoryModel>? subcategories,
    List<TransactionNameSuggestion>? suggestions,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CardExpenseFormState(
      cards: cards ?? this.cards,
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

class CardExpenseFormViewModel extends StateNotifier<CardExpenseFormState> {
  CardExpenseFormViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CreditCardRepository creditCardRepository,
    required CategoryRepository categoryRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _creditCardRepository = creditCardRepository,
        _categoryRepository = categoryRepository,
        _transactionRepository = transactionRepository,
        super(
          const CardExpenseFormState(
            cards: [],
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
  final CreditCardRepository _creditCardRepository;
  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CreditCard>>? _cardsSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<SubcategoryModel>>? _subcategoriesSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<Account> _accounts = [];
  List<CreditCard> _cards = [];

  Future<void> saveCardExpense({
    required String name,
    required int amountCents,
    required String expenseKind,
    required int cardId,
    required int invoiceMonth,
    required int invoiceYear,
    required int categoryId,
    required DateTime purchaseDate,
    int? subcategoryId,
    int? totalInstallments,
    bool installmentAmountIsTotal = false,
  }) async {
    final userId = _requireUserId();
    CreditCardPreview? card;
    for (final candidate in state.cards) {
      if (candidate.id == cardId) {
        card = candidate;
        break;
      }
    }
    if (card == null) {
      throw StateError('Selecione um cartão válido.');
    }
    final paymentAccountId = card.defaultPaymentAccountId;
    if (paymentAccountId == null) {
      throw StateError('O cartão selecionado não tem conta padrão.');
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final installments =
          expenseKind == 'installment' ? totalInstallments ?? 1 : 1;
      final installmentAmounts = _installmentAmounts(
        amountCents: amountCents,
        installments: installments,
        splitTotal: expenseKind == 'installment' && installmentAmountIsTotal,
      );

      for (var index = 0; index < installments; index++) {
        final invoiceDate = DateTime(invoiceYear, invoiceMonth + index);
        await _transactionRepository.createTransaction(
          CreateTransactionRequest(
            userId: userId,
            accountId: paymentAccountId,
            creditCardId: card.id,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            type: 'expense',
            description: installments > 1
                ? '${name.trim()} (${index + 1}/$installments)'
                : name,
            amountCents: installmentAmounts[index],
            date: purchaseDate,
            paymentMethod: 'credit_card',
            invoiceMonth: invoiceDate.month,
            invoiceYear: invoiceDate.year,
            expenseKind: expenseKind,
            installmentNumber: installments > 1 ? index + 1 : null,
            totalInstallments: installments > 1 ? installments : null,
            isRecurring: expenseKind == 'fixed_monthly',
          ),
        );
      }
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  List<int> _installmentAmounts({
    required int amountCents,
    required int installments,
    required bool splitTotal,
  }) {
    if (!splitTotal || installments <= 1) {
      return List.filled(installments, amountCents);
    }

    if (amountCents < installments) {
      throw ArgumentError(
        'O valor total nÃ£o permite dividir todas as parcelas com valor maior que zero.',
      );
    }

    final baseAmount = amountCents ~/ installments;
    final remainder = amountCents % installments;

    return [
      for (var index = 0; index < installments; index++)
        baseAmount + (index < remainder ? 1 : 0),
    ];
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
      state = const CardExpenseFormState(
        cards: [],
        categories: [],
        subcategories: [],
        suggestions: [],
      );
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts;
        _publishCards();
      },
      onError: _handleStreamError,
    );

    _cardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (cards) {
        _cards = cards;
        _publishCards();
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
          transaction.paymentMethod != 'credit_card' ||
          transaction.creditCardId == null) {
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
          creditCardId: transaction.creditCardId,
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

  void _publishCards() {
    final accountsById = {for (final account in _accounts) account.id: account};
    state = state.copyWith(
      cards: [
        for (final card in _cards) _mapCard(card, accountsById),
      ],
      isLoading: false,
      clearError: true,
    );
  }

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  CreditCardPreview _mapCard(
    CreditCard card,
    Map<int, Account> accountsById,
  ) {
    final usedPercent =
        card.limit == 0 ? 0.0 : card.currentInvoice / card.limit;
    final defaultAccount = accountsById[card.defaultPaymentAccountId];

    return CreditCardPreview(
      id: card.id,
      name: card.name,
      bankName: card.bankName,
      lastDigits: card.lastDigits,
      brand: card.brand,
      brandLabel: _brandLabel(card.brand),
      invoiceCents: card.currentInvoice,
      limitCents: card.limit,
      usedPercent: usedPercent.clamp(0.0, 1.0).toDouble(),
      color: _parseColor(card.color),
      colorHex: card.color,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
      isPrimary: card.isPrimary,
      defaultPaymentAccountId: card.defaultPaymentAccountId,
      defaultPaymentAccountName: defaultAccount?.name,
    );
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
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _cardsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final cardExpenseFormViewModelProvider = StateNotifierProvider.autoDispose<
    CardExpenseFormViewModel, CardExpenseFormState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return CardExpenseFormViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
