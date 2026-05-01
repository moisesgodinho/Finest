import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';

class AccountsState {
  const AccountsState({
    required this.accounts,
    this.isBalanceVisible = true,
  });

  final List<AccountPreview> accounts;
  final bool isBalanceVisible;

  int get totalBalanceCents {
    return accounts.fold<int>(0, (total, account) => total + account.balanceCents);
  }

  AccountsState copyWith({bool? isBalanceVisible}) {
    return AccountsState(
      accounts: accounts,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
    );
  }
}

class AccountsViewModel extends StateNotifier<AccountsState> {
  AccountsViewModel()
      : super(
          const AccountsState(
            accounts: [
              AccountPreview(
                name: 'Nubank',
                type: 'Conta corrente',
                bankName: 'Nubank',
                lastDigits: '1234',
                balanceCents: 342080,
                color: AppColors.purple,
              ),
              AccountPreview(
                name: 'Inter',
                type: 'Conta digital',
                bankName: 'Inter',
                lastDigits: '5678',
                balanceCents: 218050,
                color: Colors.deepOrange,
              ),
              AccountPreview(
                name: 'Caixa',
                type: 'Poupança',
                bankName: 'Caixa',
                lastDigits: '9012',
                balanceCents: 525035,
                color: AppColors.info,
              ),
              AccountPreview(
                name: 'Banco do Brasil',
                type: 'Conta corrente',
                bankName: 'Banco do Brasil',
                lastDigits: '3456',
                balanceCents: 162910,
                color: AppColors.warning,
              ),
            ],
          ),
        );

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }
}

final accountsViewModelProvider =
    StateNotifierProvider<AccountsViewModel, AccountsState>((ref) {
  return AccountsViewModel();
});
