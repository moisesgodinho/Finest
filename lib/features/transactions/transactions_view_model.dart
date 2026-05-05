import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/currency/exchange_rate_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/create_transaction_request.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/transaction_series_scope.dart';
import '../../data/models/update_transaction_request.dart';
import '../../data/models/update_transfer_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transfer_repository.dart';

const _unset = Object();

class TransactionFilters {
  const TransactionFilters._();

  static const all = 'all';
  static const income = 'income';
  static const expense = 'expense';
  static const creditCard = 'credit_card';
  static const transfer = 'transfer';
  static const pending = 'pending';
}

class TransactionListItem {
  const TransactionListItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.accountName,
    required this.categoryName,
    required this.amountCents,
    required this.currencyCode,
    required this.date,
    required this.monthReference,
    required this.dueDate,
    required this.type,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.isPaid,
    required this.icon,
    required this.iconColor,
    this.accountId,
    this.categoryId,
    this.subcategoryId,
    this.subcategoryName,
    this.creditCardId,
    this.creditCardName,
    this.fromAccountId,
    this.toAccountId,
    this.toAccountName,
    this.invoiceMonth,
    this.invoiceYear,
    this.kindCode,
    this.kindLabel,
    this.installmentNumber,
    this.totalInstallments,
    this.consolidatedAmountCents,
  });

  final int id;
  final TransactionEntryKind kind;
  final String title;
  final int? accountId;
  final String accountName;
  final int? categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final int? creditCardId;
  final String? creditCardName;
  final int? fromAccountId;
  final int? toAccountId;
  final String? toAccountName;
  final int amountCents;
  final String currencyCode;
  final int? consolidatedAmountCents;
  final DateTime date;
  final DateTime monthReference;
  final DateTime? dueDate;
  final String type;
  final String paymentMethod;
  final String paymentMethodLabel;
  final bool isPaid;
  final IconData icon;
  final Color iconColor;
  final int? invoiceMonth;
  final int? invoiceYear;
  final String? kindCode;
  final String? kindLabel;
  final int? installmentNumber;
  final int? totalInstallments;

  bool get isIncome => type == TransactionFilters.income;
  bool get isExpense => type == TransactionFilters.expense;
  bool get isTransfer => kind == TransactionEntryKind.transfer;
  bool get isCreditCard => paymentMethod == TransactionFilters.creditCard;
  bool get isInstallmentSeries =>
      kindCode == 'installment' &&
      (installmentNumber ?? 0) > 0 &&
      (totalInstallments ?? 0) > 1;
  bool get supportsSeriesScope => isInstallmentSeries;
  int get summaryAmountCents => consolidatedAmountCents ?? amountCents;
}

enum TransactionEntryKind {
  transaction,
  transfer,
}

class TransactionFilterOption {
  const TransactionFilterOption({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;
}

class TransactionSummary {
  const TransactionSummary({
    this.incomeCents = 0,
    this.accountExpenseCents = 0,
    this.cardExpenseCents = 0,
    this.pendingCents = 0,
    this.transferCents = 0,
  });

  final int incomeCents;
  final int accountExpenseCents;
  final int cardExpenseCents;
  final int pendingCents;
  final int transferCents;

  int get totalExpenseCents => accountExpenseCents + cardExpenseCents;
  int get netCents => incomeCents - totalExpenseCents;
}

class TransactionDayGroup {
  const TransactionDayGroup({
    required this.date,
    required this.items,
  });

  final DateTime date;
  final List<TransactionListItem> items;
}

class TransactionsState {
  const TransactionsState({
    required this.selectedMonth,
    this.selectedType = TransactionFilters.all,
    this.selectedAccountId,
    this.selectedCategoryId,
    this.selectedCreditCardId,
    this.searchQuery = '',
    this.currencyCode = 'BRL',
    this.transactions = const [],
    this.accounts = const [],
    this.categories = const [],
    this.subcategories = const [],
    this.creditCards = const [],
    this.summary = const TransactionSummary(),
    this.isLoading = false,
    this.errorMessage,
  });

  factory TransactionsState.initial() {
    final now = DateTime.now();
    return TransactionsState(
      selectedMonth: DateTime(now.year, now.month),
      isLoading: true,
    );
  }

  final DateTime selectedMonth;
  final String selectedType;
  final int? selectedAccountId;
  final int? selectedCategoryId;
  final int? selectedCreditCardId;
  final String searchQuery;
  final String currencyCode;
  final List<TransactionListItem> transactions;
  final List<AccountPreview> accounts;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final List<TransactionFilterOption> creditCards;
  final TransactionSummary summary;
  final bool isLoading;
  final String? errorMessage;

  String get monthLabel => AppDateUtils.monthYearLabel(selectedMonth);

  List<TransactionListItem> get monthTransactions {
    return transactions
        .where((transaction) => _isSameMonth(
              transaction.monthReference,
              selectedMonth,
            ))
        .toList();
  }

  List<TransactionListItem> get filteredTransactions {
    final normalizedSearch = _normalize(searchQuery);

    return monthTransactions.where((transaction) {
      if (!_matchesType(transaction)) {
        return false;
      }
      if (!_matchesAccount(transaction)) {
        return false;
      }
      if (selectedCategoryId != null &&
          transaction.categoryId != selectedCategoryId) {
        return false;
      }
      if (selectedCreditCardId != null &&
          transaction.creditCardId != selectedCreditCardId) {
        return false;
      }
      if (normalizedSearch.isEmpty) {
        return true;
      }

      final haystack = _normalize(
        [
          transaction.title,
          transaction.accountName,
          transaction.toAccountName,
          transaction.categoryName,
          transaction.subcategoryName,
          transaction.creditCardName,
          transaction.paymentMethodLabel,
        ].whereType<String>().join(' '),
      );

      return haystack.contains(normalizedSearch);
    }).toList();
  }

  List<TransactionDayGroup> get groupedTransactions {
    final groups = <DateTime, List<TransactionListItem>>{};
    for (final transaction in filteredTransactions) {
      final key = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      groups.putIfAbsent(key, () => []).add(transaction);
    }

    return [
      for (final entry in groups.entries)
        TransactionDayGroup(date: entry.key, items: entry.value),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  List<CategoryModel> get filterCategories {
    if (selectedType == TransactionFilters.income) {
      return categories
          .where((category) => category.type == TransactionFilters.income)
          .toList();
    }
    if (selectedType == TransactionFilters.expense ||
        selectedType == TransactionFilters.creditCard) {
      return categories
          .where((category) => category.type == TransactionFilters.expense)
          .toList();
    }
    return categories;
  }

  bool get hasActiveFilters {
    return selectedType != TransactionFilters.all ||
        selectedAccountId != null ||
        selectedCategoryId != null ||
        selectedCreditCardId != null ||
        searchQuery.trim().isNotEmpty;
  }

  TransactionsState copyWith({
    DateTime? selectedMonth,
    String? selectedType,
    Object? selectedAccountId = _unset,
    Object? selectedCategoryId = _unset,
    Object? selectedCreditCardId = _unset,
    String? searchQuery,
    String? currencyCode,
    List<TransactionListItem>? transactions,
    List<AccountPreview>? accounts,
    List<CategoryModel>? categories,
    List<SubcategoryModel>? subcategories,
    List<TransactionFilterOption>? creditCards,
    TransactionSummary? summary,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransactionsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedType: selectedType ?? this.selectedType,
      selectedAccountId: identical(selectedAccountId, _unset)
          ? this.selectedAccountId
          : selectedAccountId as int?,
      selectedCategoryId: identical(selectedCategoryId, _unset)
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      selectedCreditCardId: identical(selectedCreditCardId, _unset)
          ? this.selectedCreditCardId
          : selectedCreditCardId as int?,
      searchQuery: searchQuery ?? this.searchQuery,
      currencyCode: currencyCode ?? this.currencyCode,
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      creditCards: creditCards ?? this.creditCards,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool _matchesType(TransactionListItem transaction) {
    return switch (selectedType) {
      TransactionFilters.income => transaction.isIncome,
      TransactionFilters.expense =>
        transaction.isExpense && !transaction.isCreditCard,
      TransactionFilters.creditCard => transaction.isCreditCard,
      TransactionFilters.transfer => transaction.isTransfer,
      TransactionFilters.pending => !transaction.isPaid,
      _ => true,
    };
  }

  bool _matchesAccount(TransactionListItem transaction) {
    final selected = selectedAccountId;
    if (selected == null) {
      return true;
    }
    if (transaction.isTransfer) {
      return transaction.fromAccountId == selected ||
          transaction.toAccountId == selected;
    }
    return transaction.accountId == selected;
  }

  static bool _isSameMonth(DateTime left, DateTime right) {
    return left.month == right.month && left.year == right.year;
  }
}

class TransactionsViewModel extends StateNotifier<TransactionsState> {
  TransactionsViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required TransactionRepository transactionRepository,
    required TransferRepository transferRepository,
    required ExchangeRateService exchangeRateService,
    required String currencyCode,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _creditCardRepository = creditCardRepository,
        _transactionRepository = transactionRepository,
        _transferRepository = transferRepository,
        _exchangeRateService = exchangeRateService,
        _currencyCode = currencyCode,
        super(TransactionsState.initial()) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final TransactionRepository _transactionRepository;
  final TransferRepository _transferRepository;
  final ExchangeRateService _exchangeRateService;
  final String _currencyCode;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<SubcategoryModel>>? _subcategoriesSubscription;
  StreamSubscription<List<CreditCard>>? _creditCardsSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  StreamSubscription<List<AccountTransfer>>? _transfersSubscription;
  List<Account> _rawAccounts = [];
  List<CategoryModel> _rawCategories = [];
  List<SubcategoryModel> _rawSubcategories = [];
  List<CreditCard> _rawCreditCards = [];
  List<FinanceTransaction> _rawTransactions = [];
  List<AccountTransfer> _rawTransfers = [];

  void selectType(String type) {
    state = state.copyWith(
      selectedType: type,
      selectedCategoryId: null,
      selectedCreditCardId: type == TransactionFilters.creditCard
          ? state.selectedCreditCardId
          : null,
    );
  }

  void selectPreviousMonth() {
    final month = state.selectedMonth;
    state =
        state.copyWith(selectedMonth: DateTime(month.year, month.month - 1));
    _publishState();
  }

  void selectNextMonth() {
    final month = state.selectedMonth;
    state =
        state.copyWith(selectedMonth: DateTime(month.year, month.month + 1));
    _publishState();
  }

  void selectMonth(DateTime month) {
    state = state.copyWith(selectedMonth: DateTime(month.year, month.month));
    _publishState();
  }

  void selectAccount(int? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  void selectCategory(int? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void selectCreditCard(int? creditCardId) {
    state = state.copyWith(selectedCreditCardId: creditCardId);
  }

  void search(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void clearFilters() {
    state = state.copyWith(
      selectedType: TransactionFilters.all,
      selectedAccountId: null,
      selectedCategoryId: null,
      selectedCreditCardId: null,
      searchQuery: '',
    );
  }

  Future<void> createTransaction({
    required int accountId,
    required int categoryId,
    required String type,
    required String description,
    required int amountCents,
    required DateTime dueDate,
    required DateTime date,
    required bool isPaid,
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
          dueDate: dueDate,
          date: date,
          isPaid: isPaid,
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

  Future<void> markItemAsPaid(TransactionListItem transaction) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (transaction.isTransfer) {
        await _transferRepository.markTransferAsPaid(
          userId: userId,
          transferId: transaction.id,
        );
      } else {
        await _transactionRepository.markTransactionAsPaid(
          userId: userId,
          transactionId: transaction.id,
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

  Future<void> updateTransaction({
    required TransactionListItem transaction,
    required int accountId,
    required int categoryId,
    required String type,
    required String description,
    required int amountCents,
    required DateTime? dueDate,
    required DateTime date,
    required bool isPaid,
    int? subcategoryId,
    String? transactionKind,
    int? totalInstallments,
    TransactionSeriesScope scope = TransactionSeriesScope.current,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final targets = _transactionTargetsFor(transaction, scope);
      final useInstallmentSuffix = targets.any(
        (target) => _hasInstallmentSuffix(target.description),
      );

      for (final target in targets) {
        final keepsInstallments = transactionKind == 'installment';
        final effectiveInstallmentNumber =
            keepsInstallments ? target.installmentNumber : null;
        final effectiveTotalInstallments = keepsInstallments
            ? totalInstallments ?? target.totalInstallments
            : null;

        await _transactionRepository.updateTransaction(
          UpdateTransactionRequest(
            userId: userId,
            transactionId: target.id,
            accountId: accountId,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            type: type,
            description: _seriesDescription(
              description,
              installmentNumber: effectiveInstallmentNumber,
              totalInstallments: effectiveTotalInstallments,
              useSuffix: keepsInstallments && useInstallmentSuffix,
            ),
            amountCents: amountCents,
            date: _shiftDateForSeries(
              date,
              selectedInstallment: transaction.installmentNumber,
              targetInstallment: effectiveInstallmentNumber,
            ),
            dueDate: dueDate == null
                ? null
                : _shiftDateForSeries(
                    dueDate,
                    selectedInstallment: transaction.installmentNumber,
                    targetInstallment: effectiveInstallmentNumber,
                  ),
            transactionKind: transactionKind,
            installmentNumber: effectiveInstallmentNumber,
            totalInstallments: effectiveTotalInstallments,
            isPaid: isPaid,
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

  Future<void> updateTransfer({
    required TransactionListItem transfer,
    required int fromAccountId,
    required int toAccountId,
    required String name,
    required int amountCents,
    required String transferKind,
    required DateTime dueDate,
    required bool isPaid,
    required DateTime date,
    int? totalInstallments,
    TransactionSeriesScope scope = TransactionSeriesScope.current,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final targets = _transferTargetsFor(transfer, scope);
      final useInstallmentSuffix = targets.any(
        (target) => _hasInstallmentSuffix(target.name),
      );

      for (final target in targets) {
        final keepsInstallments = transferKind == 'installment';
        final effectiveInstallmentNumber =
            keepsInstallments ? target.installmentNumber : null;
        final effectiveTotalInstallments = keepsInstallments
            ? totalInstallments ?? target.totalInstallments
            : null;

        await _transferRepository.updateTransfer(
          UpdateTransferRequest(
            userId: userId,
            transferId: target.id,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            name: _seriesDescription(
              name,
              installmentNumber: effectiveInstallmentNumber,
              totalInstallments: effectiveTotalInstallments,
              useSuffix: keepsInstallments && useInstallmentSuffix,
            ),
            amountCents: amountCents,
            toAmountCents: amountCents,
            transferKind: transferKind,
            dueDate: _shiftDateForSeries(
              dueDate,
              selectedInstallment: transfer.installmentNumber,
              targetInstallment: effectiveInstallmentNumber,
            ),
            isPaid: isPaid,
            date: _shiftDateForSeries(
              date,
              selectedInstallment: transfer.installmentNumber,
              targetInstallment: effectiveInstallmentNumber,
            ),
            installmentNumber: effectiveInstallmentNumber,
            totalInstallments: effectiveTotalInstallments,
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

  Future<void> deleteItem(
    TransactionListItem transaction, {
    TransactionSeriesScope scope = TransactionSeriesScope.current,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (transaction.isTransfer) {
        final targets = _transferTargetsFor(transaction, scope);
        for (final target in targets) {
          await _transferRepository.deleteTransfer(
            userId: userId,
            transferId: target.id,
          );
        }
      } else {
        final targets = _transactionTargetsFor(transaction, scope);
        for (final target in targets) {
          await _transactionRepository.deleteTransaction(
            userId: userId,
            transactionId: target.id,
          );
        }
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  List<FinanceTransaction> _transactionTargetsFor(
    TransactionListItem selected,
    TransactionSeriesScope scope,
  ) {
    final selectedRaw = _rawTransactions
        .where((transaction) => transaction.id == selected.id)
        .firstOrNull;
    if (selectedRaw == null) {
      return const [];
    }
    if (scope == TransactionSeriesScope.current ||
        !selected.supportsSeriesScope) {
      return [selectedRaw];
    }

    final matches = _rawTransactions
        .where((transaction) =>
            _matchesTransactionSeries(transaction, selectedRaw))
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

  List<AccountTransfer> _transferTargetsFor(
    TransactionListItem selected,
    TransactionSeriesScope scope,
  ) {
    final selectedRaw = _rawTransfers
        .where((transfer) => transfer.id == selected.id)
        .firstOrNull;
    if (selectedRaw == null) {
      return const [];
    }
    if (scope == TransactionSeriesScope.current ||
        !selected.supportsSeriesScope) {
      return [selectedRaw];
    }

    final matches = _rawTransfers
        .where((transfer) => _matchesTransferSeries(transfer, selectedRaw))
        .where(
          (transfer) => _matchesInstallmentScope(
            targetInstallment: transfer.installmentNumber,
            selectedInstallment: selectedRaw.installmentNumber,
            scope: scope,
          ),
        )
        .toList()
      ..sort(_compareInstallmentTransfers);

    return matches.isEmpty ? [selectedRaw] : matches;
  }

  bool _matchesTransactionSeries(
    FinanceTransaction candidate,
    FinanceTransaction selected,
  ) {
    return candidate.userId == selected.userId &&
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

  bool _matchesTransferSeries(
    AccountTransfer candidate,
    AccountTransfer selected,
  ) {
    return candidate.userId == selected.userId &&
        candidate.fromAccountId == selected.fromAccountId &&
        candidate.toAccountId == selected.toAccountId &&
        candidate.transferKind == selected.transferKind &&
        candidate.totalInstallments == selected.totalInstallments &&
        _seriesBaseName(candidate.name) == _seriesBaseName(selected.name);
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
    return left.date.compareTo(right.date);
  }

  int _compareInstallmentTransfers(
    AccountTransfer left,
    AccountTransfer right,
  ) {
    final installmentCompare =
        (left.installmentNumber ?? 0).compareTo(right.installmentNumber ?? 0);
    if (installmentCompare != 0) {
      return installmentCompare;
    }
    return left.date.compareTo(right.date);
  }

  DateTime _shiftDateForSeries(
    DateTime date, {
    required int? selectedInstallment,
    required int? targetInstallment,
  }) {
    final selected = selectedInstallment ?? targetInstallment ?? 1;
    final target = targetInstallment ?? selected;
    return _addMonths(date, target - selected);
  }

  DateTime _addMonths(DateTime date, int months) {
    if (months == 0) {
      return date;
    }

    final firstDayOfTargetMonth = DateTime(date.year, date.month + months);
    final lastDayOfTargetMonth = DateTime(
      firstDayOfTargetMonth.year,
      firstDayOfTargetMonth.month + 1,
      0,
    ).day;
    final day = date.day.clamp(1, lastDayOfTargetMonth).toInt();

    return DateTime(
      firstDayOfTargetMonth.year,
      firstDayOfTargetMonth.month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
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
      state = TransactionsState(
        selectedMonth: state.selectedMonth,
      );
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

    _subcategoriesSubscription =
        _categoryRepository.watchSubcategories(userId).listen(
      (subcategories) {
        _rawSubcategories = subcategories;
        _publishState();
      },
      onError: _publishError,
    );

    _creditCardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (creditCards) {
        _rawCreditCards = creditCards;
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

    _transfersSubscription = _transferRepository.watchTransfers(userId).listen(
      (transfers) {
        _rawTransfers = transfers;
        _publishState();
      },
      onError: _publishError,
    );
  }

  Future<void> _publishState() async {
    final ratesToBrl = await _exchangeRateService.ratesToBrlSnapshot();
    final accounts = _rawAccounts.map(_mapAccount).toList();
    final accountNames = {
      for (final account in _rawAccounts) account.id: account.name,
    };
    final categoryMap = {
      for (final category in _rawCategories) category.id: category,
    };
    final subcategoryMap = {
      for (final subcategory in _rawSubcategories) subcategory.id: subcategory,
    };
    final creditCardMap = {
      for (final card in _rawCreditCards) card.id: card,
    };

    final entries = [
      for (final transaction in _rawTransactions)
        _mapTransaction(
          transaction,
          accountNames: accountNames,
          categoryMap: categoryMap,
          subcategoryMap: subcategoryMap,
          creditCardMap: creditCardMap,
          ratesToBrl: ratesToBrl,
        ),
      for (final transfer in _rawTransfers)
        _mapTransfer(
          transfer,
          accountNames: accountNames,
          ratesToBrl: ratesToBrl,
        ),
    ]..sort((a, b) {
        final monthCompare = b.monthReference.compareTo(a.monthReference);
        if (monthCompare != 0) {
          return monthCompare;
        }
        return b.date.compareTo(a.date);
      });

    final normalizedCreditCardId = _rawCreditCards.any(
      (card) => card.id == state.selectedCreditCardId,
    )
        ? state.selectedCreditCardId
        : null;
    final normalizedCategoryId = _rawCategories.any(
      (category) => category.id == state.selectedCategoryId,
    )
        ? state.selectedCategoryId
        : null;
    final normalizedAccountId = _rawAccounts.any(
      (account) => account.id == state.selectedAccountId,
    )
        ? state.selectedAccountId
        : null;

    state = state.copyWith(
      selectedAccountId: normalizedAccountId,
      selectedCategoryId: normalizedCategoryId,
      selectedCreditCardId: normalizedCreditCardId,
      accounts: accounts,
      categories: _rawCategories,
      subcategories: _rawSubcategories,
      currencyCode: _currencyCode,
      creditCards: [
        for (final card in _rawCreditCards)
          TransactionFilterOption(
            id: card.id,
            label: '${card.name} •••• ${card.lastDigits}',
          ),
      ],
      transactions: entries,
      summary: _buildSummary(entries),
      isLoading: false,
      clearError: true,
    );
  }

  TransactionSummary _buildSummary(List<TransactionListItem> entries) {
    var incomeCents = 0;
    var accountExpenseCents = 0;
    var cardExpenseCents = 0;
    var pendingCents = 0;
    var transferCents = 0;

    for (final entry in entries) {
      if (!_isSameMonth(entry.monthReference, state.selectedMonth)) {
        continue;
      }

      if (!entry.isPaid) {
        pendingCents += entry.summaryAmountCents;
        continue;
      }

      if (entry.isTransfer) {
        transferCents += entry.summaryAmountCents;
      } else if (entry.isCreditCard) {
        cardExpenseCents += entry.isIncome
            ? -entry.summaryAmountCents
            : entry.summaryAmountCents;
      } else if (entry.isIncome) {
        incomeCents += entry.summaryAmountCents;
      } else {
        accountExpenseCents += entry.summaryAmountCents;
      }
    }

    return TransactionSummary(
      incomeCents: incomeCents,
      accountExpenseCents: accountExpenseCents,
      cardExpenseCents: cardExpenseCents,
      pendingCents: pendingCents,
      transferCents: transferCents,
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
    required Map<int, SubcategoryModel> subcategoryMap,
    required Map<int, CreditCard> creditCardMap,
    required Map<String, double> ratesToBrl,
  }) {
    final category = categoryMap[transaction.categoryId];
    final subcategory = subcategoryMap[transaction.subcategoryId];
    final creditCard = creditCardMap[transaction.creditCardId];
    final isCreditCard =
        transaction.paymentMethod == TransactionFilters.creditCard;
    final monthReference = isCreditCard &&
            transaction.invoiceMonth != null &&
            transaction.invoiceYear != null
        ? DateTime(transaction.invoiceYear!, transaction.invoiceMonth!)
        : DateTime(transaction.date.year, transaction.date.month);

    return TransactionListItem(
      id: transaction.id,
      kind: TransactionEntryKind.transaction,
      title: transaction.description,
      accountId: transaction.accountId,
      accountName: accountNames[transaction.accountId] ?? 'Conta removida',
      categoryId: transaction.categoryId,
      categoryName: category?.name ?? 'Sem categoria',
      subcategoryId: transaction.subcategoryId,
      subcategoryName: subcategory?.name,
      creditCardId: transaction.creditCardId,
      creditCardName: creditCard == null
          ? null
          : '${creditCard.name} •••• ${creditCard.lastDigits}',
      amountCents: transaction.amount,
      currencyCode: transaction.currencyCode,
      consolidatedAmountCents: _convertCents(
        amountCents: transaction.amount,
        fromCurrency: transaction.currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      date: transaction.date,
      monthReference: monthReference,
      dueDate: transaction.dueDate,
      type: transaction.type,
      paymentMethod: transaction.paymentMethod,
      paymentMethodLabel: isCreditCard ? 'Cartão' : 'Conta',
      isPaid: transaction.isPaid,
      icon: category?.icon ?? Icons.category_rounded,
      iconColor: category?.color ?? AppColors.primary,
      invoiceMonth: transaction.invoiceMonth,
      invoiceYear: transaction.invoiceYear,
      kindCode: transaction.expenseKind,
      kindLabel: _kindLabel(transaction.expenseKind),
      installmentNumber: transaction.installmentNumber,
      totalInstallments: transaction.totalInstallments,
    );
  }

  TransactionListItem _mapTransfer(
    AccountTransfer transfer, {
    required Map<int, String> accountNames,
    required Map<String, double> ratesToBrl,
  }) {
    return TransactionListItem(
      id: transfer.id,
      kind: TransactionEntryKind.transfer,
      title: transfer.name,
      accountName: accountNames[transfer.fromAccountId] ?? 'Conta removida',
      fromAccountId: transfer.fromAccountId,
      toAccountId: transfer.toAccountId,
      toAccountName: accountNames[transfer.toAccountId] ?? 'Conta removida',
      categoryName: 'Transferência',
      amountCents: transfer.amount,
      currencyCode: transfer.fromCurrencyCode,
      consolidatedAmountCents: _convertCents(
        amountCents: transfer.amount,
        fromCurrency: transfer.fromCurrencyCode,
        ratesToBrl: ratesToBrl,
      ),
      date: transfer.date,
      monthReference: DateTime(transfer.date.year, transfer.date.month),
      dueDate: transfer.dueDate,
      type: TransactionFilters.transfer,
      paymentMethod: TransactionFilters.transfer,
      paymentMethodLabel: 'Transferência',
      isPaid: transfer.isPaid,
      icon: Icons.swap_horiz_rounded,
      iconColor: AppColors.info,
      kindCode: transfer.transferKind,
      kindLabel: _kindLabel(transfer.transferKind),
      installmentNumber: transfer.installmentNumber,
      totalInstallments: transfer.totalInstallments,
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
      currencyCode: account.currencyCode,
      includeInTotalBalance: account.includeInTotalBalance,
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  String? _kindLabel(String? value) {
    return switch (value) {
      'single' => 'Única',
      'installment' => 'Parcelada',
      'fixed_monthly' => 'Fixa mensal',
      'refund' => 'Estorno',
      'cashback' => 'Cashback',
      _ => null,
    };
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

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  bool _isSameMonth(DateTime left, DateTime right) {
    return left.month == right.month && left.year == right.year;
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    _creditCardsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _transfersSubscription?.cancel();
    super.dispose();
  }
}

String _normalize(String value) {
  return value.trim().toLowerCase();
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
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
  );
});
