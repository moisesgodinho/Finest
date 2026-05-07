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
      appBar: AppBar(title: const Text('Metas')),
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
            12,
            20,
            100 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
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
    final series = goal == null
        ? const <GoalBalancePoint>[]
        : state.balanceSeriesFor(goal);

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
            SectionCard(
              title: 'Evolucao do saldo',
              child: _GoalEvolutionChart(
                goal: goal,
                linkedAccount: linkedAccount,
                series: series,
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Detalhes',
              child: Column(
                children: [
                  _GoalDetailRow(
                    label: 'Conta vinculada',
                    value: linkedAccount?.name ?? 'Nao definida',
                  ),
                  _GoalDetailRow(
                    label: 'Meta',
                    value: CurrencyUtils.formatCents(
                      goal.targetAmountCents,
                      currencyCode: linkedAccount?.currencyCode ?? 'BRL',
                    ),
                  ),
                  _GoalDetailRow(
                    label: 'Prazo',
                    value: goal.targetDate == null
                        ? 'Sem data'
                        : _formatDate(goal.targetDate!),
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
    final targetCents = goal.targetAmountCents;
    final remainingCents =
        (targetCents - balanceCents).clamp(0, targetCents).toInt();
    final progress = _goalProgress(balanceCents, targetCents);
    final progressPercent = (progress * 100).round();

    return BalanceCard(
      title: goal.name,
      value: CurrencyUtils.formatCents(
        balanceCents,
        currencyCode: linkedAccount?.currencyCode ?? 'BRL',
      ),
      subtitle: targetCents > 0
          ? '$progressPercent% concluido - faltam ${CurrencyUtils.formatCents(
              remainingCents,
              currencyCode: linkedAccount?.currencyCode ?? 'BRL',
            )}'
          : 'Meta sem valor definido',
    );
  }
}

class _GoalEvolutionChart extends StatelessWidget {
  const _GoalEvolutionChart({
    required this.goal,
    required this.linkedAccount,
    required this.series,
  });

  final GoalPreview goal;
  final AccountPreview? linkedAccount;
  final List<GoalBalancePoint> series;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currencyCode = linkedAccount?.currencyCode ?? 'BRL';

    if (series.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: colors.primary.withValues(alpha: 0.10),
              foregroundColor: colors.primary,
              child: const Icon(Icons.show_chart_rounded),
            ),
            const SizedBox(height: 12),
            Text(
              'Sem historico suficiente para montar o grafico.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    final first = series.first;
    final last = series.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: CustomPaint(
            painter: _GoalEvolutionChartPainter(
              points: series,
              lineColor: goal.color,
              gridColor: colors.border,
              labelColor: colors.textSecondary,
              currencyCode: currencyCode,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GoalSmallMetric(
                label: _shortMonth(first.month),
                value: CurrencyUtils.formatCents(
                  first.balanceCents,
                  currencyCode: currencyCode,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GoalSmallMetric(
                label: _shortMonth(last.month),
                value: CurrencyUtils.formatCents(
                  last.balanceCents,
                  currencyCode: currencyCode,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalEvolutionChartPainter extends CustomPainter {
  const _GoalEvolutionChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.currencyCode,
  });

  final List<GoalBalancePoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final String currencyCode;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 18.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartTop = topPadding;
    final chartBottom = topPadding + chartHeight;

    var minValue = points.first.balanceCents;
    var maxValue = points.first.balanceCents;
    for (final point in points) {
      if (point.balanceCents < minValue) {
        minValue = point.balanceCents;
      }
      if (point.balanceCents > maxValue) {
        maxValue = point.balanceCents;
      }
    }

    final target = points.isNotEmpty ? points.last.balanceCents : 0;
    if (target < minValue) {
      minValue = target;
    }
    if (target > maxValue) {
      maxValue = target;
    }

    final span = (maxValue - minValue).abs();
    final safeSpan = span == 0 ? 1 : span;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.70)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = chartTop + (chartHeight / 3) * index;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    Offset pointOffset(int index, GoalBalancePoint point) {
      final x = points.length == 1
          ? leftPadding + chartWidth
          : leftPadding + (chartWidth / (points.length - 1)) * index;
      final normalized = (point.balanceCents - minValue) / safeSpan;
      final y = chartBottom - (chartHeight * normalized);
      return Offset(x, y);
    }

    final linePath = Path();
    final fillPath = Path();
    for (var index = 0; index < points.length; index++) {
      final offset = pointOffset(index, points[index]);
      if (index == 0) {
        linePath.moveTo(offset.dx, offset.dy);
        fillPath.moveTo(offset.dx, chartBottom);
        fillPath.lineTo(offset.dx, offset.dy);
      } else {
        linePath.lineTo(offset.dx, offset.dy);
        fillPath.lineTo(offset.dx, offset.dy);
      }
    }
    fillPath.lineTo(
        pointOffset(points.length - 1, points.last).dx, chartBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.24),
          lineColor.withValues(alpha: 0.03),
        ],
      ).createShader(Rect.fromLTWH(0, chartTop, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = lineColor;
    final latestOffset = pointOffset(points.length - 1, points.last);
    canvas.drawCircle(latestOffset, 5, dotPaint);
    canvas.drawCircle(
      latestOffset,
      8,
      Paint()..color = lineColor.withValues(alpha: 0.16),
    );

    _drawLabel(
      canvas,
      Offset(leftPadding, size.height - 20),
      _shortMonth(points.first.month),
      labelColor,
      TextAlign.left,
    );
    _drawLabel(
      canvas,
      Offset(size.width - rightPadding, size.height - 20),
      _shortMonth(points.last.month),
      labelColor,
      TextAlign.right,
    );
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

  @override
  bool shouldRepaint(covariant _GoalEvolutionChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.currencyCode != currencyCode;
  }
}

class _GoalDetailRow extends StatelessWidget {
  const _GoalDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSmallMetric extends StatelessWidget {
  const _GoalSmallMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
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
    required this.onOpen,
    required this.onEdit,
    required this.onAddIncome,
    required this.onDelete,
  });

  final GoalPreview goal;
  final AccountPreview? linkedAccount;
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
                        monthlyContributionCents,
                        currencyCode: currencyCode,
                      ),
                    ),
                  ),
                ],
              ),
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
