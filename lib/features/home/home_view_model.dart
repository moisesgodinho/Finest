import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_expense_preview.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/transaction_preview.dart';

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

  HomeState copyWith({bool? isBalanceVisible}) {
    return HomeState(
      userName: userName,
      monthLabel: monthLabel,
      currentBalanceCents: currentBalanceCents,
      projectedBalanceCents: projectedBalanceCents,
      initialMonthBalanceCents: initialMonthBalanceCents,
      incomeCents: incomeCents,
      expenseCents: expenseCents,
      creditCard: creditCard,
      categories: categories,
      recentTransactions: recentTransactions,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel({required String userName})
      : super(
          HomeState(
            userName: userName,
            monthLabel: AppDateUtils.monthYearLabel(DateTime.now()),
            currentBalanceCents: 498075,
            projectedBalanceCents: 674530,
            initialMonthBalanceCents: 570000,
            incomeCents: 985000,
            expenseCents: 486925,
            creditCard: const CreditCardPreview(
              name: 'Nubank',
              lastDigits: '1234',
              invoiceCents: 125840,
              limitCents: 500000,
              usedPercent: 0.42,
              color: AppColors.primaryDark,
              dueDay: 15,
            ),
            categories: const [
              CategoryExpensePreview(
                name: 'Alimentação',
                amountCents: 123050,
                percent: 0.25,
                color: AppColors.success,
                icon: Icons.restaurant_rounded,
              ),
              CategoryExpensePreview(
                name: 'Transporte',
                amountCents: 95030,
                percent: 0.19,
                color: AppColors.info,
                icon: Icons.directions_bus_rounded,
              ),
              CategoryExpensePreview(
                name: 'Moradia',
                amountCents: 150000,
                percent: 0.31,
                color: AppColors.purple,
                icon: Icons.home_work_rounded,
              ),
              CategoryExpensePreview(
                name: 'Lazer',
                amountCents: 72040,
                percent: 0.15,
                color: AppColors.warning,
                icon: Icons.local_activity_rounded,
              ),
              CategoryExpensePreview(
                name: 'Saúde',
                amountCents: 46805,
                percent: 0.10,
                color: Colors.pink,
                icon: Icons.favorite_rounded,
              ),
            ],
            recentTransactions: const [
              TransactionPreview(
                title: 'Supermercado',
                subtitle: 'Alimentação • Hoje',
                amountCents: 15680,
                icon: Icons.shopping_cart_rounded,
                iconColor: AppColors.success,
              ),
              TransactionPreview(
                title: 'Salário',
                subtitle: 'Receita • Ontem',
                amountCents: 485000,
                icon: Icons.payments_rounded,
                iconColor: AppColors.success,
                isIncome: true,
              ),
              TransactionPreview(
                title: 'Posto Ipiranga',
                subtitle: 'Transporte • 06/05',
                amountCents: 12000,
                icon: Icons.local_gas_station_rounded,
                iconColor: AppColors.purple,
              ),
              TransactionPreview(
                title: 'Droga Raia',
                subtitle: 'Saúde • 05/05',
                amountCents: 8990,
                icon: Icons.medical_services_rounded,
                iconColor: Colors.pink,
              ),
            ],
          ),
        );

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }
}

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final user = ref.watch(authStateProvider.select((state) => state.user));
  return HomeViewModel(userName: user?.name ?? 'Camila Souza');
});
