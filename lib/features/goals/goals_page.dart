import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/account_preview.dart';
import '../../shared/widgets/section_card.dart';
import '../home/transfer_form_sheet.dart';
import 'goals_view_model.dart';

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
      appBar: AppBar(
        title: const Text('Metas'),
        actions: [
          IconButton(
            tooltip: 'Nova meta',
            onPressed: () => _openGoalForm(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGoalForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Meta'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            if (state.isLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            _GoalsHeaderCard(state: state),
            const SizedBox(height: 14),
            _GoalMetrics(state: state),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Metas pessoais',
              trailing: TextButton.icon(
                onPressed: () => _openGoalForm(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Adicionar'),
              ),
              child: state.goalAccounts.isEmpty
                  ? _EmptyPersonalGoals(
                      onAdd: () => _openGoalForm(context, ref),
                    )
                  : Column(
                      children: [
                        for (final goal in state.goalAccounts) ...[
                          _PersonalGoalTile(
                            goal: goal,
                            onEdit: () => _openGoalForm(
                              context,
                              ref,
                              goal: goal,
                            ),
                            onTransfer: () => _openTransferToGoal(
                              context,
                              goal,
                            ),
                          ),
                          if (goal != state.goalAccounts.last)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Reservas',
              child: _GoalProgressTile(
                icon: Icons.shield_rounded,
                color: context.colors.primary,
                title: 'Reserva de emergência',
                subtitle: _reserveSubtitle(state),
                currentLabel: CurrencyUtils.formatCents(
                  state.emergencyReserveBalanceCents,
                ),
                targetLabel: state.emergencyReserveTargetCents > 0
                    ? CurrencyUtils.formatCents(
                        state.emergencyReserveTargetCents,
                      )
                    : 'A calcular',
                progress: state.emergencyReserveProgress,
                statusLabel: _reserveStatus(state),
                footer: state.emergencyReserveTargetCents > 0
                    ? state.emergencyReserveRemainingCents == 0
                        ? 'Meta alcançada'
                        : 'Faltam ${CurrencyUtils.formatCents(state.emergencyReserveRemainingCents)}'
                    : 'Registre despesas para gerar uma sugestão',
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Objetivos do mês',
              child: Column(
                children: [
                  _GoalProgressTile(
                    icon: Icons.account_balance_wallet_rounded,
                    color: context.colors.info,
                    title: 'Orçamento mensal',
                    subtitle: state.plannedExpenseCents > 0
                        ? 'Gastos dentro do limite planejado'
                        : 'Planejamento ainda não criado',
                    currentLabel: CurrencyUtils.formatCents(
                      state.currentExpenseCents,
                    ),
                    targetLabel: state.plannedExpenseCents > 0
                        ? CurrencyUtils.formatCents(state.plannedExpenseCents)
                        : 'Sem limite',
                    progress: state.budgetUsageProgress,
                    statusLabel: _budgetStatus(state),
                    footer: _budgetFooter(state),
                  ),
                  const SizedBox(height: 14),
                  _GoalProgressTile(
                    icon: Icons.trending_up_rounded,
                    color: context.colors.success,
                    title: 'Taxa de poupança',
                    subtitle: 'Guardar pelo menos 10% da renda do mês',
                    currentLabel: CurrencyUtils.formatCents(
                      state.monthlySavingsCents,
                    ),
                    targetLabel: state.monthlySavingsTargetCents > 0
                        ? CurrencyUtils.formatCents(
                            state.monthlySavingsTargetCents,
                          )
                        : 'Sem receita',
                    progress: state.monthlySavingsProgress,
                    statusLabel: _savingsStatus(state),
                    footer:
                        '${(state.savingsRate * 100).clamp(-999, 999).round()}% da renda atual',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Referências',
              child: Column(
                children: [
                  _ReferenceRow(
                    icon: Icons.payments_rounded,
                    label: 'Receitas do mês',
                    value: CurrencyUtils.formatCents(state.currentIncomeCents),
                    color: context.colors.success,
                  ),
                  _ReferenceRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'Despesas do mês',
                    value: CurrencyUtils.formatCents(state.currentExpenseCents),
                    color: context.colors.danger,
                  ),
                  _ReferenceRow(
                    icon: Icons.calculate_rounded,
                    label: 'Média mensal recente',
                    value: CurrencyUtils.formatCents(
                      state.monthlyExpenseAverageCents,
                    ),
                    color: context.colors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reserveSubtitle(GoalsState state) {
    final account = state.emergencyReserveAccount;
    if (account != null) {
      return account.name;
    }
    if (state.emergencyReserveTargetCents > 0) {
      return 'Meta sugerida por média de gastos';
    }
    return 'Aguardando histórico financeiro';
  }

  String _reserveStatus(GoalsState state) {
    if (state.emergencyReserveTargetCents <= 0) {
      return 'A calcular';
    }
    if (state.emergencyReserveRemainingCents == 0) {
      return 'Completa';
    }
    if (state.emergencyReserveAccount == null) {
      return 'Sugerida';
    }
    return 'Em construção';
  }

  String _budgetStatus(GoalsState state) {
    if (state.plannedExpenseCents <= 0) {
      return 'Sem plano';
    }
    return state.availableBudgetCents >= 0 ? 'Dentro' : 'Acima';
  }

  String _budgetFooter(GoalsState state) {
    if (state.plannedExpenseCents <= 0) {
      return 'Crie um planejamento mensal para ativar esta meta';
    }
    if (state.availableBudgetCents >= 0) {
      return 'Disponível: ${CurrencyUtils.formatCents(state.availableBudgetCents)}';
    }
    return 'Estouro: ${CurrencyUtils.formatCents(-state.availableBudgetCents)}';
  }

  String _savingsStatus(GoalsState state) {
    if (state.monthlySavingsTargetCents <= 0) {
      return 'Sem receita';
    }
    if (state.monthlySavingsCents >= state.monthlySavingsTargetCents) {
      return 'Batida';
    }
    if (state.monthlySavingsCents < 0) {
      return 'Abaixo';
    }
    return 'Em evolução';
  }
}

Future<void> _openGoalForm(
  BuildContext context,
  WidgetRef ref, {
  AccountPreview? goal,
}) async {
  final viewModel = ref.read(goalsViewModelProvider.notifier);
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
        onSubmit: ({
          required String name,
          required int targetCents,
          required int initialBalanceCents,
          required bool includeInTotalBalance,
        }) async {
          if (goal == null) {
            await viewModel.createGoal(
              name: name,
              targetCents: targetCents,
              initialBalanceCents: initialBalanceCents,
              includeInTotalBalance: includeInTotalBalance,
            );
          } else {
            await viewModel.updateGoal(
              goal: goal,
              name: name,
              targetCents: targetCents,
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

Future<void> _openTransferToGoal(
  BuildContext context,
  AccountPreview goal,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => TransferFormSheet(initialToAccountId: goal.id),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transferência registrada.')),
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
            'Crie metas para separar dinheiro por objetivo.',
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
    required this.onEdit,
    required this.onTransfer,
  });

  final AccountPreview goal;
  final VoidCallback onEdit;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final targetCents = goal.emergencyReserveTargetCents ?? 0;
    final progress = targetCents <= 0
        ? 0.0
        : (goal.balanceCents / targetCents).clamp(0.0, 1.0).toDouble();
    final remainingCents =
        (targetCents - goal.balanceCents).clamp(0, targetCents).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: goal.color.withValues(alpha: 0.13),
                foregroundColor: goal.color,
                child: const Icon(Icons.flag_rounded),
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.includeInTotalBalance
                          ? 'Entra no saldo total'
                          : 'Fora do saldo total',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_GoalAction>(
                tooltip: 'Opções',
                onSelected: (action) {
                  switch (action) {
                    case _GoalAction.transfer:
                      onTransfer();
                      break;
                    case _GoalAction.edit:
                      onEdit();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _GoalAction.transfer,
                    child: Text('Transferir para meta'),
                  ),
                  PopupMenuItem(
                    value: _GoalAction.edit,
                    child: Text('Editar meta'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GoalValueBlock(
                  label: 'Guardado',
                  value: CurrencyUtils.formatCents(goal.balanceCents),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GoalValueBlock(
                  label: 'Meta',
                  value: targetCents > 0
                      ? CurrencyUtils.formatCents(targetCents)
                      : 'Sem valor',
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
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(goal.color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  targetCents > 0
                      ? remainingCents == 0
                          ? 'Meta alcançada'
                          : 'Faltam ${CurrencyUtils.formatCents(remainingCents)}'
                      : 'Defina um valor alvo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onTransfer,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Transferir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _GoalAction { transfer, edit }

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({
    required this.goal,
    required this.onSubmit,
  });

  final AccountPreview? goal;
  final Future<void> Function({
    required String name,
    required int targetCents,
    required int initialBalanceCents,
    required bool includeInTotalBalance,
  }) onSubmit;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _initialBalanceController;
  late bool _includeInTotalBalance;
  bool _isSubmitting = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal == null
          ? ''
          : _formatCentsForInput(goal.emergencyReserveTargetCents ?? 0),
    );
    _initialBalanceController = TextEditingController(
      text: goal == null ? '' : _formatCentsForInput(goal.balanceCents),
    );
    _includeInTotalBalance = goal?.includeInTotalBalance ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialBalanceController.dispose();
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
              if (!_isEditing) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _initialBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Saldo inicial',
                    hintText: 'Ex: 1000,00',
                    prefixIcon: Icon(Icons.savings_rounded),
                  ),
                  validator: _validateOptionalAmount,
                ),
              ],
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
        initialBalanceCents: _isEditing
            ? widget.goal!.balanceCents
            : CurrencyUtils.parseToCents(_initialBalanceController.text),
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

class _GoalsHeaderCard extends StatelessWidget {
  const _GoalsHeaderCard({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = state.overallProgress.clamp(0.0, 1.0).toDouble();
    final progressPercent = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
                  'Metas financeiras',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _HeaderBadge(label: state.monthLabel),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$progressPercent%',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            state.activeGoalsCount == 1
                ? '1 objetivo acompanhado'
                : '${state.activeGoalsCount} objetivos acompanhados',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _GoalMetrics extends StatelessWidget {
  const _GoalMetrics({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Saldo livre',
                value: CurrencyUtils.formatCents(state.monthlySavingsCents),
                icon: Icons.savings_rounded,
                color: context.colors.success,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Reserva',
                value: '${(state.emergencyReserveProgress * 100).round()}%',
                icon: Icons.shield_rounded,
                color: context.colors.primary,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Metas',
                value: CurrencyUtils.formatCents(state.goalBalanceCents),
                icon: Icons.flag_rounded,
                color: context.colors.info,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Progresso',
                value: '${(state.goalProgress * 100).round()}%',
                icon: Icons.track_changes_rounded,
                color: context.colors.warning,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
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
        borderRadius: BorderRadius.circular(20),
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
            backgroundColor: color.withValues(alpha: 0.13),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
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

class _GoalProgressTile extends StatelessWidget {
  const _GoalProgressTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.currentLabel,
    required this.targetLabel,
    required this.progress,
    required this.statusLabel,
    required this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String currentLabel;
  final String targetLabel;
  final double progress;
  final String statusLabel;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.13),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(label: statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GoalValueBlock(label: 'Atual', value: currentLabel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GoalValueBlock(label: 'Meta', value: targetLabel),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 9,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            footer,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _GoalValueBlock extends StatelessWidget {
  const _GoalValueBlock({
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.13),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
