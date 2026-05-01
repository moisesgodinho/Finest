import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/widgets/section_card.dart';
import 'planning_view_model.dart';

class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planningViewModelProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlanningHeader(monthLabel: AppDateUtils.monthYearLabel(DateTime.now())),
            const SizedBox(height: 20),
            _PlanningProgressCard(state: state),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _PlanningMetric(
                    title: 'Orçamento disponível',
                    value: CurrencyUtils.formatCents(state.availableBudgetCents),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlanningMetric(
                    title: 'Contas previstas',
                    value: CurrencyUtils.formatCents(state.upcomingBillsCents),
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Metas e limites',
              child: Column(
                children: [
                  for (final budget in state.budgets)
                    _BudgetRow(budget: budget),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Próximas contas',
              child: Column(
                children: [
                  for (final bill in state.upcomingBills) _BillRow(bill: bill),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planejamento',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(monthLabel, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.calendar_month_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _PlanningProgressCard extends StatelessWidget {
  const _PlanningProgressCard({required this.state});

  final PlanningState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planejamento do mês',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(state.completionPercent * 100).round()}% concluído',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: state.completionPercent.clamp(0.0, 1.0).toDouble(),
              minHeight: 12,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${CurrencyUtils.formatCents(state.currentExpenseCents)} gastos de ${CurrencyUtils.formatCents(state.plannedExpenseCents)} planejados',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlanningMetric extends StatelessWidget {
  const _PlanningMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.10),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final BudgetLimitPreview budget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: budget.color.withValues(alpha: 0.12),
            foregroundColor: budget.color,
            child: Icon(budget.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(budget.name, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 3),
                Text(
                  '${CurrencyUtils.formatCents(budget.usedCents)} de ${CurrencyUtils.formatCents(budget.limitCents)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: budget.percent.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(budget.color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '${(budget.percent * 100).round()}%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: budget.color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final PlannedBillPreview bill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.event_available_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.name, style: Theme.of(context).textTheme.bodyLarge),
                Text(bill.dueLabel, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Agendada',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyUtils.formatCents(bill.amountCents),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
