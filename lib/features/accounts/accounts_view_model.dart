import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_account_request.dart';
import '../../data/models/update_account_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class AccountsState {
  const AccountsState({
    required this.accounts,
    this.monthlyExpenseAverageCents = 0,
    this.suggestedEmergencyReserveCents = 0,
    this.isBalanceVisible = true,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AccountPreview> accounts;
  final int monthlyExpenseAverageCents;
  final int suggestedEmergencyReserveCents;
  final bool isBalanceVisible;
  final bool isLoading;
  final String? errorMessage;

  int get totalBalanceCents {
    return accounts.fold<int>(
      0,
      (total, account) => total + account.balanceCents,
    );
  }

  int get emergencyReserveBalanceCents {
    return emergencyReserveAccount?.balanceCents ?? 0;
  }

  AccountPreview? get emergencyReserveAccount {
    for (final account in accounts) {
      if (account.emergencyReserveTargetCents != null) {
        return account;
      }
    }

    for (final account in accounts) {
      if (account.isEmergencyReserve) {
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
    int? monthlyExpenseAverageCents,
    int? suggestedEmergencyReserveCents,
    bool? isBalanceVisible,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
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
    required int? userId,
  })  : _accountRepository = accountRepository,
        _transactionRepository = transactionRepository,
        _userId = userId,
        super(const AccountsState(accounts: [], isLoading: true)) {
    _watchAccounts();
    _watchTransactions();
  }

  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final int? _userId;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<AccountPreview> _accounts = [];
  List<FinanceTransaction> _transactions = [];

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required int initialBalance,
    int? emergencyReserveTarget,
    String? bankName,
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
          emergencyReserveTarget: emergencyReserveTarget,
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
    String? bankName,
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.updateAccount(
        UpdateAccountRequest(
          id: account.id,
          userId: userId,
          name: name,
          type: type,
          bankName: bankName,
          initialBalance: balanceCents,
          currentBalance: balanceCents,
          emergencyReserveTarget: emergencyReserveTarget,
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
      state = const AccountsState(accounts: []);
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

  void _publishState({
    bool? isLoading,
    bool clearError = false,
  }) {
    final monthlyExpenseAverageCents = _calculateMonthlyExpenseAverageCents();

    state = state.copyWith(
      accounts: _accounts,
      monthlyExpenseAverageCents: monthlyExpenseAverageCents,
      suggestedEmergencyReserveCents:
          _reserveTargetFor(monthlyExpenseAverageCents),
      isLoading: isLoading,
      clearError: clearError,
    );
  }

  int _calculateMonthlyExpenseAverageCents() {
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
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    if (totalsByMonth.isEmpty) {
      return 0;
    }

    final total =
        totalsByMonth.values.fold<int>(0, (sum, value) => sum + value);
    return (total / totalsByMonth.length).round();
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

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      balanceCents: account.currentBalance,
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
    userId: userId,
  );
});
