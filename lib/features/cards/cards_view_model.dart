import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/currency/exchange_rate_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_credit_card_request.dart';
import '../../data/models/create_transaction_request.dart';
import '../../data/models/category_model.dart';
import '../../data/models/credit_card_invoice_preview.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/transaction_series_scope.dart';
import '../../data/models/update_credit_card_request.dart';
import '../../data/models/update_credit_card_expense_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class CardsState {
  const CardsState({
    required this.cards,
    required this.accounts,
    required this.invoices,
    required this.categories,
    required this.subcategories,
    this.currencyCode = 'BRL',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<CreditCardPreview> cards;
  final List<AccountPreview> accounts;
  final List<CreditCardInvoicePreview> invoices;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final String currencyCode;
  final bool isLoading;
  final String? errorMessage;

  CreditCardPreview? get primaryCard {
    for (final card in cards) {
      if (card.isPrimary) {
        return card;
      }
    }
    return cards.isEmpty ? null : cards.first;
  }

  CreditCardInvoicePreview invoiceForCard(CreditCardPreview card) {
    final now = DateTime.now();
    return invoiceForCardMonth(
      card,
      month: now.month,
      year: now.year,
    );
  }

  CreditCardInvoicePreview invoiceForCardMonth(
    CreditCardPreview card, {
    required int month,
    required int year,
  }) {
    for (final invoice
        in invoices.where((invoice) => invoice.cardId == card.id)) {
      if (invoice.month == month && invoice.year == year) {
        return invoice;
      }
    }

    return CreditCardInvoicePreview(
      id: 0,
      cardId: card.id,
      cardName: card.name,
      cardLastDigits: card.lastDigits,
      month: month,
      year: year,
      amountCents: 0,
      currencyCode: card.currencyCode,
      displayAmountCents: 0,
      status: 'open',
      statusLabel: 'Aberta',
      dueDate: DateTime(year, month, _safeDay(year, month, card.dueDay)),
      paymentAccountId: card.defaultPaymentAccountId,
      paymentAccountName: card.defaultPaymentAccountName,
      cardColor: card.color,
      transactions: const [],
    );
  }

  List<DateTime> invoiceMonthsForCard(CreditCardPreview card) {
    final keyedMonths = <String, DateTime>{};
    final now = DateTime.now();
    keyedMonths['${now.year}-${now.month}'] = DateTime(now.year, now.month);

    for (final invoice
        in invoices.where((invoice) => invoice.cardId == card.id)) {
      keyedMonths['${invoice.year}-${invoice.month}'] =
          DateTime(invoice.year, invoice.month);
    }

    return keyedMonths.values.toList()..sort((a, b) => b.compareTo(a));
  }

  List<CategoryModel> get expenseCategories {
    return categories.where((category) => category.type == 'expense').toList();
  }

  List<CategoryModel> get incomeCategories {
    return categories.where((category) => category.type == 'income').toList();
  }

  List<SubcategoryModel> subcategoriesFor(int categoryId) {
    return subcategories
        .where((subcategory) => subcategory.categoryId == categoryId)
        .toList();
  }

  int get totalInvoicesCents {
    return invoices
        .where((invoice) => !invoice.isPaid)
        .fold<int>(0, (total, invoice) => total + invoice.displayAmountCents);
  }

  int get availableLimitCents {
    return cards.fold<int>(
      0,
      (total, card) =>
          total + (card.displayLimitCents - card.displayInvoiceCents),
    );
  }

  CardsState copyWith({
    List<CreditCardPreview>? cards,
    List<AccountPreview>? accounts,
    List<CreditCardInvoicePreview>? invoices,
    List<CategoryModel>? categories,
    List<SubcategoryModel>? subcategories,
    String? currencyCode,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CardsState(
      cards: cards ?? this.cards,
      accounts: accounts ?? this.accounts,
      invoices: invoices ?? this.invoices,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      currencyCode: currencyCode ?? this.currencyCode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

int _safeDay(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return day.clamp(1, lastDay).toInt();
}

class CardsViewModel extends StateNotifier<CardsState> {
  CardsViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required TransactionRepository transactionRepository,
    required ExchangeRateService exchangeRateService,
    required String currencyCode,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _creditCardRepository = creditCardRepository,
        _transactionRepository = transactionRepository,
        _exchangeRateService = exchangeRateService,
        _currencyCode = currencyCode,
        super(
          CardsState(
            cards: const [],
            accounts: const [],
            invoices: const [],
            categories: const [],
            subcategories: const [],
            currencyCode: currencyCode,
            isLoading: true,
          ),
        ) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final TransactionRepository _transactionRepository;
  final ExchangeRateService _exchangeRateService;
  final String _currencyCode;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CreditCard>>? _cardsSubscription;
  StreamSubscription<List<CreditCardInvoice>>? _invoicesSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<SubcategoryModel>>? _subcategoriesSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<Account> _accounts = [];
  List<CreditCard> _cards = [];
  List<CreditCardInvoice> _invoices = [];
  List<CategoryModel> _categories = [];
  List<SubcategoryModel> _subcategories = [];
  List<FinanceTransaction> _transactions = [];

  Future<void> createCard({
    required String name,
    required String lastDigits,
    required String brand,
    required int limitCents,
    required int currentInvoiceCents,
    required int defaultPaymentAccountId,
    required int closingDay,
    required int dueDay,
    required bool isPrimary,
    required String color,
    String? bankName,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.createCard(
        CreateCreditCardRequest(
          userId: userId,
          name: name,
          bankName: bankName,
          lastDigits: lastDigits,
          brand: brand,
          limitCents: limitCents,
          currentInvoiceCents: currentInvoiceCents,
          defaultPaymentAccountId: defaultPaymentAccountId,
          closingDay: closingDay,
          dueDay: dueDay,
          isPrimary: isPrimary,
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

  Future<void> updateCard({
    required CreditCardPreview card,
    required String name,
    required String lastDigits,
    required String brand,
    required int limitCents,
    required int currentInvoiceCents,
    required int defaultPaymentAccountId,
    required int closingDay,
    required int dueDay,
    required bool isPrimary,
    required String color,
    String? bankName,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final newDefaultAccount = _accounts
          .where((account) => account.id == defaultPaymentAccountId)
          .firstOrNull;
      if (newDefaultAccount != null &&
          newDefaultAccount.currencyCode.toUpperCase() !=
              card.currencyCode.toUpperCase() &&
          _cardHasFinancialEntries(card.id)) {
        throw StateError(
          'Este cartÃ£o jÃ¡ possui faturas ou compras. Para mudar a moeda, crie um novo cartÃ£o vinculado Ã nova conta.',
        );
      }

      await _creditCardRepository.updateCard(
        UpdateCreditCardRequest(
          id: card.id,
          userId: userId,
          name: name,
          bankName: bankName,
          lastDigits: lastDigits,
          brand: brand,
          limitCents: limitCents,
          currentInvoiceCents: currentInvoiceCents,
          defaultPaymentAccountId: defaultPaymentAccountId,
          closingDay: closingDay,
          dueDay: dueDay,
          isPrimary: isPrimary,
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

  Future<void> deleteCard(CreditCardPreview card) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.deleteCard(
        userId: userId,
        cardId: card.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> payCurrentInvoice(CreditCardPreview card) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.payCurrentInvoice(
        userId: userId,
        cardId: card.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> payInvoice(CreditCardInvoicePreview invoice) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.payInvoice(
        userId: userId,
        invoiceId: invoice.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> addInvoiceEntry({
    required CreditCardPreview card,
    required CreditCardInvoicePreview invoice,
    required String entryKind,
    required String description,
    required int amountCents,
    required int categoryId,
    required int? subcategoryId,
    required DateTime date,
  }) async {
    if (invoice.isPaid) {
      throw StateError('Esta fatura já foi paga.');
    }

    final accountId = invoice.paymentAccountId ?? card.defaultPaymentAccountId;
    if (accountId == null) {
      throw StateError('Defina uma conta padrão para o cartão.');
    }

    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _transactionRepository.createTransaction(
        CreateTransactionRequest(
          userId: userId,
          accountId: accountId,
          creditCardId: card.id,
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          type: entryKind == 'expense' ? 'expense' : 'income',
          description: description,
          amountCents: amountCents,
          date: date,
          paymentMethod: 'credit_card',
          invoiceMonth: invoice.month,
          invoiceYear: invoice.year,
          expenseKind: entryKind == 'expense' ? 'single' : entryKind,
          isPaid: true,
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

  Future<void> updateInvoiceTransaction({
    required CreditCardInvoicePreview invoice,
    required CreditCardInvoiceTransactionPreview transaction,
    required String description,
    required int amountCents,
    required int categoryId,
    required int? subcategoryId,
    required DateTime date,
    TransactionSeriesScope scope = TransactionSeriesScope.current,
  }) async {
    if (invoice.isPaid) {
      throw StateError('Esta fatura já foi paga.');
    }

    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final targets = _invoiceTransactionTargetsFor(transaction, scope);
      final useInstallmentSuffix = targets.any(
        (target) => _hasInstallmentSuffix(target.description),
      );

      for (final target in targets) {
        await _transactionRepository.updateCreditCardExpense(
          UpdateCreditCardExpenseRequest(
            userId: userId,
            transactionId: target.id,
            description: _seriesDescription(
              description,
              installmentNumber: target.installmentNumber,
              totalInstallments: target.totalInstallments,
              useSuffix: useInstallmentSuffix,
            ),
            amountCents: amountCents,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            date: date,
          ),
        );
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> deleteInvoiceTransaction({
    required CreditCardInvoicePreview invoice,
    required CreditCardInvoiceTransactionPreview transaction,
    TransactionSeriesScope scope = TransactionSeriesScope.current,
  }) async {
    if (invoice.isPaid) {
      throw StateError('Esta fatura já foi paga.');
    }

    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final targets = _invoiceTransactionTargetsFor(transaction, scope);
      for (final target in targets) {
        await _transactionRepository.deleteTransaction(
          userId: userId,
          transactionId: target.id,
        );
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  List<FinanceTransaction> _invoiceTransactionTargetsFor(
    CreditCardInvoiceTransactionPreview selected,
    TransactionSeriesScope scope,
  ) {
    final selectedRaw = _transactionById(selected.id);
    if (selectedRaw == null) {
      return const [];
    }
    if (scope == TransactionSeriesScope.current ||
        !selected.supportsSeriesScope) {
      return [selectedRaw];
    }

    final matches = _transactions
        .where(
          (transaction) =>
              _matchesCreditCardInstallmentSeries(transaction, selectedRaw),
        )
        .where(
          (transaction) => _matchesInstallmentScope(
            targetInstallment: transaction.installmentNumber,
            selectedInstallment: selectedRaw.installmentNumber,
            scope: scope,
          ),
        )
        .toList()
      ..sort(_compareInstallmentTransactions);

    return matches.isEmpty ? [selectedRaw] : matches;
  }

  FinanceTransaction? _transactionById(int id) {
    for (final transaction in _transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }
    return null;
  }

  bool _matchesCreditCardInstallmentSeries(
    FinanceTransaction candidate,
    FinanceTransaction selected,
  ) {
    return candidate.userId == selected.userId &&
        candidate.paymentMethod == 'credit_card' &&
        candidate.paymentMethod == selected.paymentMethod &&
        candidate.creditCardId == selected.creditCardId &&
        candidate.accountId == selected.accountId &&
        candidate.categoryId == selected.categoryId &&
        candidate.subcategoryId == selected.subcategoryId &&
        candidate.type == selected.type &&
        candidate.expenseKind == selected.expenseKind &&
        candidate.totalInstallments == selected.totalInstallments &&
        _seriesBaseName(candidate.description) ==
            _seriesBaseName(selected.description);
  }

  bool _matchesInstallmentScope({
    required int? targetInstallment,
    required int? selectedInstallment,
    required TransactionSeriesScope scope,
  }) {
    if (scope == TransactionSeriesScope.all) {
      return true;
    }
    if (scope == TransactionSeriesScope.current) {
      return targetInstallment == selectedInstallment;
    }

    return (targetInstallment ?? 0) >= (selectedInstallment ?? 0);
  }

  int _compareInstallmentTransactions(
    FinanceTransaction left,
    FinanceTransaction right,
  ) {
    final installmentCompare =
        (left.installmentNumber ?? 0).compareTo(right.installmentNumber ?? 0);
    if (installmentCompare != 0) {
      return installmentCompare;
    }
    final leftInvoice = DateTime(
      left.invoiceYear ?? left.date.year,
      left.invoiceMonth ?? left.date.month,
    );
    final rightInvoice = DateTime(
      right.invoiceYear ?? right.date.year,
      right.invoiceMonth ?? right.date.month,
    );
    return leftInvoice.compareTo(rightInvoice);
  }

  String _seriesDescription(
    String value, {
    required int? installmentNumber,
    required int? totalInstallments,
    required bool useSuffix,
  }) {
    final baseName = _seriesBaseName(value);
    if (!useSuffix || installmentNumber == null || totalInstallments == null) {
      return baseName;
    }
    return '$baseName ($installmentNumber/$totalInstallments)';
  }

  String _seriesBaseName(String value) {
    return value.trim().replaceFirst(
          RegExp(r'\s*\(\d+/\d+\)\s*$'),
          '',
        );
  }

  bool _hasInstallmentSuffix(String value) {
    return RegExp(r'\(\d+/\d+\)\s*$').hasMatch(value.trim());
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = CardsState(
        cards: const [],
        accounts: const [],
        invoices: const [],
        categories: const [],
        subcategories: const [],
        currencyCode: _currencyCode,
      );
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts;
        _publishState();
      },
      onError: _handleStreamError,
    );

    _cardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (cards) {
        _cards = cards;
        _publishState();
      },
      onError: _handleStreamError,
    );

    _invoicesSubscription = _creditCardRepository.watchInvoices(userId).listen(
      (invoices) {
        _invoices = invoices;
        _publishState();
      },
      onError: _handleStreamError,
    );

    _categoriesSubscription =
        _categoryRepository.watchCategories(userId).listen(
      (categories) {
        _categories = categories;
        _publishState();
      },
      onError: _handleStreamError,
    );

    _subcategoriesSubscription =
        _categoryRepository.watchSubcategories(userId).listen(
      (subcategories) {
        _subcategories = subcategories;
        _publishState();
      },
      onError: _handleStreamError,
    );

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState();
      },
      onError: _handleStreamError,
    );
  }

  Future<void> _publishState() async {
    final ratesToBrl = await _exchangeRateService.ratesToBrlSnapshot();
    final accountsById = {for (final account in _accounts) account.id: account};
    final cardsById = {for (final card in _cards) card.id: card};
    final categoriesById = {
      for (final category in _categories) category.id: category,
    };
    final subcategoriesById = {
      for (final subcategory in _subcategories) subcategory.id: subcategory,
    };
    final currentInvoiceTotalsByCard = _currentInvoiceTotalsByCard();

    state = state.copyWith(
      accounts: _accounts
          .where((account) => account.type != 'goal')
          .map(_mapAccount)
          .toList(),
      cards: [
        for (final card in _cards)
          _mapCard(
            card,
            accountsById,
            currentInvoiceCents: currentInvoiceTotalsByCard[card.id],
            ratesToBrl: ratesToBrl,
          ),
      ],
      categories: _categories,
      subcategories: _subcategories,
      invoices: _mapInvoicePreviews(
        cardsById: cardsById,
        accountsById: accountsById,
        categoriesById: categoriesById,
        subcategoriesById: subcategoriesById,
        ratesToBrl: ratesToBrl,
      ),
      currencyCode: _currencyCode,
      isLoading: false,
      clearError: true,
    );
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

  Map<int, int> _currentInvoiceTotalsByCard() {
    final now = DateTime.now();
    final totals = <int, int>{};

    for (final transaction in _transactions) {
      final creditCardId = transaction.creditCardId;
      if (creditCardId == null ||
          transaction.paymentMethod != 'credit_card' ||
          transaction.invoiceMonth != now.month ||
          transaction.invoiceYear != now.year) {
        continue;
      }

      totals.update(
        creditCardId,
        (total) => total + _invoiceAmountDelta(transaction),
        ifAbsent: () => _invoiceAmountDelta(transaction),
      );
    }

    return {
      for (final entry in totals.entries)
        entry.key: entry.value.clamp(0, 1 << 31).toInt(),
    };
  }

  bool _cardHasFinancialEntries(int cardId) {
    final hasTransactions = _transactions.any(
      (transaction) =>
          transaction.paymentMethod == 'credit_card' &&
          transaction.creditCardId == cardId,
    );
    final hasInvoices = _invoices.any(
      (invoice) => invoice.creditCardId == cardId && invoice.amount > 0,
    );
    return hasTransactions || hasInvoices;
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
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  CreditCardPreview _mapCard(
    CreditCard card,
    Map<int, Account> accountsById, {
    int? currentInvoiceCents,
    required Map<String, double> ratesToBrl,
  }) {
    final defaultAccount = accountsById[card.defaultPaymentAccountId];
    final invoiceCents = currentInvoiceCents ?? card.currentInvoice;
    final currencyCode = defaultAccount?.currencyCode ?? 'BRL';
    final usedPercent = card.limit == 0 ? 0.0 : invoiceCents / card.limit;

    return CreditCardPreview(
      id: card.id,
      name: card.name,
      bankName: card.bankName,
      lastDigits: card.lastDigits,
      brand: card.brand,
      brandLabel: _brandLabel(card.brand),
      invoiceCents: invoiceCents,
      limitCents: card.limit,
      currencyCode: currencyCode,
      displayInvoiceCents: _convertCents(
        amountCents: invoiceCents,
        fromCurrency: currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      displayLimitCents: _convertCents(
        amountCents: card.limit,
        fromCurrency: currencyCode,
        ratesToBrl: ratesToBrl,
      ),
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

  CreditCardInvoicePreview _mapInvoice(
    CreditCardInvoice invoice, {
    required CreditCard card,
    required Map<int, Account> accountsById,
    required Map<int, CategoryModel> categoriesById,
    required Map<int, SubcategoryModel> subcategoriesById,
    required Map<String, double> ratesToBrl,
  }) {
    final account = accountsById[invoice.paymentAccountId];
    final defaultAccount = accountsById[card.defaultPaymentAccountId];
    final currencyCode =
        account?.currencyCode ?? defaultAccount?.currencyCode ?? 'BRL';
    final transactions = _creditCardTransactionsFor(
      cardId: invoice.creditCardId,
      month: invoice.month,
      year: invoice.year,
    );
    final transactionTotal = transactions.fold<int>(
      0,
      (total, transaction) => total + _invoiceAmountDelta(transaction),
    );
    final invoiceAmount = transactions.isEmpty
        ? invoice.amount
        : transactionTotal.clamp(0, 1 << 31).toInt();
    final effectiveStatus = invoice.status == 'open' &&
            _isInvoiceClosed(
              month: invoice.month,
              year: invoice.year,
              closingDay: card.closingDay,
            )
        ? 'closed'
        : invoice.status;

    return CreditCardInvoicePreview(
      id: invoice.id,
      cardId: invoice.creditCardId,
      cardName: card.name,
      cardLastDigits: card.lastDigits,
      month: invoice.month,
      year: invoice.year,
      amountCents: invoiceAmount,
      currencyCode: currencyCode,
      displayAmountCents: _convertCents(
        amountCents: invoiceAmount,
        fromCurrency: currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      status: effectiveStatus,
      statusLabel: _invoiceStatusLabel(effectiveStatus),
      dueDate: invoice.dueDate,
      paymentAccountId: invoice.paymentAccountId,
      paymentAccountName: account?.name,
      paidAt: invoice.paidAt,
      cardColor: _parseColor(card.color),
      transactions: [
        for (final transaction in transactions)
          _mapInvoiceTransaction(
            transaction,
            categoriesById: categoriesById,
            subcategoriesById: subcategoriesById,
            ratesToBrl: ratesToBrl,
          ),
      ],
    );
  }

  List<CreditCardInvoicePreview> _mapInvoicePreviews({
    required Map<int, CreditCard> cardsById,
    required Map<int, Account> accountsById,
    required Map<int, CategoryModel> categoriesById,
    required Map<int, SubcategoryModel> subcategoriesById,
    required Map<String, double> ratesToBrl,
  }) {
    final mappedKeys = <String>{};
    final previews = <CreditCardInvoicePreview>[];

    for (final invoice in _invoices) {
      final card = cardsById[invoice.creditCardId];
      if (card == null) {
        continue;
      }

      mappedKeys.add(
        _invoiceKey(
          cardId: invoice.creditCardId,
          month: invoice.month,
          year: invoice.year,
        ),
      );
      previews.add(
        _mapInvoice(
          invoice,
          card: card,
          accountsById: accountsById,
          categoriesById: categoriesById,
          subcategoriesById: subcategoriesById,
          ratesToBrl: ratesToBrl,
        ),
      );
    }

    for (final transaction in _transactions) {
      final creditCardId = transaction.creditCardId;
      if (transaction.paymentMethod != 'credit_card' ||
          creditCardId == null ||
          cardsById[creditCardId] == null) {
        continue;
      }

      final invoiceMonth = transaction.invoiceMonth ?? transaction.date.month;
      final invoiceYear = transaction.invoiceYear ?? transaction.date.year;
      final key = _invoiceKey(
        cardId: creditCardId,
        month: invoiceMonth,
        year: invoiceYear,
      );
      if (!mappedKeys.add(key)) {
        continue;
      }

      previews.add(
        _mapSyntheticInvoice(
          card: cardsById[creditCardId]!,
          month: invoiceMonth,
          year: invoiceYear,
          accountsById: accountsById,
          categoriesById: categoriesById,
          subcategoriesById: subcategoriesById,
          ratesToBrl: ratesToBrl,
        ),
      );
    }

    previews.sort((a, b) {
      final yearComparison = b.year.compareTo(a.year);
      if (yearComparison != 0) {
        return yearComparison;
      }
      return b.month.compareTo(a.month);
    });
    return previews;
  }

  CreditCardInvoicePreview _mapSyntheticInvoice({
    required CreditCard card,
    required int month,
    required int year,
    required Map<int, Account> accountsById,
    required Map<int, CategoryModel> categoriesById,
    required Map<int, SubcategoryModel> subcategoriesById,
    required Map<String, double> ratesToBrl,
  }) {
    final transactions = _creditCardTransactionsFor(
      cardId: card.id,
      month: month,
      year: year,
    );
    final amount = transactions
        .fold<int>(
          0,
          (total, transaction) => total + _invoiceAmountDelta(transaction),
        )
        .clamp(0, 1 << 31)
        .toInt();
    final status = _isInvoiceClosed(
      month: month,
      year: year,
      closingDay: card.closingDay,
    )
        ? 'closed'
        : 'open';
    final paymentAccount = accountsById[card.defaultPaymentAccountId];
    final currencyCode = paymentAccount?.currencyCode ?? 'BRL';

    return CreditCardInvoicePreview(
      id: 0,
      cardId: card.id,
      cardName: card.name,
      cardLastDigits: card.lastDigits,
      month: month,
      year: year,
      amountCents: amount,
      currencyCode: currencyCode,
      displayAmountCents: _convertCents(
        amountCents: amount,
        fromCurrency: currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      status: status,
      statusLabel: _invoiceStatusLabel(status),
      dueDate: DateTime(year, month, _safeDay(year, month, card.dueDay)),
      paymentAccountId: card.defaultPaymentAccountId,
      paymentAccountName: paymentAccount?.name,
      cardColor: _parseColor(card.color),
      transactions: [
        for (final transaction in transactions)
          _mapInvoiceTransaction(
            transaction,
            categoriesById: categoriesById,
            subcategoriesById: subcategoriesById,
            ratesToBrl: ratesToBrl,
          ),
      ],
    );
  }

  List<FinanceTransaction> _creditCardTransactionsFor({
    required int cardId,
    required int month,
    required int year,
  }) {
    return _transactions
        .where(
          (transaction) =>
              transaction.paymentMethod == 'credit_card' &&
              transaction.creditCardId == cardId &&
              (transaction.invoiceMonth ?? transaction.date.month) == month &&
              (transaction.invoiceYear ?? transaction.date.year) == year,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  CreditCardInvoiceTransactionPreview _mapInvoiceTransaction(
    FinanceTransaction transaction, {
    required Map<int, CategoryModel> categoriesById,
    required Map<int, SubcategoryModel> subcategoriesById,
    required Map<String, double> ratesToBrl,
  }) {
    return CreditCardInvoiceTransactionPreview(
      id: transaction.id,
      description: transaction.description,
      amountCents: transaction.amount,
      currencyCode: transaction.currencyCode,
      displayAmountCents: _convertCents(
        amountCents: transaction.amount,
        fromCurrency: transaction.currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      date: transaction.date,
      categoryId: transaction.categoryId,
      categoryName: categoriesById[transaction.categoryId]?.name ?? 'Categoria',
      type: transaction.type,
      subcategoryId: transaction.subcategoryId,
      subcategoryName: transaction.subcategoryId == null
          ? null
          : subcategoriesById[transaction.subcategoryId]?.name,
      entryKind: transaction.expenseKind,
      installmentNumber: transaction.installmentNumber,
      totalInstallments: transaction.totalInstallments,
    );
  }

  int _invoiceAmountDelta(FinanceTransaction transaction) {
    return transaction.type == 'income'
        ? -transaction.amount
        : transaction.amount;
  }

  String _invoiceKey({
    required int cardId,
    required int month,
    required int year,
  }) {
    return '$cardId-$year-$month';
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

  String _invoiceStatusLabel(String status) {
    return switch (status) {
      'closed' => 'Fechada',
      'paid' => 'Paga',
      _ => 'Aberta',
    };
  }

  bool _isInvoiceClosed({
    required int month,
    required int year,
    required int closingDay,
  }) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final closingDate = DateTime(year, month, closingDay.clamp(1, lastDay));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(closingDate);
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  int _convertCents({
    required int amountCents,
    required String fromCurrency,
    required Map<String, double> ratesToBrl,
  }) {
    return _exchangeRateService.convertCentsWithRates(
      amountCents: amountCents,
      fromCurrency: fromCurrency,
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _cardsSubscription?.cancel();
    _invoicesSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final cardsViewModelProvider =
    StateNotifierProvider<CardsViewModel, CardsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return CardsViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
  );
});
