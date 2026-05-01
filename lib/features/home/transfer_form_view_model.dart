import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_transfer_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transfer_repository.dart';

class TransferFormState {
  const TransferFormState({
    required this.accounts,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AccountPreview> accounts;
  final bool isLoading;
  final String? errorMessage;

  TransferFormState copyWith({
    List<AccountPreview>? accounts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransferFormState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TransferFormViewModel extends StateNotifier<TransferFormState> {
  TransferFormViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required TransferRepository transferRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _transferRepository = transferRepository,
        super(const TransferFormState(accounts: [], isLoading: true)) {
    _watchAccounts();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final TransferRepository _transferRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;

  Future<void> saveTransfer({
    required String name,
    required int amountCents,
    required String transferKind,
    required int fromAccountId,
    required int toAccountId,
    required DateTime dueDate,
    required bool isPaid,
    required DateTime date,
    int? totalInstallments,
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _transferRepository.createTransfer(
        CreateTransferRequest(
          userId: userId,
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          name: name,
          amountCents: amountCents,
          transferKind: transferKind,
          dueDate: dueDate,
          isPaid: isPaid,
          date: date,
          installmentNumber: transferKind == 'installment' ? 1 : null,
          totalInstallments:
              transferKind == 'installment' ? totalInstallments : null,
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

  void _watchAccounts() {
    final userId = _userId;
    if (userId == null) {
      state = const TransferFormState(accounts: []);
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
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
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
    super.dispose();
  }
}

final transferFormViewModelProvider =
    StateNotifierProvider.autoDispose<TransferFormViewModel, TransferFormState>(
  (ref) {
    final userId = ref.watch(
      authStateProvider.select((state) => state.user?.id),
    );

    return TransferFormViewModel(
      userId: userId,
      accountRepository: ref.watch(accountRepositoryProvider),
      transferRepository: ref.watch(transferRepositoryProvider),
    );
  },
);
