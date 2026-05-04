import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/section_card.dart';
import 'planning_view_model.dart';

class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(
      planningViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

    final state = ref.watch(planningViewModelProvider);
    final viewModel = ref.read(planningViewModelProvider.notifier);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlanningHeader(
              monthLabel: state.monthLabel,
              onPreviousMonth: viewModel.previousMonth,
              onNextMonth: viewModel.nextMonth,
              onCalendarTap: () => _pickMonth(context, ref, state),
              onEditPlan: () => _openPlanSheet(context, state),
            ),
            const SizedBox(height: 20),
            if (state.isLoading) ...[
              LinearProgressIndicator(color: context.colors.primary),
              const SizedBox(height: 18),
            ],
            _PlanningProgressCard(
              state: state,
              onEditPlan: () => _openPlanSheet(context, state),
            ),
            const SizedBox(height: 18),
            _PlanningMetrics(state: state),
            const SizedBox(height: 18),
            _PlanSummaryCard(state: state),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Metas e limites',
              child: state.budgets.isEmpty
                  ? const _EmptyPlanningMessage(
                      icon: Icons.track_changes_rounded,
                      title: 'Sem gastos por categoria',
                      message:
                          'Crie um planejamento e registre despesas para acompanhar os limites do mes.',
                    )
                  : Column(
                      children: [
                        for (final budget in state.budgets)
                          _BudgetRow(budget: budget),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Proximas contas',
              child: state.upcomingBills.isEmpty
                  ? const _EmptyPlanningMessage(
                      icon: Icons.event_available_rounded,
                      title: 'Nada previsto em aberto',
                      message:
                          'Despesas pendentes e faturas abertas deste mes aparecem aqui.',
                    )
                  : Column(
                      children: [
                        for (final bill in state.upcomingBills)
                          _BillRow(bill: bill),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    PlanningState state,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecione um dia do mes desejado',
    );
    if (picked == null) {
      return;
    }
    ref.read(planningViewModelProvider.notifier).selectMonth(picked);
  }

  Future<void> _openPlanSheet(
    BuildContext context,
    PlanningState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PlanningFormSheet(initialState: state),
    );
  }
}

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({
    required this.monthLabel,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onCalendarTap,
    required this.onEditPlan,
  });

  final String monthLabel;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onCalendarTap;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
              Row(
                children: [
                  IconButton(
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                  Flexible(
                    child: Text(
                      monthLabel,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onCalendarTap,
          icon: const Icon(Icons.calendar_month_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onEditPlan,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _PlanningProgressCard extends StatelessWidget {
  const _PlanningProgressCard({
    required this.state,
    required this.onEditPlan,
  });

  final PlanningState state;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = state.completionPercent.clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryDark, colors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Planejamento do mes',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(
                onPressed: onEditPlan,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(state.hasPlan ? 'Editar' : 'Criar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.hasPlan
                ? '${(state.completionPercent * 100).round()}% concluido'
                : 'Crie seu plano',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primaryLight),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.hasPlan
                ? '${CurrencyUtils.formatCents(state.currentExpenseCents)} gastos de ${CurrencyUtils.formatCents(state.plannedExpenseCents)} planejados'
                : 'Defina receita, despesas e saldo inicial para acompanhar o mes com dados reais.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${CurrencyUtils.formatCents(state.currentIncomeCents)} recebidos no mes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
        ],
      ),
    );
  }
}

class _PlanningMetrics extends StatelessWidget {
  const _PlanningMetrics({required this.state});

  final PlanningState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth >= 620;
        final metricWidth =
            useColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: metricWidth,
              child: _PlanningMetric(
                title: 'Orcamento disponivel',
                value: CurrencyUtils.formatCents(state.availableBudgetCents),
                icon: Icons.account_balance_wallet_rounded,
                color: state.availableBudgetCents < 0
                    ? context.colors.danger
                    : context.colors.success,
              ),
            ),
            SizedBox(
              width: metricWidth,
              child: _PlanningMetric(
                title: 'Contas previstas',
                value: CurrencyUtils.formatCents(state.upcomingBillsCents),
                icon: Icons.calendar_month_rounded,
                color: context.colors.primary,
              ),
            ),
            SizedBox(
              width: metricWidth,
              child: _PlanningMetric(
                title: 'Receita planejada',
                value: CurrencyUtils.formatCents(state.plannedIncomeCents),
                icon: Icons.trending_up_rounded,
                color: context.colors.info,
              ),
            ),
            SizedBox(
              width: metricWidth,
              child: _PlanningMetric(
                title: 'Saldo final previsto',
                value: CurrencyUtils.formatCents(
                  state.projectedFinalBalanceCents,
                ),
                icon: Icons.ssid_chart_rounded,
                color: state.projectedFinalBalanceCents < 0
                    ? context.colors.danger
                    : context.colors.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.state});

  final PlanningState state;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Plano do mes',
      trailing: Consumer(
        builder: (context, ref, _) {
          return TextButton.icon(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => _PlanningFormSheet(initialState: state),
              );
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(state.hasPlan ? 'Editar' : 'Criar'),
          );
        },
      ),
      child: Column(
        children: [
          _PlanRow(
            label: 'Saldo inicial',
            value: CurrencyUtils.formatCents(state.initialMonthBalanceCents),
          ),
          Divider(height: 22, color: context.colors.border),
          _PlanRow(
            label: 'Receita planejada',
            value: CurrencyUtils.formatCents(state.plannedIncomeCents),
          ),
          Divider(height: 22, color: context.colors.border),
          _PlanRow(
            label: 'Despesa planejada',
            value: CurrencyUtils.formatCents(state.plannedExpenseCents),
          ),
          Divider(height: 22, color: context.colors.border),
          _PlanRow(
            label: 'Saldo final planejado',
            value: CurrencyUtils.formatCents(state.plannedFinalBalanceCents),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
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
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.32 : 0.05),
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
    final colors = context.colors;
    final percent = budget.percent.clamp(0.0, 1.0).toDouble();

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
                  budget.limitCents == 0
                      ? '${CurrencyUtils.formatCents(budget.usedCents)} usados'
                      : '${CurrencyUtils.formatCents(budget.usedCents)} de ${CurrencyUtils.formatCents(budget.limitCents)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(budget.color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              budget.limitCents == 0
                  ? '--'
                  : '${(budget.percent * 100).round()}%',
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
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.accentSoft,
            foregroundColor: colors.primary,
            child: Icon(bill.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  bill.dueLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyUtils.formatCents(bill.amountCents),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanningMessage extends StatelessWidget {
  const _EmptyPlanningMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.surface,
            foregroundColor: colors.primary,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
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

class _PlanningFormSheet extends ConsumerStatefulWidget {
  const _PlanningFormSheet({required this.initialState});

  final PlanningState initialState;

  @override
  ConsumerState<_PlanningFormSheet> createState() => _PlanningFormSheetState();
}

class _PlanningFormSheetState extends ConsumerState<_PlanningFormSheet> {
  late final TextEditingController _incomeController;
  late final TextEditingController _expenseController;
  late final TextEditingController _initialBalanceController;

  @override
  void initState() {
    super.initState();
    final state = widget.initialState;
    _incomeController = TextEditingController(
      text: CurrencyUtils.formatCents(
        state.plannedIncomeCents > 0
            ? state.plannedIncomeCents
            : state.currentIncomeCents,
      ),
    );
    _expenseController = TextEditingController(
      text: CurrencyUtils.formatCents(
        state.plannedExpenseCents > 0
            ? state.plannedExpenseCents
            : state.currentExpenseCents,
      ),
    );
    _initialBalanceController = TextEditingController(
      text: CurrencyUtils.formatCents(state.initialMonthBalanceCents),
    );
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planningViewModelProvider);
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              state.hasPlan ? 'Editar planejamento' : 'Criar planejamento',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              state.monthLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 18),
            _MoneyField(
              controller: _initialBalanceController,
              label: 'Saldo no inicio do mes',
              hintText: r'R$ 0,00',
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 14),
            _MoneyField(
              controller: _incomeController,
              label: 'Receita planejada',
              hintText: r'R$ 0,00',
              icon: Icons.trending_up_rounded,
            ),
            const SizedBox(height: 14),
            _MoneyField(
              controller: _expenseController,
              label: 'Despesa planejada',
              hintText: r'R$ 0,00',
              icon: Icons.trending_down_rounded,
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Os campos ja sugerem o que existe lancado neste mes. Ajuste para refletir seu plano real.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Salvar planejamento',
              isLoading: state.isSaving,
              onPressed: state.isSaving ? null : _save,
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      await ref.read(planningViewModelProvider.notifier).savePlan(
            plannedIncomeCents: CurrencyUtils.parseToCents(
              _incomeController.text,
            ),
            plannedExpenseCents: CurrencyUtils.parseToCents(
              _expenseController.text,
            ),
            initialMonthBalanceCents: CurrencyUtils.parseToCents(
              _initialBalanceController.text,
            ),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planejamento salvo.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
