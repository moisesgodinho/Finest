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
import '../../data/models/update_account_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transfer_repository.dart';

class AccountsState {
  const AccountsState({
    required this.accounts,
    required this.currencyCode,
    this.totalBalanceCents = 0,
    this.monthlyExpenseAverageCents = 0,
    this.suggestedEmergencyReserveCents = 0,
    this.isBalanceVisible = true,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AccountPreview> accounts;
  final String currencyCode;
  final int totalBalanceCents;
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

  AccountsState copyWith({
    List<AccountPreview>? accounts,
    String? currencyCode,
    int? totalBalanceCents,
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
      totalBalanceCents: totalBalanceCents ?? this.totalBalanceCents,
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
    required TransactionRepository transactionRepository,
    required TransferRepository transferRepository,
    required ExchangeRateService exchangeRateService,
    required String currencyCode,
    required int? userId,
  })  : _accountRepository = accountRepository,
        _transactionRepository = transactionRepository,
        _transferRepository = transferRepository,
        _exchangeRateService = exchangeRateService,
        _currencyCode = currencyCode,
        _userId = userId,
        super(AccountsState(
          accounts: const [],
          currencyCode: currencyCode,
          isLoading: true,
        )) {
    _watchAccounts();
    _watchTransactions();
    _watchTransfers();
  }

  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final TransferRepository _transferRepository;
  final ExchangeRateService _exchangeRateService;
  final String _currencyCode;
  final int? _userId;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  StreamSubscription<List<AccountTransfer>>? _transfersSubscription;
  List<AccountPreview> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  List<AccountTransfer> _transfers = [];

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
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
      if (effectiveCurrencyCode.toUpperCase() !=
          account.currencyCode.toUpperCase()) {
        throw StateError('A moeda da conta nÃ£o pode ser alterada.');
      }
      if (_hasLinkedEntries(account.id) &&
          balanceCents != account.balanceCents) {
        throw StateError(
          'Esta conta jÃ¡ possui lanÃ§amentos. Para ajustar o saldo, registre uma receita, despesa ou transferÃªncia.',
        );
      }

      await _accountRepository.updateAccount(
        UpdateAccountRequest(
          id: account.id,
          userId: userId,
          name: name,
          type: type,
          bankName: bankName,
          initialBalance: balanceCents,
          currentBalance: balanceCents,
          currencyCode: effectiveCurrencyCode,
          emergencyReserveTarget: emergencyReserveTarget,
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
          'Esta conta possui lanÃ§amentos ou transferÃªncias vinculados. Remova ou mova esses registros antes de excluir a conta.',
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

  void _watchAccounts() {
    if (_userId == null) {
      state = AccountsState(accounts: const [], currencyCode: _currencyCode);
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

  Future<void> _publishState({
    bool? isLoading,
    bool clearError = false,
  }) async {
    final ratesToBrl = await _exchangeRateService.ratesToBrlSnapshot();
    final accounts = [
      for (final account in _accounts)
        _withConsolidatedBalance(account, ratesToBrl),
    ];
    final totalBalanceCents = accounts.fold<int>(
      0,
      (total, account) => account.includeInTotalBalance
          ? total + account.consolidatedBalanceCents
          : total,
    );
    final monthlyExpenseAverageCents =
        _calculateMonthlyExpenseAverageCents(ratesToBrl);

    state = state.copyWith(
      accounts: accounts,
      currencyCode: _currencyCode,
      totalBalanceCents: totalBalanceCents,
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
    return _exchangeRateService.convertCentsWithRates(
      amountCents: transaction.amount,
      fromCurrency: transaction.currencyCode,
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  AccountPreview _withConsolidatedBalance(
    AccountPreview account,
    Map<String, double> ratesToBrl,
  ) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.lastDigits,
      balanceCents: account.balanceCents,
      currencyCode: account.currencyCode,
      displayBalanceCents: _exchangeRateService.convertCentsWithRates(
        amountCents: account.balanceCents,
        fromCurrency: account.currencyCode,
        toCurrency: _currencyCode,
        ratesToBrl: ratesToBrl,
      ),
      includeInTotalBalance: account.includeInTotalBalance,
      emergencyReserveTargetCents: account.emergencyReserveTargetCents,
      color: account.color,
      colorHex: account.colorHex,
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
      emergencyReserveTargetCents: account.emergencyReserveTarget,
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
    super.dispose();
  }
}

final accountsViewModelProvider =
    StateNotifierProvider<AccountsViewModel, AccountsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return AccountsViewModel(
    accountRepository: ref.watch(accountRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
    userId: userId,
  );
});
