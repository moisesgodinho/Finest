import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/goal_preview.dart';
import '../../shared/widgets/app_popup_menu_item.dart';
import '../../shared/widgets/balance_card.dart';
import '../../shared/widgets/section_card.dart';
import '../home/income_form_sheet.dart';
import 'goals_view_model.dart';

const _createLinkedAccountValue = -1;
const _goalChartHeight = 252.0;
const _monthlyChartLeftPadding = 58.0;
const _monthlyChartRightPadding = 18.0;
const _annualChartLeftPadding = 58.0;
const _annualChartRightPadding = 18.0;

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsViewModelProvider);

    ref.listen(
      goalsViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova meta',
        onPressed: () => _openGoalForm(context, ref),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            100 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            const _GoalsPageHeader(),
            const SizedBox(height: 18),
            if (state.isLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            _GoalsHeaderCard(state: state),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suas metas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openGoalForm(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.goalAccounts.isEmpty)
              _EmptyPersonalGoals(
                onAdd: () => _openGoalForm(context, ref),
              )
            else
              for (final goal in state.goalAccounts) ...[
                _PersonalGoalTile(
                  goal: goal,
                  linkedAccount: state.linkedAccountFor(goal),
                  projection: state.projectionFor(goal),
                  onOpen: () => context.pushNamed(
                    'goalDetails',
                    pathParameters: {'goalId': goal.id.toString()},
                  ),
                  onEdit: () => _openGoalForm(
                    context,
                    ref,
                    goal: goal,
                  ),
                  onAddIncome: () => _openIncomeForGoal(
                    context,
                    goal,
                    destinationAccountId: state.linkedAccountFor(goal)?.id,
                  ),
                  onDelete: () => _confirmDeleteGoal(
                    context,
                    ref,
                    goal,
                  ),
                ),
                if (goal != state.goalAccounts.last) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _GoalsPageHeader extends StatelessWidget {
  const _GoalsPageHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Metas',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}

Future<void> _openGoalForm(
  BuildContext context,
  WidgetRef ref, {
  GoalPreview? goal,
}) async {
  final viewModel = ref.read(goalsViewModelProvider.notifier);
  final state = ref.read(goalsViewModelProvider);
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return _GoalFormSheet(
        goal: goal,
        linkedAccounts: state.linkedAccountOptions,
        progressBalanceCents:
            goal == null ? 0 : state.goalProgressBalanceCents(goal),
        onSubmit: ({
          required String name,
          required int targetCents,
          required DateTime targetDate,
          required int? linkedAccountId,
          required GoalLinkedAccountDraft? linkedAccountDraft,
          required bool includeInTotalBalance,
        }) async {
          if (goal == null) {
            await viewModel.createGoal(
              name: name,
              targetCents: targetCents,
              targetDate: targetDate,
              linkedAccountId: linkedAccountId,
              linkedAccountDraft: linkedAccountDraft,
              includeInTotalBalance: includeInTotalBalance,
            );
          } else {
            await viewModel.updateGoal(
              goal: goal,
              name: name,
              targetCents: targetCents,
              targetDate: targetDate,
              linkedAccountId: linkedAccountId,
              linkedAccountDraft: linkedAccountDraft,
              includeInTotalBalance: includeInTotalBalance,
            );
          }
        },
      );
    },
  );

  if (saved == true) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(goal == null ? 'Meta criada.' : 'Meta atualizada.'),
      ),
    );
  }
}

Future<void> _openIncomeForGoal(
  BuildContext context,
  GoalPreview goal, {
  int? destinationAccountId,
}) async {
  if (destinationAccountId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Vincule uma conta para adicionar receita.')),
    );
    return;
  }

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => IncomeFormSheet(
      initialAccountId: destinationAccountId,
      lockAccount: true,
      title: 'Receita para ${goal.name}',
    ),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receita adicionada na meta.')),
    );
    return;
  }
}

Future<void> _confirmDeleteGoal(
  BuildContext context,
  WidgetRef ref,
  GoalPreview goal,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir meta?'),
      content: Text(
        'A meta "${goal.name}" sera removida. A conta vinculada e o saldo dela serao mantidos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return;
  }

  await ref.read(goalsViewModelProvider.notifier).deleteGoal(goal);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meta excluida.')),
    );
  }
}

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({
    required this.goalId,
    super.key,
  });

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsViewModelProvider);
    final goal = state.goalById(goalId);
    final linkedAccount = goal == null ? null : state.linkedAccountFor(goal);
    final projection = goal == null ? null : state.projectionFor(goal);

    ref.listen(
      goalsViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meta')),
        body: SafeArea(
          child: Center(
            child: state.isLoading
                ? const CircularProgressIndicator()
                : const Text('Meta nao encontrada.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(goal.name)),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar receita',
        onPressed: () => _openIncomeForGoal(
          context,
          goal,
          destinationAccountId: linkedAccount?.id,
        ),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            100 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            if (state.isLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            _GoalDetailHeaderCard(
              goal: goal,
              linkedAccount: linkedAccount,
              balanceCents: state.goalProgressBalanceCents(goal),
            ),
            const SizedBox(height: 18),
            if (projection != null) ...[
              SectionCard(
                title: 'Projecao patrimonial',
                child: _GoalProjectionSection(
                  linkedAccount: linkedAccount,
                  projection: projection,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalDetailHeaderCard extends StatelessWidget {
  const _GoalDetailHeaderCard({
    required this.goal,
    required this.linkedAccount,
    required this.balanceCents,
  });

  final GoalPreview goal;
  final AccountPreview? linkedAccount;
  final int balanceCents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currencyCode = linkedAccount?.currencyCode ?? 'BRL';
    final targetCents = goal.targetAmountCents;
    final remainingCents =
        (targetCents - balanceCents).clamp(0, targetCents).toInt();
    final progress = _goalProgress(balanceCents, targetCents);
    final progressPercent = (progress * 100).round();
    final gradientStart = _shiftColor(colors.primary, lightnessDelta: 0.10);
    final gradientEnd = _shiftColor(colors.primaryDark, lightnessDelta: -0.02);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primaryDark
                .withValues(alpha: colors.isDark ? 0.32 : 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyUtils.formatCents(
                  balanceCents,
                  currencyCode: currencyCode,
                ),
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            _GoalHeaderProgressPill(
              text: targetCents > 0
                  ? '$progressPercent% concluido - faltam ${CurrencyUtils.formatCents(
                      remainingCents,
                      currencyCode: currencyCode,
                    )}'
                  : 'Meta sem valor definido',
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 560
                    ? (constraints.maxWidth - 20) / 3
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _GoalHeaderInfoTile(
                      width: itemWidth,
                      label: 'Conta vinculada',
                      value: linkedAccount?.name ?? 'Nao definida',
                    ),
                    _GoalHeaderInfoTile(
                      width: itemWidth,
                      label: 'Meta',
                      value: CurrencyUtils.formatCents(
                        targetCents,
                        currencyCode: currencyCode,
                      ),
                    ),
                    _GoalHeaderInfoTile(
                      width: itemWidth,
                      label: 'Prazo',
                      value: goal.targetDate == null
                          ? 'Sem data'
                          : _formatDate(goal.targetDate!),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalHeaderProgressPill extends StatelessWidget {
  const _GoalHeaderProgressPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _GoalHeaderInfoTile extends StatelessWidget {
  const _GoalHeaderInfoTile({
    required this.label,
    required this.value,
    this.width,
  });

  final String label;
  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalChartSurface extends StatelessWidget {
  const _GoalChartSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: _goalChartHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _GoalProjectionSection extends StatelessWidget {
  const _GoalProjectionSection({
    required this.linkedAccount,
    required this.projection,
  });

  final AccountPreview? linkedAccount;
  final GoalProjection projection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currencyCode = linkedAccount?.currencyCode ?? 'BRL';
    const investedColor = Color(0xFF6366F1);
    const yieldColor = Color(0xFF59B883);
    const projectedColor = Color(0xFF4F46E5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 4 : 2;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 10) / columns;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _GoalSmallMetric(
                    icon: Icons.percent_rounded,
                    accentColor: colors.info,
                    label: 'Juros anual medio',
                    value: projection.hasYieldHistory
                        ? _formatAnnualRate(
                            projection.averageAnnualYieldRate,
                          )
                        : 'Sem historico',
                    helper: projection.hasYieldHistory
                        ? '${projection.yieldHistoryMonths} meses de historico'
                        : 'Registre rendimentos',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _GoalSmallMetric(
                    icon: Icons.savings_rounded,
                    accentColor: investedColor,
                    label: 'Aporte medio',
                    value: CurrencyUtils.formatCents(
                      projection.averageMonthlyContributionCents,
                      currencyCode: currencyCode,
                    ),
                    helper: 'Media dos aportes positivos',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _GoalSmallMetric(
                    icon: Icons.trending_up_rounded,
                    accentColor: yieldColor,
                    label: 'Juros projetados',
                    value: CurrencyUtils.formatCents(
                      projection.projectedInterestCents,
                      currencyCode: currencyCode,
                    ),
                    helper:
                        _formatProjectionDuration(projection.projectedMonths),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _GoalSmallMetric(
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: projectedColor,
                    label: 'Montante final',
                    value: CurrencyUtils.formatCents(
                      projection.projectedFinalBalanceCents,
                      currencyCode: currencyCode,
                    ),
                    helper: projection.targetReachedAt == null
                        ? 'Meta ainda nao atingida'
                        : 'Chega em ${_formatCompletionMonth(projection.targetReachedAt)}',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  foregroundColor: colors.primary,
                  child: const Icon(Icons.insights_rounded, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _projectionSummary(projection, currencyCode),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          height: 1.38,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _GoalProjectionBlockTitle(
          title: 'Evolucao anual do patrimonio',
          subtitle: 'Total investido e juros acumulados',
        ),
        const SizedBox(height: 10),
        _GoalAnnualProjectionChart(
          rows: projection.annualRows,
          targetCents: projection.targetCents,
          currencyCode: currencyCode,
          investedColor: investedColor,
          interestColor: yieldColor,
          targetColor: colors.warning,
        ),
        const SizedBox(height: 24),
        _GoalProjectionBlockTitle(
          title: 'Evolucao mensal do patrimonio',
          subtitle: projection.points.length > 1
              ? 'Toque ou arraste no grafico para ver cada mes'
              : 'Total investido e montante projetado',
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: const [
            _GoalProjectionLegend(
              color: investedColor,
              label: 'Total investido',
            ),
            _GoalProjectionLegend(
              color: yieldColor,
              label: 'Montante',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GoalMonthlyProjectionChart(
          projection: projection,
          currencyCode: currencyCode,
          investedColor: investedColor,
          yieldColor: yieldColor,
        ),
        const SizedBox(height: 24),
        const _GoalProjectionBlockTitle(
          title: 'Projecao detalhada',
          subtitle: 'Primeiros meses, marco da meta e fechamento',
        ),
        const SizedBox(height: 10),
        _GoalProjectionDetailList(
          projection: projection,
          currencyCode: currencyCode,
          highlightColor: yieldColor,
        ),
      ],
    );
  }
}

class _GoalProjectionBlockTitle extends StatelessWidget {
  const _GoalProjectionBlockTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _GoalProjectionCallout extends StatelessWidget {
  const _GoalProjectionCallout({
    required this.projection,
    required this.currencyCode,
  });

  final GoalProjection projection;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final hasYield = projection.hasYieldHistory;
    final text = hasYield
        ? '${_formatAnnualRate(projection.averageAnnualYieldRate)} em media nos ultimos ${projection.yieldHistoryMonths} meses. Montante projetado: ${CurrencyUtils.formatCents(
            projection.projectedFinalBalanceCents,
            currencyCode: currencyCode,
          )}.'
        : 'Registre rendimentos da conta para melhorar a projecao.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              hasYield ? Icons.trending_up_rounded : Icons.auto_graph_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProjectionLegend extends StatelessWidget {
  const _GoalProjectionLegend({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: color.withValues(alpha: colors.isDark ? 0.70 : 0.20),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _GoalMonthlyProjectionChart extends StatefulWidget {
  const _GoalMonthlyProjectionChart({
    required this.projection,
    required this.currencyCode,
    required this.investedColor,
    required this.yieldColor,
  });

  final GoalProjection projection;
  final String currencyCode;
  final Color investedColor;
  final Color yieldColor;

  @override
  State<_GoalMonthlyProjectionChart> createState() =>
      _GoalMonthlyProjectionChartState();
}

class _GoalMonthlyProjectionChartState
    extends State<_GoalMonthlyProjectionChart> {
  int? _selectedIndex;

  int get _effectiveSelectedIndex {
    final points = widget.projection.points;
    if (points.isEmpty) {
      return 0;
    }
    return (_selectedIndex ?? points.length - 1).clamp(0, points.length - 1);
  }

  void _selectFromPosition(Offset localPosition, Size size) {
    final points = widget.projection.points;
    if (points.isEmpty) {
      return;
    }

    const leftPadding = _monthlyChartLeftPadding;
    const rightPadding = _monthlyChartRightPadding;
    final chartWidth = math.max(1.0, size.width - leftPadding - rightPadding);
    final dx = (localPosition.dx - leftPadding).clamp(0.0, chartWidth);
    final index = points.length == 1
        ? 0
        : ((dx / chartWidth) * (points.length - 1)).round();
    setState(() => _selectedIndex = index.clamp(0, points.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final points = widget.projection.points;

    if (points.isEmpty) {
      return const _GoalProjectionEmpty(
        message: 'Sem dados suficientes para projetar a evolucao mensal.',
      );
    }

    final selectedIndex = _effectiveSelectedIndex;
    final selectedPoint = points[selectedIndex];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final chartSize = Size(
              constraints.maxWidth,
              _goalChartHeight,
            );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _selectFromPosition(details.localPosition, chartSize),
              onHorizontalDragStart: (details) =>
                  _selectFromPosition(details.localPosition, chartSize),
              onHorizontalDragUpdate: (details) =>
                  _selectFromPosition(details.localPosition, chartSize),
              child: _GoalChartSurface(
                child: CustomPaint(
                  painter: _GoalProjectionChartPainter(
                    points: points,
                    targetCents: widget.projection.targetCents,
                    yieldColor: widget.yieldColor,
                    baseColor: widget.investedColor,
                    targetColor: colors.warning,
                    gridColor: colors.border,
                    labelColor: colors.textSecondary,
                    currencyCode: widget.currencyCode,
                    showYieldLine: widget.projection.hasYieldHistory,
                    selectedIndex: selectedIndex,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _GoalProjectionSelectionSummary(
          title: selectedIndex == 0
              ? 'Inicio - ${_shortMonth(selectedPoint.month)}'
              : 'Mes $selectedIndex - ${_shortMonth(selectedPoint.month)}',
          items: [
            _GoalProjectionSummaryItem(
              label: 'Investido',
              value: CurrencyUtils.formatCents(
                selectedPoint.balanceWithoutYieldCents,
                currencyCode: widget.currencyCode,
              ),
              color: widget.investedColor,
            ),
            _GoalProjectionSummaryItem(
              label: 'Montante',
              value: CurrencyUtils.formatCents(
                selectedPoint.balanceWithYieldCents,
                currencyCode: widget.currencyCode,
              ),
              color: widget.yieldColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalProjectionChartPainter extends CustomPainter {
  const _GoalProjectionChartPainter({
    required this.points,
    required this.targetCents,
    required this.yieldColor,
    required this.baseColor,
    required this.targetColor,
    required this.gridColor,
    required this.labelColor,
    required this.currencyCode,
    required this.showYieldLine,
    required this.selectedIndex,
  });

  final List<GoalProjectionPoint> points;
  final int targetCents;
  final Color yieldColor;
  final Color baseColor;
  final Color targetColor;
  final Color gridColor;
  final Color labelColor;
  final String currencyCode;
  final bool showYieldLine;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    const leftPadding = _monthlyChartLeftPadding;
    const rightPadding = _monthlyChartRightPadding;
    const topPadding = 24.0;
    const bottomPadding = 42.0;
    final chartRect = Rect.fromLTRB(
      leftPadding,
      topPadding,
      size.width - rightPadding,
      size.height - bottomPadding,
    );

    var maxValue = 1.0;
    for (final point in points) {
      maxValue = math.max(maxValue, point.balanceWithoutYieldCents.toDouble());
      maxValue = math.max(maxValue, point.balanceWithYieldCents.toDouble());
    }
    if (targetCents > 0) {
      maxValue = math.max(maxValue, targetCents.toDouble());
    }
    const minValue = 0.0;
    final span = math.max(1.0, maxValue - minValue);
    maxValue += span * 0.14;
    final safeSpan = math.max(1.0, maxValue - minValue);

    Offset offsetFor(int index, int value) {
      final x = points.length == 1
          ? chartRect.right
          : chartRect.left + (chartRect.width / (points.length - 1)) * index;
      final normalized = (value - minValue) / safeSpan;
      final y = chartRect.bottom - (chartRect.height * normalized);
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.46)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final normalized = index / 3;
      final y = chartRect.bottom - (chartRect.height * normalized);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawLabel(
        canvas,
        Offset(chartRect.left - 8, y - 7),
        _formatCompactCurrency(
          (maxValue * normalized).round(),
          currencyCode: currencyCode,
        ),
        labelColor.withValues(alpha: 0.82),
        TextAlign.right,
      );
    }

    List<Offset> offsetsFor(int Function(GoalProjectionPoint point) valueFor) {
      final offsets = <Offset>[];
      for (var index = 0; index < points.length; index++) {
        offsets.add(offsetFor(index, valueFor(points[index])));
      }
      return offsets;
    }

    final baseOffsets = offsetsFor((point) => point.balanceWithoutYieldCents);
    final yieldOffsets = offsetsFor((point) => point.balanceWithYieldCents);
    final basePath = _smoothPath(baseOffsets);
    final yieldPath = _smoothPath(yieldOffsets);
    final focusOffsets = showYieldLine ? yieldOffsets : baseOffsets;
    final focusPath = showYieldLine ? yieldPath : basePath;

    if (targetCents > 0) {
      final normalized = ((targetCents - minValue) / safeSpan).clamp(0.0, 1.0);
      final targetY = chartRect.bottom - chartRect.height * normalized;
      _drawDashedLine(
        canvas,
        Offset(chartRect.left, targetY),
        Offset(chartRect.right, targetY),
        Paint()
          ..color = targetColor.withValues(alpha: 0.72)
          ..strokeWidth = 1.2,
      );
      _drawLabel(
        canvas,
        Offset(chartRect.right, targetY - 18),
        'Meta',
        targetColor,
        TextAlign.right,
      );
    }

    if (points.length > 1) {
      final fillPath = Path.from(focusPath)
        ..lineTo(focusOffsets.last.dx, chartRect.bottom)
        ..lineTo(focusOffsets.first.dx, chartRect.bottom)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (showYieldLine ? yieldColor : baseColor).withValues(alpha: 0.16),
              (showYieldLine ? yieldColor : baseColor).withValues(alpha: 0.02),
            ],
          ).createShader(chartRect),
      );
    }

    final basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(basePath, basePaint);

    if (showYieldLine) {
      final yieldPaint = Paint()
        ..color = yieldColor
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(yieldPath, yieldPaint);
    }

    void drawMarkers(List<Offset> offsets, Color color) {
      final step = math.max(1, (offsets.length / 16).ceil());
      for (var index = 0; index < offsets.length; index += step) {
        canvas.drawCircle(
          offsets[index],
          2.4,
          Paint()..color = color.withValues(alpha: 0.78),
        );
      }
      canvas.drawCircle(offsets.last, 3.2, Paint()..color = color);
    }

    drawMarkers(baseOffsets, baseColor);
    if (showYieldLine) {
      drawMarkers(yieldOffsets, yieldColor);
    }

    final safeSelectedIndex = selectedIndex.clamp(0, points.length - 1);
    final selectedBase = baseOffsets[safeSelectedIndex];
    final selectedYield = yieldOffsets[safeSelectedIndex];
    final selectedX = selectedYield.dx;
    canvas.drawLine(
      Offset(selectedX, chartRect.top),
      Offset(selectedX, chartRect.bottom),
      Paint()
        ..color = labelColor.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      selectedBase,
      5,
      Paint()..color = baseColor.withValues(alpha: 0.18),
    );
    canvas.drawCircle(selectedBase, 3, Paint()..color = baseColor);
    if (showYieldLine) {
      canvas.drawCircle(
        selectedYield,
        6,
        Paint()..color = yieldColor.withValues(alpha: 0.18),
      );
      canvas.drawCircle(selectedYield, 3.4, Paint()..color = yieldColor);
    }

    _drawLabel(
      canvas,
      Offset(chartRect.left, size.height - 26),
      _shortMonth(points.first.month),
      labelColor,
      TextAlign.left,
    );
    _drawLabel(
      canvas,
      Offset(chartRect.right, size.height - 26),
      _shortMonth(points.last.month),
      labelColor,
      TextAlign.right,
    );
  }

  Path _smoothPath(List<Offset> offsets) {
    final path = Path();
    if (offsets.isEmpty) {
      return path;
    }
    if (offsets.length == 1) {
      path.moveTo(offsets.first.dx, offsets.first.dy);
      return path;
    }

    path.moveTo(offsets.first.dx, offsets.first.dy);
    for (var index = 0; index < offsets.length - 1; index++) {
      final current = offsets[index];
      final next = offsets[index + 1];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }
    path.quadraticBezierTo(
      offsets[offsets.length - 2].dx,
      offsets[offsets.length - 2].dy,
      offsets.last.dx,
      offsets.last.dy,
    );
    return path;
  }

  void _drawLabel(
    Canvas canvas,
    Offset anchor,
    String text,
    Color color,
    TextAlign align,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final dx =
        align == TextAlign.right ? anchor.dx - textPainter.width : anchor.dx;
    textPainter.paint(canvas, Offset(dx, anchor.dy));
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 6.0;
    const dashGap = 5.0;
    var currentX = start.dx;
    while (currentX < end.dx) {
      final nextX = math.min(currentX + dashWidth, end.dx);
      canvas.drawLine(Offset(currentX, start.dy), Offset(nextX, end.dy), paint);
      currentX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _GoalProjectionChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.targetCents != targetCents ||
        oldDelegate.yieldColor != yieldColor ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.currencyCode != currencyCode ||
        oldDelegate.showYieldLine != showYieldLine ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _GoalAnnualProjectionChart extends StatelessWidget {
  const _GoalAnnualProjectionChart({
    required this.rows,
    required this.targetCents,
    required this.currencyCode,
    required this.investedColor,
    required this.interestColor,
    required this.targetColor,
  });

  final List<GoalProjectionYear> rows;
  final int targetCents;
  final String currencyCode;
  final Color investedColor;
  final Color interestColor;
  final Color targetColor;

  int _selectedIndexFromPosition(Offset localPosition, Size size) {
    if (rows.isEmpty) {
      return 0;
    }

    const leftPadding = _annualChartLeftPadding;
    const rightPadding = _annualChartRightPadding;
    final chartWidth = math.max(1.0, size.width - leftPadding - rightPadding);
    final dx = (localPosition.dx - leftPadding).clamp(0.0, chartWidth);
    final slotWidth = chartWidth / rows.length;
    final index = (dx / slotWidth).floor();
    return index.clamp(0, rows.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _GoalProjectionEmpty(
        message: 'Meta ja alcancada ou sem meses para projetar.',
      );
    }

    return _GoalAnnualProjectionChartBody(
      rows: rows,
      targetCents: targetCents,
      currencyCode: currencyCode,
      investedColor: investedColor,
      interestColor: interestColor,
      targetColor: targetColor,
      indexFromPosition: _selectedIndexFromPosition,
    );
  }
}

class _GoalAnnualProjectionChartBody extends StatefulWidget {
  const _GoalAnnualProjectionChartBody({
    required this.rows,
    required this.targetCents,
    required this.currencyCode,
    required this.investedColor,
    required this.interestColor,
    required this.targetColor,
    required this.indexFromPosition,
  });

  final List<GoalProjectionYear> rows;
  final int targetCents;
  final String currencyCode;
  final Color investedColor;
  final Color interestColor;
  final Color targetColor;
  final int Function(Offset localPosition, Size size) indexFromPosition;

  @override
  State<_GoalAnnualProjectionChartBody> createState() =>
      _GoalAnnualProjectionChartBodyState();
}

class _GoalAnnualProjectionChartBodyState
    extends State<_GoalAnnualProjectionChartBody> {
  int? _selectedIndex;

  int get _effectiveSelectedIndex {
    return (_selectedIndex ?? widget.rows.length - 1)
        .clamp(0, widget.rows.length - 1);
  }

  void _selectFromPosition(Offset localPosition, Size size) {
    setState(
      () => _selectedIndex = widget.indexFromPosition(localPosition, size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _effectiveSelectedIndex;
    final selectedRow = widget.rows[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _GoalProjectionLegend(
              color: widget.investedColor,
              label: 'Total investido',
            ),
            _GoalProjectionLegend(
              color: widget.interestColor,
              label: 'Juros acumulados',
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartSize = Size(
              constraints.maxWidth,
              _goalChartHeight,
            );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _selectFromPosition(details.localPosition, chartSize),
              onHorizontalDragStart: (details) =>
                  _selectFromPosition(details.localPosition, chartSize),
              onHorizontalDragUpdate: (details) =>
                  _selectFromPosition(details.localPosition, chartSize),
              child: _GoalChartSurface(
                child: CustomPaint(
                  painter: _GoalAnnualProjectionChartPainter(
                    rows: widget.rows,
                    targetCents: widget.targetCents,
                    currencyCode: widget.currencyCode,
                    investedColor: widget.investedColor,
                    interestColor: widget.interestColor,
                    targetColor: widget.targetColor,
                    gridColor: context.colors.border,
                    labelColor: context.colors.textSecondary,
                    selectedIndex: selectedIndex,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _GoalProjectionSelectionSummary(
          title:
              'Ano ${selectedRow.yearNumber} - ${_shortMonth(selectedRow.month)}',
          items: [
            _GoalProjectionSummaryItem(
              label: 'Investido',
              value: CurrencyUtils.formatCents(
                selectedRow.totalInvestedCents,
                currencyCode: widget.currencyCode,
              ),
              color: widget.investedColor,
            ),
            _GoalProjectionSummaryItem(
              label: 'Juros',
              value: CurrencyUtils.formatCents(
                selectedRow.accumulatedInterestCents,
                currencyCode: widget.currencyCode,
              ),
              color: widget.interestColor,
            ),
            _GoalProjectionSummaryItem(
              label: 'Montante',
              value: CurrencyUtils.formatCents(
                selectedRow.projectedBalanceCents,
                currencyCode: widget.currencyCode,
              ),
              color: const Color(0xFF4F46E5),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalAnnualProjectionChartPainter extends CustomPainter {
  const _GoalAnnualProjectionChartPainter({
    required this.rows,
    required this.targetCents,
    required this.currencyCode,
    required this.investedColor,
    required this.interestColor,
    required this.targetColor,
    required this.gridColor,
    required this.labelColor,
    required this.selectedIndex,
  });

  final List<GoalProjectionYear> rows;
  final int targetCents;
  final String currencyCode;
  final Color investedColor;
  final Color interestColor;
  final Color targetColor;
  final Color gridColor;
  final Color labelColor;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) {
      return;
    }

    const leftPadding = _annualChartLeftPadding;
    const rightPadding = _annualChartRightPadding;
    const topPadding = 26.0;
    const bottomPadding = 42.0;
    final chartRect = Rect.fromLTRB(
      leftPadding,
      topPadding,
      size.width - rightPadding,
      size.height - bottomPadding,
    );

    var maxValue = 1.0;
    for (final row in rows) {
      maxValue = math.max(maxValue, row.projectedBalanceCents.toDouble());
    }
    if (targetCents > 0) {
      maxValue = math.max(maxValue, targetCents.toDouble());
    }
    maxValue += maxValue * 0.10;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.46)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final normalized = index / 3;
      final y = chartRect.bottom - (chartRect.height * normalized);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawLabel(
        canvas,
        Offset(chartRect.left - 8, y - 7),
        _formatCompactCurrency(
          (maxValue * normalized).round(),
          currencyCode: currencyCode,
        ),
        labelColor.withValues(alpha: 0.82),
        TextAlign.right,
      );
    }

    if (targetCents > 0) {
      final normalized = (targetCents / maxValue).clamp(0.0, 1.0);
      final targetY = chartRect.bottom - chartRect.height * normalized;
      _drawDashedLine(
        canvas,
        Offset(chartRect.left, targetY),
        Offset(chartRect.right, targetY),
        Paint()
          ..color = targetColor.withValues(alpha: 0.72)
          ..strokeWidth = 1.2,
      );
      _drawLabel(
        canvas,
        Offset(chartRect.right, targetY - 18),
        'Meta',
        targetColor,
        TextAlign.right,
      );
    }

    final slotWidth = chartRect.width / rows.length;
    final barWidth = (slotWidth * 0.58).clamp(12.0, 40.0).toDouble();

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final isSelected = index == selectedIndex.clamp(0, rows.length - 1);
      final centerX = chartRect.left + slotWidth * index + slotWidth / 2;
      final left = centerX - barWidth / 2;
      final totalHeight =
          chartRect.height * (row.projectedBalanceCents / maxValue);
      final investedHeight =
          chartRect.height * (row.totalInvestedCents / maxValue);
      final interestHeight = math.max(0.0, totalHeight - investedHeight);
      final bottom = chartRect.bottom;

      if (isSelected) {
        final highlightRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            centerX - slotWidth / 2 + 4,
            chartRect.top,
            centerX + slotWidth / 2 - 4,
            chartRect.bottom,
          ),
          const Radius.circular(12),
        );
        canvas.drawRRect(
          highlightRect,
          Paint()..color = labelColor.withValues(alpha: 0.08),
        );
      }

      final investedRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, bottom - investedHeight, left + barWidth, bottom),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        investedRect,
        Paint()
          ..color = investedColor.withValues(alpha: isSelected ? 1.0 : 0.82),
      );

      if (interestHeight > 1) {
        final interestRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left,
            bottom - totalHeight,
            left + barWidth,
            bottom - investedHeight + 2,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(
          interestRect,
          Paint()
            ..color = interestColor.withValues(alpha: isSelected ? 1.0 : 0.86),
        );
      }

      if (isSelected) {
        final selectedRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left - 4,
            bottom - totalHeight - 4,
            left + barWidth + 4,
            bottom + 2,
          ),
          const Radius.circular(7),
        );
        canvas.drawRRect(
          selectedRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = labelColor.withValues(alpha: 0.40),
        );
      }

      final shouldDrawLabel = rows.length <= 6 ||
          index == 0 ||
          index == rows.length - 1 ||
          index % math.max(1, (rows.length / 4).ceil()) == 0;
      if (shouldDrawLabel) {
        _drawLabel(
          canvas,
          Offset(centerX, size.height - 24),
          'Ano ${row.yearNumber}',
          labelColor,
          TextAlign.center,
        );
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset anchor,
    String text,
    Color color,
    TextAlign align,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 72);
    final dx = switch (align) {
      TextAlign.center => anchor.dx - textPainter.width / 2,
      TextAlign.right => anchor.dx - textPainter.width,
      _ => anchor.dx,
    };
    textPainter.paint(canvas, Offset(dx, anchor.dy));
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 6.0;
    const dashGap = 5.0;
    var currentX = start.dx;
    while (currentX < end.dx) {
      final nextX = math.min(currentX + dashWidth, end.dx);
      canvas.drawLine(Offset(currentX, start.dy), Offset(nextX, end.dy), paint);
      currentX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _GoalAnnualProjectionChartPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.targetCents != targetCents ||
        oldDelegate.currencyCode != currencyCode ||
        oldDelegate.investedColor != investedColor ||
        oldDelegate.interestColor != interestColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _GoalProjectionSelectionSummary extends StatelessWidget {
  const _GoalProjectionSelectionSummary({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_GoalProjectionSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620
                    ? math.min(3, items.length)
                    : constraints.maxWidth >= 440
                        ? 2
                        : 1;
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;

                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: itemWidth,
                        child: _GoalProjectionSummaryPill(item: item),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProjectionSummaryPill extends StatelessWidget {
  const _GoalProjectionSummaryPill({required this.item});

  final _GoalProjectionSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Text(
                  item.value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProjectionSummaryItem {
  const _GoalProjectionSummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _GoalProjectionDetailList extends StatelessWidget {
  const _GoalProjectionDetailList({
    required this.projection,
    required this.currencyCode,
    required this.highlightColor,
  });

  final GoalProjection projection;
  final String currencyCode;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = projection.monthlyRows;
    final visibleRows = _visibleRowsFor(rows);
    final hiddenCount = rows.length - visibleRows.length;

    if (rows.isEmpty) {
      return const _GoalProjectionEmpty(
        message: 'Nada para detalhar: a meta ja foi alcancada.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, isCompact: isCompact),
                for (final row in visibleRows) ...[
                  Divider(height: 1, thickness: 1, color: colors.border),
                  if (isCompact)
                    _buildCompactRow(context, row)
                  else
                    _buildWideRow(context, row),
                ],
                if (hiddenCount > 0) ...[
                  Divider(height: 1, thickness: 1, color: colors.border),
                  _buildPreviewFooter(context, hiddenCount),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<GoalProjectionMonth> _visibleRowsFor(List<GoalProjectionMonth> rows) {
    if (rows.length <= 18) {
      return rows;
    }

    final indexes = <int>{};
    for (var index = 0; index < math.min(12, rows.length); index++) {
      indexes.add(index);
    }

    final targetIndex = rows.indexWhere((row) => row.reachesTarget);
    if (targetIndex >= 0) {
      indexes.add(targetIndex);
    }
    indexes.add(rows.length - 1);

    final sortedIndexes = indexes.toList()..sort();
    return [
      for (final index in sortedIndexes) rows[index],
    ];
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isCompact,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );

    return Container(
      color: colors.surfaceElevated,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 0,
        vertical: isCompact ? 12 : 0,
      ),
      constraints: BoxConstraints(minHeight: isCompact ? 42 : 44),
      child: Row(
        children: [
          if (isCompact) ...[
            Expanded(child: Text('MES', style: headerStyle)),
            Text('MONTANTE TOTAL', style: headerStyle),
          ] else ...[
            _buildTableCell('MES', flex: 1, style: headerStyle),
            _buildTableCell(
              'TOTAL INVESTIDO',
              flex: 3,
              alignment: Alignment.centerRight,
              style: headerStyle,
            ),
            _buildTableCell(
              'JUROS ACUMULADOS',
              flex: 3,
              alignment: Alignment.centerRight,
              style: headerStyle,
            ),
            _buildTableCell(
              'MONTANTE TOTAL',
              flex: 3,
              alignment: Alignment.centerRight,
              style: headerStyle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWideRow(BuildContext context, GoalProjectionMonth row) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final backgroundColor = row.reachesTarget
        ? highlightColor.withValues(alpha: colors.isDark ? 0.16 : 0.08)
        : colors.surface;

    return Container(
      color: backgroundColor,
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: [
          _buildTableCell(
            row.monthNumber.toString(),
            flex: 1,
            alignment: Alignment.center,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          _buildTableCell(
            CurrencyUtils.formatCents(
              row.totalInvestedCents,
              currencyCode: currencyCode,
            ),
            flex: 3,
            alignment: Alignment.centerRight,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          _buildTableCell(
            CurrencyUtils.formatCents(
              row.accumulatedInterestCents,
              currencyCode: currencyCode,
            ),
            flex: 3,
            alignment: Alignment.centerRight,
            style: textTheme.bodyMedium?.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          _buildTableCell(
            CurrencyUtils.formatCents(
              row.projectedBalanceCents,
              currencyCode: currencyCode,
            ),
            flex: 3,
            alignment: Alignment.centerRight,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4F46E5),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(BuildContext context, GoalProjectionMonth row) {
    final colors = context.colors;
    final backgroundColor = row.reachesTarget
        ? highlightColor.withValues(alpha: colors.isDark ? 0.16 : 0.08)
        : colors.surface;

    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            _buildCompactLine(
              context,
              label: 'Mes',
              value: row.monthNumber.toString(),
              valueColor: colors.textPrimary,
              isStrong: true,
            ),
            const SizedBox(height: 6),
            _buildCompactLine(
              context,
              label: 'Montante total',
              value: CurrencyUtils.formatCents(
                row.projectedBalanceCents,
                currencyCode: currencyCode,
              ),
              valueColor: const Color(0xFF4F46E5),
              isStrong: true,
            ),
            const SizedBox(height: 6),
            _buildCompactLine(
              context,
              label: 'Total investido',
              value: CurrencyUtils.formatCents(
                row.totalInvestedCents,
                currencyCode: currencyCode,
              ),
            ),
            const SizedBox(height: 6),
            _buildCompactLine(
              context,
              label: 'Juros acumulados',
              value: CurrencyUtils.formatCents(
                row.accumulatedInterestCents,
                currencyCode: currencyCode,
              ),
              valueColor: highlightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLine(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    bool isStrong = false,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: textTheme.bodySmall?.copyWith(
              color: valueColor ?? colors.textSecondary,
              fontWeight: isStrong ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewFooter(BuildContext context, int hiddenCount) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      color: colors.surfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.unfold_more_rounded,
              size: 18, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hiddenCount == 1
                  ? '1 mes intermediario oculto para manter a leitura enxuta.'
                  : '$hiddenCount meses intermediarios ocultos para manter a leitura enxuta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(
    String value, {
    required int flex,
    Alignment alignment = Alignment.centerLeft,
    TextStyle? style,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _GoalProjectionEmpty extends StatelessWidget {
  const _GoalProjectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.auto_graph_rounded, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSmallMetric extends StatelessWidget {
  const _GoalSmallMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(
                      alpha: colors.isDark ? 0.18 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 17),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              helper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsHeaderCard extends StatelessWidget {
  const _GoalsHeaderCard({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.overallProgress.clamp(0.0, 1.0).toDouble();
    final progressPercent = (progress * 100).round();
    final totalTargetCents = state.goalTargetCents;
    final remainingCents = (totalTargetCents - state.goalBalanceCents)
        .clamp(0, totalTargetCents)
        .toInt();

    return BalanceCard(
      title: 'Metas financeiras',
      value: CurrencyUtils.formatCents(state.goalBalanceCents),
      subtitle: totalTargetCents > 0
          ? '$progressPercent% concluido - faltam ${CurrencyUtils.formatCents(remainingCents)}'
          : 'Crie sua primeira meta com conta vinculada',
    );
  }
}

class _EmptyPersonalGoals extends StatelessWidget {
  const _EmptyPersonalGoals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primary.withValues(alpha: 0.10),
            foregroundColor: colors.primary,
            child: const Icon(Icons.flag_rounded, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'Crie metas com valor, prazo e uma conta vinculada.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar meta'),
          ),
        ],
      ),
    );
  }
}

class _PersonalGoalTile extends StatelessWidget {
  const _PersonalGoalTile({
    required this.goal,
    required this.linkedAccount,
    required this.projection,
    required this.onOpen,
    required this.onEdit,
    required this.onAddIncome,
    required this.onDelete,
  });

  final GoalPreview goal;
  final AccountPreview? linkedAccount;
  final GoalProjection? projection;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onAddIncome;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseColor = goal.color;
    final gradientStart = _shiftColor(baseColor, lightnessDelta: 0.10);
    final gradientEnd = _shiftColor(baseColor, lightnessDelta: -0.12);
    final currencyCode = linkedAccount?.currencyCode ?? 'BRL';
    final targetCents = goal.targetAmountCents;
    final targetDate = goal.targetDate;
    final currentBalanceCents = linkedAccount?.balanceCents ?? 0;
    final progress = _goalProgress(currentBalanceCents, targetCents);
    final progressPercent = (progress * 100).round();
    final remainingCents =
        (targetCents - currentBalanceCents).clamp(0, targetCents).toInt();
    final monthlyContributionCents = _monthlyContributionEstimate(
      remainingCents: remainingCents,
      targetDate: targetDate,
    );
    final projectedMonthlyContributionCents =
        projection?.requiredMonthlyWithoutYieldCents ??
            monthlyContributionCents;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: colors.isDark ? 0.28 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    child: Text(
                      _initialsFor(goal.name),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          linkedAccount == null
                              ? 'Conta vinculada não definida'
                              : 'Vinculada a ${linkedAccount!.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  AppPopupMenuButton<_GoalAction>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white),
                    tooltip: 'Opções',
                    onSelected: (action) {
                      switch (action) {
                        case _GoalAction.addIncome:
                          onAddIncome();
                          break;
                        case _GoalAction.edit:
                          onEdit();
                          break;
                        case _GoalAction.delete:
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _GoalAction.addIncome,
                        child: AppPopupMenuItem(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Adicionar receita',
                        ),
                      ),
                      PopupMenuItem(
                        value: _GoalAction.edit,
                        child: AppPopupMenuItem(
                          icon: Icons.edit_rounded,
                          label: 'Editar meta',
                        ),
                      ),
                      PopupMenuItem(
                        value: _GoalAction.delete,
                        child: AppPopupMenuItem(
                          icon: Icons.delete_outline_rounded,
                          label: 'Excluir meta',
                          isDestructive: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _GoalCardMetric(
                      label: 'Saldo',
                      value: CurrencyUtils.formatCents(
                        currentBalanceCents,
                        currencyCode: currencyCode,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GoalCardMetric(
                      label: 'Meta',
                      value: targetCents > 0
                          ? CurrencyUtils.formatCents(
                              targetCents,
                              currencyCode: currencyCode,
                            )
                          : 'Sem valor',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GoalCardMetric(
                      label: 'Prazo',
                      value: targetDate == null
                          ? 'Sem data'
                          : _formatDate(targetDate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GoalCardMetric(
                      label: 'Aporte/mês',
                      value: CurrencyUtils.formatCents(
                        projectedMonthlyContributionCents,
                        currencyCode: currencyCode,
                      ),
                    ),
                  ),
                ],
              ),
              if (projection != null) ...[
                const SizedBox(height: 12),
                _GoalProjectionCallout(
                  projection: projection!,
                  currencyCode: currencyCode,
                ),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      remainingCents == 0
                          ? 'Meta alcançada'
                          : '$progressPercent% concluído, faltam ${CurrencyUtils.formatCents(remainingCents)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onAddIncome,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Receita'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GoalAction { addIncome, edit, delete }

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({
    required this.goal,
    required this.linkedAccounts,
    required this.progressBalanceCents,
    required this.onSubmit,
  });

  final GoalPreview? goal;
  final List<AccountPreview> linkedAccounts;
  final int progressBalanceCents;
  final Future<void> Function({
    required String name,
    required int targetCents,
    required DateTime targetDate,
    required int? linkedAccountId,
    required GoalLinkedAccountDraft? linkedAccountDraft,
    required bool includeInTotalBalance,
  }) onSubmit;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _newAccountNameController;
  late final TextEditingController _newAccountBankController;
  late final TextEditingController _newAccountInitialBalanceController;
  late DateTime _targetDate;
  late int _selectedLinkedAccountValue;
  late bool _includeInTotalBalance;
  bool _isSubmitting = false;

  bool get _isEditing => widget.goal != null;
  bool get _shouldCreateLinkedAccount =>
      _selectedLinkedAccountValue == _createLinkedAccountValue;
  AccountPreview? get _selectedLinkedAccount {
    for (final account in widget.linkedAccounts) {
      if (account.id == _selectedLinkedAccountValue) {
        return account;
      }
    }
    return null;
  }

  int get _currentLinkedBalanceCents {
    if (_shouldCreateLinkedAccount) {
      return CurrencyUtils.parseToCents(
          _newAccountInitialBalanceController.text);
    }

    return _selectedLinkedAccount?.balanceCents ?? widget.progressBalanceCents;
  }

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    final fallbackTargetDate = DateTime(
      DateTime.now().year,
      DateTime.now().month + 12,
    );
    final linkedId = goal?.linkedAccountId;
    final hasLinkedAccount = linkedId != null &&
        widget.linkedAccounts.any((account) => account.id == linkedId);

    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal == null ? '' : _formatCentsForInput(goal.targetAmountCents),
    );
    _newAccountNameController = TextEditingController();
    _newAccountBankController = TextEditingController();
    _newAccountInitialBalanceController = TextEditingController();
    _targetDate = goal?.targetDate ?? fallbackTargetDate;
    _selectedLinkedAccountValue = hasLinkedAccount
        ? linkedId
        : widget.linkedAccounts.isEmpty
            ? _createLinkedAccountValue
            : widget.linkedAccounts.first.id;
    _includeInTotalBalance =
        _selectedLinkedAccount?.includeInTotalBalance ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _newAccountNameController.dispose();
    _newAccountBankController.dispose();
    _newAccountInitialBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar meta' : 'Nova meta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da meta',
                  hintText: 'Ex: Casa própria',
                  prefixIcon: Icon(Icons.flag_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da meta.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selectedLinkedAccountValue,
                decoration: const InputDecoration(
                  labelText: 'Conta vinculada',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items: [
                  for (final account in widget.linkedAccounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                  const DropdownMenuItem(
                    value: _createLinkedAccountValue,
                    child: Text('Criar nova conta'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedLinkedAccountValue = value;
                    _includeInTotalBalance =
                        _selectedLinkedAccount?.includeInTotalBalance ?? false;
                  });
                },
              ),
              if (_shouldCreateLinkedAccount) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newAccountNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da nova conta',
                    hintText: 'Ex: Conta da meta',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                  validator: (value) {
                    if (!_shouldCreateLinkedAccount) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da conta.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newAccountBankController,
                  decoration: const InputDecoration(
                    labelText: 'Banco ou descrição',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newAccountInitialBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Saldo inicial da conta',
                    hintText: 'Ex: 0,00',
                    prefixIcon: Icon(Icons.savings_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateOptionalAmount,
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor da meta',
                  hintText: 'Ex: 50000,00',
                  prefixIcon: Icon(Icons.track_changes_rounded),
                ),
                validator: _validatePositiveAmount,
              ),
              const SizedBox(height: 14),
              _LinkedBalancePreview(amountCents: _currentLinkedBalanceCents),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickTargetDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Pretende alcançar até',
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(_formatDate(_targetDate)),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeInTotalBalance,
                title: const Text('Somar ao saldo total'),
                subtitle: const Text(
                  'Quando desligado, o dinheiro fica separado dos saldos principais.',
                ),
                onChanged: (value) {
                  setState(() => _includeInTotalBalance = value);
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar meta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate.isBefore(firstDate) ? firstDate : _targetDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 30),
    );
    if (pickedDate != null) {
      setState(() => _targetDate = pickedDate);
    }
  }

  String? _validatePositiveAmount(String? value) {
    if (value == null || CurrencyUtils.parseToCents(value) <= 0) {
      return 'Informe um valor maior que zero.';
    }
    return null;
  }

  String? _validateOptionalAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (CurrencyUtils.parseToCents(value) < 0) {
      return 'Informe um valor válido.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        targetCents: CurrencyUtils.parseToCents(_targetController.text),
        targetDate: _targetDate,
        linkedAccountId:
            _shouldCreateLinkedAccount ? null : _selectedLinkedAccountValue,
        linkedAccountDraft: _shouldCreateLinkedAccount
            ? GoalLinkedAccountDraft(
                name: _newAccountNameController.text.trim(),
                bankName: _newAccountBankController.text.trim().isEmpty
                    ? null
                    : _newAccountBankController.text.trim(),
                initialBalanceCents: CurrencyUtils.parseToCents(
                  _newAccountInitialBalanceController.text,
                ),
              )
            : null,
        includeInTotalBalance: _includeInTotalBalance,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatCentsForInput(int cents) {
    if (cents == 0) {
      return '';
    }
    return (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _LinkedBalancePreview extends StatelessWidget {
  const _LinkedBalancePreview({required this.amountCents});

  final int amountCents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.savings_rounded, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor já aportado',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyUtils.formatCents(amountCents),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCardMetric extends StatelessWidget {
  const _GoalCardMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _goalProgress(int balanceCents, int targetCents) {
  if (targetCents <= 0) {
    return 0;
  }
  return (balanceCents / targetCents).clamp(0.0, 1.0).toDouble();
}

int _monthlyContributionEstimate({
  required int remainingCents,
  required DateTime? targetDate,
}) {
  if (remainingCents <= 0) {
    return 0;
  }
  if (targetDate == null) {
    return remainingCents;
  }

  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final targetMonth = DateTime(targetDate.year, targetDate.month);
  final months = ((targetMonth.year - currentMonth.year) * 12) +
      targetMonth.month -
      currentMonth.month +
      1;
  final safeMonths = months.clamp(1, 360).toInt();
  return ((remainingCents + safeMonths - 1) / safeMonths).floor();
}

String _formatCompactCurrency(
  int cents, {
  required String currencyCode,
}) {
  final amount = cents / 100;
  final absAmount = amount.abs();
  var suffix = '';
  late final String value;

  if (absAmount >= 1000000) {
    value = (amount / 1000000).toStringAsFixed(absAmount >= 10000000 ? 0 : 1);
    suffix = ' mi';
  } else if (absAmount >= 1000) {
    value = (amount / 1000).toStringAsFixed(absAmount >= 10000 ? 0 : 1);
    suffix = ' mil';
  } else {
    value = amount.toStringAsFixed(0);
  }

  final prefix = currencyCode == 'BRL' ? r'R$ ' : '$currencyCode ';
  return '$prefix${value.replaceAll('.', ',')}$suffix';
}

String _projectionSummary(GoalProjection projection, String currencyCode) {
  if (projection.remainingCents <= 0) {
    return 'Meta alcancada. A projecao continua acompanhando os rendimentos da conta vinculada.';
  }

  if (!projection.hasContributionPace && !projection.hasYieldHistory) {
    return 'Ainda nao ha historico suficiente de aportes ou rendimentos para prever a conclusao.';
  }

  final finalBalance = CurrencyUtils.formatCents(
    projection.projectedFinalBalanceCents,
    currencyCode: currencyCode,
  );
  final projectedInterest = CurrencyUtils.formatCents(
    projection.projectedInterestCents,
    currencyCode: currencyCode,
  );
  final duration = _formatProjectionDuration(projection.projectedMonths);
  final targetReachedAt = _formatCompletionMonth(projection.targetReachedAt);

  if (projection.targetReachedAt != null) {
    return 'No ritmo atual, a meta chega em $targetReachedAt. Em $duration, o montante projetado e $finalBalance, com $projectedInterest em juros.';
  }

  if (projection.monthsToTarget > 0) {
    final gap = (projection.targetCents - projection.projectedFinalBalanceCents)
        .clamp(0, projection.targetCents)
        .toInt();
    final gapText = CurrencyUtils.formatCents(gap, currencyCode: currencyCode);
    return 'No prazo definido, a projecao chega a $finalBalance em $duration, com $projectedInterest em juros. Ainda faltariam $gapText para a meta.';
  }

  return 'Mantendo o ritmo atual, a projecao chega a $finalBalance em $duration, com $projectedInterest em juros. A meta ainda nao e atingida nesse horizonte.';
}

String _formatCompletionMonth(DateTime? date) {
  return date == null ? 'sem previsao' : _shortMonth(date);
}

String _formatAnnualRate(double rate) {
  final percent = rate * 100;
  final decimals = percent >= 10 ? 1 : 2;
  return '${percent.toStringAsFixed(decimals).replaceAll('.', ',')}% a.a.';
}

String _formatProjectionDuration(int months) {
  if (months <= 0) {
    return 'agora';
  }

  if (months < 12) {
    return months == 1 ? '1 mes' : '$months meses';
  }

  final years = months ~/ 12;
  final remainingMonths = months % 12;
  final yearsText = years == 1 ? '1 ano' : '$years anos';
  if (remainingMonths == 0) {
    return yearsText;
  }

  final monthsText = remainingMonths == 1 ? '1 mes' : '$remainingMonths meses';
  return '$yearsText e $monthsText';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _shortMonth(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '$month/$year';
}

String _initialsFor(String name) {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    return '?';
  }
  return trimmedName.characters.take(2).toString().toUpperCase();
}

Color _shiftColor(Color color, {required double lightnessDelta}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
      .toColor();
}
