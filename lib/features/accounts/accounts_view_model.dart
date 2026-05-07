import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/currency/exchange_rate_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_account_request.dart';
import '../../data/models/create_transaction_request.dart';
import '../../data/models/update_account_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transfer_repository.dart';

class AccountsState {
  const AccountsState({
    required this.accounts,
    required this.currencyCode,
    required this.selectedMonth,
    required this.firstAvailableMonth,
    this.totalBalanceCents = 0,
    this.totalInitialBalanceCents = 0,
    this.totalIncomeCents = 0,
    this.totalExpenseCents = 0,
    this.totalYieldCents = 0,
    this.monthlyExpenseAverageCents = 0,
    this.suggestedEmergencyReserveCents = 0,
    this.isBalanceVisible = true,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AccountPreview> accounts;
  final String currencyCode;
  final DateTime selectedMonth;
  final DateTime firstAvailableMonth;
  final int totalBalanceCents;
  final int totalInitialBalanceCents;
  final int totalIncomeCents;
  final int totalExpenseCents;
  final int totalYieldCents;
  final int monthlyExpenseAverageCents;
  final int suggestedEmergencyReserveCents;
  final bool isBalanceVisible;
  final bool isLoading;
  final String? errorMessage;

  int get emergencyReserveBalanceCents {
    return emergencyReserveAccount?.balanceCents ?? 0;
  }

  AccountPreview? get emergencyReserveAccount {
    for (final account in accounts) {
      if (!account.isGoal && account.emergencyReserveTargetCents != null) {
        return account;
      }
    }

    for (final account in accounts) {
      if (!account.isGoal && account.isEmergencyReserve) {
        return account;
      }
    }

    return null;
  }

  int get emergencyReserveTargetCents {
    return emergencyReserveAccount?.emergencyReserveTargetCents ??
        suggestedEmergencyReserveCents;
  }

  double get emergencyReserveProgress {
    final targetCents = emergencyReserveTargetCents;
    if (targetCents <= 0) {
      return 0;
    }

    return (emergencyReserveBalanceCents / targetCents)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool get hasEmergencyReserveSuggestion {
    return suggestedEmergencyReserveCents > 0 && monthlyExpenseAverageCents > 0;
  }

  bool get canGoToPreviousMonth {
    return _isAfterMonth(selectedMonth, firstAvailableMonth);
  }

  AccountsState copyWith({
    List<AccountPreview>? accounts,
    String? currencyCode,
    DateTime? selectedMonth,
    DateTime? firstAvailableMonth,
    int? totalBalanceCents,
    int? totalInitialBalanceCents,
    int? totalIncomeCents,
    int? totalExpenseCents,
    int? totalYieldCents,
    int? monthlyExpenseAverageCents,
    int? suggestedEmergencyReserveCents,
    bool? isBalanceVisible,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      currencyCode: currencyCode ?? this.currencyCode,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      firstAvailableMonth: firstAvailableMonth ?? this.firstAvailableMonth,
      totalBalanceCents: totalBalanceCents ?? this.totalBalanceCents,
      totalInitialBalanceCents:
          totalInitialBalanceCents ?? this.totalInitialBalanceCents,
      totalIncomeCents: totalIncomeCents ?? this.totalIncomeCents,
      totalExpenseCents: totalExpenseCents ?? this.totalExpenseCents,
      totalYieldCents: totalYieldCents ?? this.totalYieldCents,
      monthlyExpenseAverageCents:
          monthlyExpenseAverageCents ?? this.monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          suggestedEmergencyReserveCents ?? this.suggestedEmergencyReserveCents,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AccountsViewModel extends StateNotifier<AccountsState> {
  AccountsViewModel({
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required TransactionRepository transactionRepository,
    required TransferRepository transferRepository,
    required ExchangeRateService exchangeRateService,
    required String currencyCode,
    required int? userId,
  })  : _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _creditCardRepository = creditCardRepository,
        _transactionRepository = transactionRepository,
        _transferRepository = transferRepository,
        _exchangeRateService = exchangeRateService,
        _currencyCode = currencyCode,
        _userId = userId,
        super(AccountsState(
          accounts: const [],
          currencyCode: currencyCode,
          selectedMonth: _monthOnly(DateTime.now()),
          firstAvailableMonth: _monthOnly(DateTime.now()),
          isLoading: true,
        )) {
    _watchAccounts();
    _watchTransactions();
    _watchTransfers();
    _watchInvoices();
  }

  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final TransactionRepository _transactionRepository;
  final TransferRepository _transferRepository;
  final ExchangeRateService _exchangeRateService;
  final String _currencyCode;
  final int? _userId;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  StreamSubscription<List<AccountTransfer>>? _transfersSubscription;
  StreamSubscription<List<CreditCardInvoice>>? _invoicesSubscription;
  List<AccountPreview> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  List<AccountTransfer> _transfers = [];
  List<CreditCardInvoice> _invoices = [];

  static const _yieldPaymentMethod = 'account_yield';
  static const _yieldCategoryName = 'Rendimentos';

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }

  void selectMonth(DateTime month) {
    final selectedMonth = _maxMonth(
      _monthOnly(month),
      state.firstAvailableMonth,
    );
    if (selectedMonth.year == state.selectedMonth.year &&
        selectedMonth.month == state.selectedMonth.month) {
      return;
    }

    state = state.copyWith(
      selectedMonth: selectedMonth,
      isLoading: true,
      clearError: true,
    );
    _publishState(isLoading: false, clearError: true);
  }

  void previousMonth() {
    if (!state.canGoToPreviousMonth) {
      return;
    }

    selectMonth(
      DateTime(state.selectedMonth.year, state.selectedMonth.month - 1),
    );
  }

  void nextMonth() {
    selectMonth(
      DateTime(state.selectedMonth.year, state.selectedMonth.month + 1),
    );
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required int initialBalance,
    int? emergencyReserveTarget,
    bool includeInTotalBalance = true,
    String? bankName,
    String currencyCode = 'BRL',
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.createAccount(
        CreateAccountRequest(
          userId: userId,
          name: name,
          type: type,
          bankName: bankName,
          initialBalance: initialBalance,
          currencyCode: currencyCode,
          emergencyReserveTarget: emergencyReserveTarget,
          includeInTotalBalance: includeInTotalBalance,
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

  Future<void> updateAccount({
    required AccountPreview account,
    required String name,
    required String type,
    required int balanceCents,
    int? emergencyReserveTarget,
    bool? includeInTotalBalance,
    String? bankName,
    String? currencyCode,
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final effectiveCurrencyCode = currencyCode ?? account.currencyCode;
      final hasLinkedEntries = _hasLinkedEntries(account.id);
      if (effectiveCurrencyCode.toUpperCase() !=
          account.currencyCode.toUpperCase()) {
        throw StateError('A moeda da conta não pode ser alterada.');
      }
      if (hasLinkedEntries && balanceCents != account.initialBalanceCents) {
        throw StateError(
          'Esta conta já possui lançamentos. Para ajustar o saldo, registre uma receita, despesa ou transferência.',
        );
      }

      await _accountRepository.updateAccount(
        UpdateAccountRequest(
          id: account.id,
          userId: userId,
          name: name,
          type: type,
          bankName: bankName,
          initialBalance:
              hasLinkedEntries ? account.initialBalanceCents : balanceCents,
          currentBalance:
              hasLinkedEntries ? account.currentBalanceCents : balanceCents,
          currencyCode: effectiveCurrencyCode,
          emergencyReserveTarget: emergencyReserveTarget,
          goalLinkedAccountId: account.goalLinkedAccountId,
          goalTargetDate: account.goalTargetDate,
          includeInTotalBalance:
              includeInTotalBalance ?? account.includeInTotalBalance,
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

  Future<void> deleteAccount(AccountPreview account) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (_hasLinkedEntries(account.id)) {
        throw StateError(
          'Esta conta possui lançamentos ou transferências vinculados. Remova ou mova esses registros antes de excluir a conta.',
        );
      }

      await _accountRepository.deleteAccount(
        userId: userId,
        accountId: account.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> registerAccountYield({
    required AccountPreview account,
    required int amountCents,
    required DateTime date,
    String? description,
  }) async {
    final userId = _requireUserId();
    if (amountCents <= 0) {
      throw ArgumentError('O rendimento deve ser maior que zero.');
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final categoryId = await _ensureYieldCategory(userId);
      await _transactionRepository.createTransaction(
        CreateTransactionRequest(
          userId: userId,
          accountId: account.id,
          categoryId: categoryId,
          type: 'income',
          description: description?.trim().isNotEmpty == true
              ? description!.trim()
              : 'Rendimento ${account.name}',
          amountCents: amountCents,
          date: date,
          dueDate: date,
          paymentMethod: _yieldPaymentMethod,
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

  void _watchAccounts() {
    if (_userId == null) {
      state = AccountsState(
        accounts: const [],
        currencyCode: _currencyCode,
        selectedMonth: state.selectedMonth,
        firstAvailableMonth: state.firstAvailableMonth,
      );
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(_userId).listen(
      (accounts) {
        _accounts = accounts.map(_mapAccount).toList();
        _publishState(isLoading: false, clearError: true);
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  void _watchTransactions() {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState(isLoading: false, clearError: true);
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  void _watchTransfers() {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _transfersSubscription = _transferRepository.watchTransfers(userId).listen(
      (transfers) {
        _transfers = transfers;
        _publishState(isLoading: false, clearError: true);
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  void _watchInvoices() {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _invoicesSubscription = _creditCardRepository.watchInvoices(userId).listen(
      (invoices) {
        _invoices = invoices;
        _publishState(isLoading: false, clearError: true);
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  Future<void> _publishState({
    bool? isLoading,
    bool clearError = false,
  }) async {
    if (!mounted) {
      return;
    }

    final Map<String, double> ratesToBrl;
    try {
      ratesToBrl = await _exchangeRateService.ratesToBrlSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final firstAvailableMonth = _firstAvailableMonthForAccounts();
    final selectedMonth = _maxMonth(state.selectedMonth, firstAvailableMonth);
    final useProjectedMonth = _shouldUseProjectedMonth(selectedMonth);
    final statsByAccount = _calculateMonthStats(
      selectedMonth,
      includeExpected: useProjectedMonth,
    );
    final accounts = [
      for (final account in _accounts)
        _withConsolidatedBalance(
          account,
          ratesToBrl,
          statsByAccount[account.id] ?? _AccountMonthStats.empty,
          balanceCents: useProjectedMonth
              ? _projectedBalanceForMonth(account, selectedMonth)
              : _balanceForMonth(account, selectedMonth),
          firstAvailableMonth: _firstAvailableMonthForAccount(account),
        ),
    ];
    final totalBalanceCents = accounts.fold<int>(
      0,
      (total, account) => account.includeInTotalBalance
          ? total + account.consolidatedBalanceCents
          : total,
    );
    final totalInitialBalanceCents = accounts.fold<int>(
      0,
      (total, account) => account.includeInTotalBalance
          ? total +
              _convertCentsWithRates(
                amountCents: account.initialBalanceCents,
                fromCurrency: account.currencyCode,
                ratesToBrl: ratesToBrl,
              )
          : total,
    );
    final totalIncomeCents = _sumStats(
      accounts,
      ratesToBrl,
      (account) => account.monthlyIncomeCents,
    );
    final totalExpenseCents = _sumStats(
      accounts,
      ratesToBrl,
      (account) => account.monthlyExpenseCents,
    );
    final totalYieldCents = _sumStats(
      accounts,
      ratesToBrl,
      (account) => account.monthlyYieldCents,
    );
    final monthlyExpenseAverageCents =
        _calculateMonthlyExpenseAverageCents(ratesToBrl);

    state = state.copyWith(
      accounts: accounts,
      currencyCode: _currencyCode,
      selectedMonth: selectedMonth,
      firstAvailableMonth: firstAvailableMonth,
      totalBalanceCents: totalBalanceCents,
      totalInitialBalanceCents: totalInitialBalanceCents,
      totalIncomeCents: totalIncomeCents,
      totalExpenseCents: totalExpenseCents,
      totalYieldCents: totalYieldCents,
      monthlyExpenseAverageCents: monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          _reserveTargetFor(monthlyExpenseAverageCents),
      isLoading: isLoading,
      clearError: clearError,
    );
  }

  int _calculateMonthlyExpenseAverageCents(Map<String, double> ratesToBrl) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 2);
    final end = DateTime(now.year, now.month + 1);
    final totalsByMonth = <int, int>{};

    for (final transaction in _transactions) {
      if (transaction.type != 'expense' || !transaction.isPaid) {
        continue;
      }

      final referenceDate = transaction.dueDate ?? transaction.date;
      if (referenceDate.isBefore(start) || !referenceDate.isBefore(end)) {
        continue;
      }

      final monthKey = referenceDate.year * 12 + referenceDate.month;
      totalsByMonth.update(
        monthKey,
        (value) => value + _convertTransactionAmount(transaction, ratesToBrl),
        ifAbsent: () => _convertTransactionAmount(transaction, ratesToBrl),
      );
    }

    if (totalsByMonth.isEmpty) {
      return 0;
    }

    final total =
        totalsByMonth.values.fold<int>(0, (sum, value) => sum + value);
    return (total / totalsByMonth.length).round();
  }

  int _convertTransactionAmount(
    FinanceTransaction transaction,
    Map<String, double> ratesToBrl,
  ) {
    return _convertCentsWithRates(
      amountCents: transaction.amount,
      fromCurrency: transaction.currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  int _sumStats(
    List<AccountPreview> accounts,
    Map<String, double> ratesToBrl,
    int Function(AccountPreview account) selector,
  ) {
    return accounts.fold<int>(
      0,
      (total, account) => account.includeInTotalBalance
          ? total +
              _convertCentsWithRates(
                amountCents: selector(account),
                fromCurrency: account.currencyCode,
                ratesToBrl: ratesToBrl,
              )
          : total,
    );
  }

  int _convertCentsWithRates({
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

  AccountPreview _withConsolidatedBalance(
    AccountPreview account,
    Map<String, double> ratesToBrl,
    _AccountMonthStats stats, {
    required int balanceCents,
    required DateTime firstAvailableMonth,
  }) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.lastDigits,
      initialBalanceCents: account.initialBalanceCents,
      balanceCents: balanceCents,
      currentBalanceCents: account.currentBalanceCents,
      monthlyIncomeCents: stats.incomeCents,
      monthlyExpenseCents: stats.expenseCents,
      monthlyYieldCents: stats.yieldCents,
      currencyCode: account.currencyCode,
      displayBalanceCents: _convertCentsWithRates(
        amountCents: balanceCents,
        fromCurrency: account.currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      includeInTotalBalance: account.includeInTotalBalance,
      emergencyReserveTargetCents: account.emergencyReserveTargetCents,
      goalLinkedAccountId: account.goalLinkedAccountId,
      goalTargetDate: account.goalTargetDate,
      createdAt: account.createdAt,
      firstAvailableMonth: firstAvailableMonth,
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

  bool _shouldUseProjectedMonth(DateTime month) {
    return _isAfterMonth(_monthOnly(month), _monthOnly(DateTime.now()));
  }

  Map<int, _AccountMonthStats> _calculateMonthStats(
    DateTime month, {
    required bool includeExpected,
  }) {
    final start = _monthOnly(month);
    final end = DateTime(start.year, start.month + 1);
    final statsByAccount = <int, _AccountMonthStats>{};

    for (final transaction in _transactions) {
      if (transaction.paymentMethod == 'credit_card') {
        continue;
      }

      if (!transaction.isPaid && !includeExpected) {
        continue;
      }

      final referenceDate = transaction.isPaid
          ? transaction.date
          : transaction.dueDate ?? transaction.date;
      if (referenceDate.isBefore(start) || !referenceDate.isBefore(end)) {
        continue;
      }

      final isYield = transaction.paymentMethod == _yieldPaymentMethod;
      final current =
          statsByAccount[transaction.accountId] ?? _AccountMonthStats.empty;
      statsByAccount[transaction.accountId] = current.add(
        incomeCents:
            transaction.type == 'income' && !isYield ? transaction.amount : 0,
        expenseCents: transaction.type == 'expense' ? transaction.amount : 0,
        yieldCents:
            transaction.type == 'income' && isYield ? transaction.amount : 0,
      );
    }

    if (!includeExpected) {
      return statsByAccount;
    }

    for (final invoice in _invoices) {
      final accountId = invoice.paymentAccountId;
      if (invoice.status == 'paid' ||
          invoice.amount <= 0 ||
          accountId == null ||
          !_isWithinMonth(invoice.dueDate, month)) {
        continue;
      }

      final current = statsByAccount[accountId] ?? _AccountMonthStats.empty;
      statsByAccount[accountId] = current.add(
        expenseCents: invoice.amount,
      );
    }

    return statsByAccount;
  }

  int _projectedBalanceForMonth(AccountPreview account, DateTime month) {
    final end = DateTime(month.year, month.month + 1);
    var balanceCents = _balanceForMonth(account, month);

    for (final transaction in _transactions) {
      if (transaction.isPaid ||
          transaction.accountId != account.id ||
          transaction.paymentMethod == 'credit_card') {
        continue;
      }

      final referenceDate = transaction.dueDate ?? transaction.date;
      if (!referenceDate.isBefore(end)) {
        continue;
      }

      balanceCents += transaction.type == 'income'
          ? transaction.amount
          : -transaction.amount;
    }

    for (final transfer in _transfers) {
      if (transfer.isPaid || !transfer.dueDate.isBefore(end)) {
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
      if (invoice.status == 'paid' ||
          invoice.amount <= 0 ||
          invoice.paymentAccountId != account.id ||
          !invoice.dueDate.isBefore(end)) {
        continue;
      }

      balanceCents -= invoice.amount;
    }

    return balanceCents;
  }

  Future<int> _ensureYieldCategory(int userId) async {
    final categories = await _categoryRepository.findCategoriesByType(
      userId: userId,
      type: 'income',
    );
    final normalizedName = _yieldCategoryName.toLowerCase();
    for (final category in categories) {
      if (category.name.trim().toLowerCase() == normalizedName) {
        return category.id;
      }
    }

    return _categoryRepository.createCategory(
      userId: userId,
      name: _yieldCategoryName,
      type: 'income',
      icon: 'investment',
      color: '#0A8F4D',
    );
  }

  int _reserveTargetFor(int monthlyExpenseAverageCents) {
    if (monthlyExpenseAverageCents <= 0) {
      return 0;
    }

    const roundingUnit = 10000; // R$ 100,00
    final sixMonthTarget = monthlyExpenseAverageCents * 6;
    return ((sixMonthTarget + roundingUnit - 1) ~/ roundingUnit) * roundingUnit;
  }

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  bool _hasLinkedEntries(int accountId) {
    final hasTransactions =
        _transactions.any((transaction) => transaction.accountId == accountId);
    final hasTransfers = _transfers.any(
      (transfer) =>
          transfer.fromAccountId == accountId ||
          transfer.toAccountId == accountId,
    );
    return hasTransactions || hasTransfers;
  }

  DateTime _firstAvailableMonthForAccounts() {
    if (_accounts.isEmpty) {
      return _monthOnly(DateTime.now());
    }

    var firstMonth = _firstAvailableMonthForAccount(_accounts.first);
    for (final account in _accounts.skip(1)) {
      firstMonth = _minMonth(
        firstMonth,
        _firstAvailableMonthForAccount(account),
      );
    }
    return firstMonth;
  }

  DateTime _firstAvailableMonthForAccount(AccountPreview account) {
    DateTime? firstRecordMonth = _monthOnly(
      account.createdAt ?? DateTime.now(),
    );

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

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      initialBalanceCents: account.initialBalance,
      balanceCents: account.currentBalance,
      currentBalanceCents: account.currentBalance,
      currencyCode: account.currencyCode,
      includeInTotalBalance: account.includeInTotalBalance,
      emergencyReserveTargetCents: account.emergencyReserveTarget,
      goalLinkedAccountId: account.goalLinkedAccountId,
      goalTargetDate: account.goalTargetDate,
      createdAt: account.createdAt,
      firstAvailableMonth: _monthOnly(account.createdAt),
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
    _transactionsSubscription?.cancel();
    _transfersSubscription?.cancel();
    _invoicesSubscription?.cancel();
    super.dispose();
  }
}

class _AccountMonthStats {
  const _AccountMonthStats({
    this.incomeCents = 0,
    this.expenseCents = 0,
    this.yieldCents = 0,
  });

  final int incomeCents;
  final int expenseCents;
  final int yieldCents;

  static const empty = _AccountMonthStats();

  _AccountMonthStats add({
    int incomeCents = 0,
    int expenseCents = 0,
    int yieldCents = 0,
  }) {
    return _AccountMonthStats(
      incomeCents: this.incomeCents + incomeCents,
      expenseCents: this.expenseCents + expenseCents,
      yieldCents: this.yieldCents + yieldCents,
    );
  }
}

final accountsViewModelProvider =
    StateNotifierProvider<AccountsViewModel, AccountsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return AccountsViewModel(
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
    userId: userId,
  );
});

DateTime _monthOnly(DateTime date) => DateTime(date.year, date.month);

bool _isWithinMonth(DateTime date, DateTime month) {
  final start = _monthOnly(month);
  final end = DateTime(start.year, start.month + 1);
  return !date.isBefore(start) && date.isBefore(end);
}

bool _isBeforeMonth(DateTime left, DateTime right) {
  return left.year < right.year ||
      (left.year == right.year && left.month < right.month);
}

bool _isAfterMonth(DateTime left, DateTime right) {
  return left.year > right.year ||
      (left.year == right.year && left.month > right.month);
}

DateTime _minMonth(DateTime left, DateTime right) {
  return _isBeforeMonth(left, right) ? left : right;
}

DateTime _maxMonth(DateTime left, DateTime right) {
  return _isBeforeMonth(left, right) ? right : left;
}

DateTime _minNullableMonth(DateTime? left, DateTime right) {
  return left == null ? right : _minMonth(left, right);
}
