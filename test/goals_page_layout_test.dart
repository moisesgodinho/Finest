import 'package:finest/core/theme/app_theme.dart';
import 'package:finest/data/models/account_preview.dart';
import 'package:finest/data/models/goal_preview.dart';
import 'package:finest/data/repositories/account_repository.dart';
import 'package:finest/data/repositories/credit_card_repository.dart';
import 'package:finest/data/repositories/goal_repository.dart';
import 'package:finest/data/repositories/monthly_plan_repository.dart';
import 'package:finest/data/repositories/transaction_repository.dart';
import 'package:finest/data/repositories/transfer_repository.dart';
import 'package:finest/features/goals/goals_page.dart';
import 'package:finest/features/goals/goals_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza detalhe de meta com graficos no mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalsViewModelProvider.overrideWith((ref) {
            return _FakeGoalsViewModel(_goalsState);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GoalDetailPage(goalId: 1),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Projecao patrimonial'), findsOneWidget);
    expect(find.text('Evolucao anual do patrimonio'), findsOneWidget);
    expect(find.text('Evolucao mensal do patrimonio'), findsOneWidget);
    // Layout exceptions fail the test automatically.
  });
}

final _fixedDate = DateTime(2026, 5);

const _goal = GoalPreview(
  id: 1,
  userId: 1,
  name: 'Reserva para viagem',
  linkedAccountId: 1,
  targetAmountCents: 3000000,
  targetDate: null,
  color: Color(0xFF006B4F),
  colorHex: '#006B4F',
);

final _account = AccountPreview(
  id: 1,
  name: 'Conta da meta',
  type: 'savings',
  balanceCents: 550000,
  initialBalanceCents: 500000,
  currentBalanceCents: 550000,
  currencyCode: 'BRL',
  includeInTotalBalance: false,
  color: const Color(0xFF006B4F),
  colorHex: '#006B4F',
  createdAt: _fixedDate,
);

final _projectionPoints = [
  for (var index = 0; index <= 24; index++)
    GoalProjectionPoint(
      month: DateTime(2026, 5 + index),
      balanceWithoutYieldCents: 550000 + index * 85000,
      balanceWithYieldCents: 550000 + index * 94000 + index * index * 900,
    ),
];

final _monthlyRows = [
  for (var index = 1; index <= 24; index++)
    GoalProjectionMonth(
      monthNumber: index,
      month: DateTime(2026, 5 + index),
      contributionCents: 85000,
      monthlyInterestCents: 9000 + index * 650,
      accumulatedInterestCents: index * 9500,
      totalInvestedCents: 550000 + index * 85000,
      projectedBalanceCents: 550000 + index * 94000 + index * index * 900,
      reachesTarget: index == 22,
    ),
];

final _annualRows = [
  GoalProjectionYear(
    yearNumber: 1,
    month: DateTime(2027, 5),
    totalInvestedCents: 1570000,
    accumulatedInterestCents: 120000,
    projectedBalanceCents: 1690000,
  ),
  GoalProjectionYear(
    yearNumber: 2,
    month: DateTime(2028, 5),
    totalInvestedCents: 2590000,
    accumulatedInterestCents: 360000,
    projectedBalanceCents: 2950000,
  ),
  GoalProjectionYear(
    yearNumber: 3,
    month: DateTime(2028, 6),
    totalInvestedCents: 2675000,
    accumulatedInterestCents: 405000,
    projectedBalanceCents: 3080000,
  ),
];

final _projection = GoalProjection(
  currentBalanceCents: 550000,
  targetCents: 3000000,
  remainingCents: 2450000,
  monthsToTarget: 24,
  requiredMonthlyWithoutYieldCents: 102084,
  requiredMonthlyWithYieldCents: 94000,
  averageMonthlyYieldRate: 0.006,
  averageAnnualYieldRate: 0.0744,
  yieldHistoryMonths: 8,
  averageMonthlyContributionCents: 85000,
  estimatedMonthlyYieldCents: 3300,
  projectedFinalBalanceCents: 3080000,
  projectedTotalInvestedCents: 2675000,
  projectedInterestCents: 405000,
  projectedMonths: 24,
  targetReachedAt: DateTime(2028, 3),
  estimatedCompletionWithoutYield: DateTime(2028, 10),
  estimatedCompletionWithYield: DateTime(2028, 3),
  points: _projectionPoints,
  monthlyRows: _monthlyRows,
  annualRows: _annualRows,
);

final _goalsState = GoalsState(
  selectedMonth: _fixedDate,
  accounts: [_account],
  goals: const [_goal],
  projectionsByGoalId: {1: _projection},
  isLoading: false,
);

class _FakeGoalsViewModel extends GoalsViewModel {
  _FakeGoalsViewModel(GoalsState initialState)
      : super(
          userId: null,
          accountRepository: _FakeAccountRepository(),
          creditCardRepository: _FakeCreditCardRepository(),
          goalRepository: _FakeGoalRepository(),
          monthlyPlanRepository: _FakeMonthlyPlanRepository(),
          transactionRepository: _FakeTransactionRepository(),
          transferRepository: _FakeTransferRepository(),
        ) {
    state = initialState;
  }
}

class _FakeAccountRepository implements AccountRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCreditCardRepository implements CreditCardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoalRepository implements GoalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMonthlyPlanRepository implements MonthlyPlanRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionRepository implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransferRepository implements TransferRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
