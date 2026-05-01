import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

class BudgetLimitPreview {
  const BudgetLimitPreview({
    required this.name,
    required this.usedCents,
    required this.limitCents,
    required this.color,
    required this.icon,
  });

  final String name;
  final int usedCents;
  final int limitCents;
  final Color color;
  final IconData icon;

  double get percent => limitCents == 0 ? 0 : usedCents / limitCents;
}

class PlannedBillPreview {
  const PlannedBillPreview({
    required this.name,
    required this.dueLabel,
    required this.amountCents,
    required this.icon,
  });

  final String name;
  final String dueLabel;
  final int amountCents;
  final IconData icon;
}

class PlanningState {
  const PlanningState({
    required this.plannedExpenseCents,
    required this.currentExpenseCents,
    required this.upcomingBillsCents,
    required this.budgets,
    required this.upcomingBills,
  });

  final int plannedExpenseCents;
  final int currentExpenseCents;
  final int upcomingBillsCents;
  final List<BudgetLimitPreview> budgets;
  final List<PlannedBillPreview> upcomingBills;

  double get completionPercent {
    if (plannedExpenseCents == 0) {
      return 0;
    }
    return currentExpenseCents / plannedExpenseCents;
  }

  int get availableBudgetCents => plannedExpenseCents - currentExpenseCents;
}

class PlanningViewModel extends StateNotifier<PlanningState> {
  PlanningViewModel()
      : super(
          const PlanningState(
            plannedExpenseCents: 1000000,
            currentExpenseCents: 486925,
            upcomingBillsCents: 124000,
            budgets: [
              BudgetLimitPreview(
                name: 'Alimentação',
                usedCents: 123050,
                limitCents: 150000,
                color: AppColors.success,
                icon: Icons.restaurant_rounded,
              ),
              BudgetLimitPreview(
                name: 'Transporte',
                usedCents: 95030,
                limitCents: 120000,
                color: AppColors.info,
                icon: Icons.directions_bus_rounded,
              ),
              BudgetLimitPreview(
                name: 'Lazer',
                usedCents: 72040,
                limitCents: 80000,
                color: AppColors.warning,
                icon: Icons.star_outline_rounded,
              ),
              BudgetLimitPreview(
                name: 'Saúde',
                usedCents: 46805,
                limitCents: 70000,
                color: Colors.pink,
                icon: Icons.favorite_border_rounded,
              ),
            ],
            upcomingBills: [
              PlannedBillPreview(
                name: 'Aluguel',
                dueLabel: 'Vencimento: 10/06',
                amountCents: 95000,
                icon: Icons.home_rounded,
              ),
              PlannedBillPreview(
                name: 'Internet',
                dueLabel: 'Vencimento: 12/06',
                amountCents: 9990,
                icon: Icons.wifi_rounded,
              ),
              PlannedBillPreview(
                name: 'Escola',
                dueLabel: 'Vencimento: 10/06',
                amountCents: 45000,
                icon: Icons.school_rounded,
              ),
            ],
          ),
        );
}

final planningViewModelProvider =
    StateNotifierProvider<PlanningViewModel, PlanningState>((ref) {
  return PlanningViewModel();
});
