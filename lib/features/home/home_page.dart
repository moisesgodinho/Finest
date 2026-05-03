import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/category_expense_preview.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/transaction_preview.dart';
import '../../shared/widgets/balance_card.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import '../../shared/widgets/section_card.dart';
import '../accounts/accounts_page.dart';
import '../cards/cards_page.dart';
import '../planning/planning_page.dart';
import '../pet/finance_pet_avatar.dart';
import '../pet/pet_view_model.dart';
import '../settings/settings_page.dart';
import 'card_expense_form_sheet.dart';
import 'expense_form_sheet.dart';
import 'home_view_model.dart';
import 'income_form_sheet.dart';
import 'transfer_form_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeDashboard(),
          AccountsPage(),
          PlanningPage(),
          CardsPage(),
          SettingsPage(),
        ],
      ),
      floatingActionButton: _currentIndex == 4
          ? null
          : FloatingActionButton(
              onPressed: _openCreateActionMenu,
              child: const Icon(Icons.add_rounded, size: 34),
            ),
      bottomNavigationBar: FinancePetBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Future<void> _openCreateActionMenu() async {
    final action = await showModalBottomSheet<_CreateAction>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _CreateActionTile(
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                  title: 'Receita',
                  subtitle: 'Entrada em conta',
                  action: _CreateAction.income,
                ),
                _CreateActionTile(
                  icon: Icons.remove_rounded,
                  color: AppColors.danger,
                  title: 'Despesa',
                  subtitle: 'Saída direto da conta',
                  action: _CreateAction.expense,
                ),
                _CreateActionTile(
                  icon: Icons.credit_card_rounded,
                  color: AppColors.info,
                  title: 'Despesa no cartão',
                  subtitle: 'Compra para a fatura',
                  action: _CreateAction.cardExpense,
                ),
                _CreateActionTile(
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.warning,
                  title: 'Transferência',
                  subtitle: 'Mover valor entre contas',
                  action: _CreateAction.transfer,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _CreateAction.income:
        await _openIncomeForm();
      case _CreateAction.expense:
        await _openExpenseForm();
      case _CreateAction.cardExpense:
        await _openCardExpenseForm();
      case _CreateAction.transfer:
        await _openTransferForm();
    }
  }

  Future<void> _openIncomeForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const IncomeFormSheet(),
    );

    if (mounted && saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receita salva.')),
      );
    }
  }

  Future<void> _openExpenseForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const ExpenseFormSheet(),
    );

    if (mounted && saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Despesa salva.')),
      );
    }
  }

  Future<void> _openCardExpenseForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const CardExpenseFormSheet(),
    );

    if (mounted && saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Despesa no cartão salva.')),
      );
    }
  }

  Future<void> _openTransferForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const TransferFormSheet(),
    );

    if (mounted && saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transferência salva.')),
      );
    }
  }
}

enum _CreateAction { income, expense, cardExpense, transfer }

class _CreateActionTile extends StatelessWidget {
  const _CreateActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final _CreateAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final petState = ref.watch(petViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final firstName = state.userName.split(' ').first;
    final colors = context.colors;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, $firstName',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.monthLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            BalanceCard(
              title: 'Saldo atual',
              value: CurrencyUtils.formatCents(state.currentBalanceCents),
              subtitle: state.balanceVariationLabel,
              isVisible: state.isBalanceVisible,
              onToggleVisibility: viewModel.toggleBalanceVisibility,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.trending_up_rounded,
                    title: 'Previsão no fim do mês',
                    value: CurrencyUtils.formatCents(
                      state.projectedBalanceCents,
                    ),
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Saldo no início',
                    value: CurrencyUtils.formatCents(
                      state.initialMonthBalanceCents,
                    ),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _FinancePetHomeCard(
              state: petState,
              onTap: () => context.push(AppRoutes.pet),
            ),
            const SizedBox(height: 18),
            _ResponsiveSummarySection(state: state),
            const SizedBox(height: 18),
            _CategoriesCard(
              categories: state.categories,
              onViewReport: () => context.push(AppRoutes.categories),
            ),
            const SizedBox(height: 18),
            _RecentTransactionsCard(transactions: state.recentTransactions),
            const SizedBox(height: 18),
            _QuickActions(onOpenInvestments: () {
              context.push(AppRoutes.investments);
            }),
          ],
        ),
      ),
    );
  }
}

class _FinancePetHomeCard extends StatelessWidget {
  const _FinancePetHomeCard({
    required this.state,
    required this.onTap,
  });

  final PetState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final streakLabel = state.contributionStreakMonths == 1
        ? '1 mês seguido'
        : '${state.contributionStreakMonths} meses seguidos';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.shadow
                    .withValues(alpha: colors.isDark ? 0.36 : 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              FinancePetAvatar(
                level: state.level,
                progress: state.progressToNextLevel,
                size: 96,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'FinancePet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Nv. ${state.level}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      state.currentLevel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: state.progressToNextLevel,
                        minHeight: 9,
                        backgroundColor: colors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${(state.savingsRate * 100).round()}% de taxa',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Text(
                          streakLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveSummarySection extends StatelessWidget {
  const _ResponsiveSummarySection({required this.state});

  static const double _tabletBreakpoint = 700;

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= _tabletBreakpoint;

        if (isTablet) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _MonthlySummaryCard(state: state)),
              const SizedBox(width: 12),
              Expanded(child: _CreditCardSummary(card: state.creditCard)),
            ],
          );
        }

        return Column(
          children: [
            _MonthlySummaryCard(state: state),
            const SizedBox(height: 18),
            _CreditCardSummary(card: state.creditCard),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      constraints: const BoxConstraints(minHeight: 126),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.10),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
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
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SectionCard(
      title: 'Resumo do mês',
      trailing: const _SectionAction(label: 'Detalhes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountLine(
            label: 'Receitas',
            value: CurrencyUtils.formatCents(state.incomeCents),
            color: AppColors.success,
            percent: state.incomeProgressPercent,
          ),
          const SizedBox(height: 12),
          _AmountLine(
            label: 'Despesas',
            value: CurrencyUtils.formatCents(state.expenseCents),
            color: AppColors.danger,
            percent: state.expenseProgressPercent,
          ),
          if (state.pendingIncomeCents > 0 ||
              state.totalPendingOutflowCents > 0) ...[
            const SizedBox(height: 16),
            _PendingSummary(
              pendingIncomeCents: state.pendingIncomeCents,
              pendingExpenseCents: state.pendingExpenseCents,
              creditCardInvoiceCents: state.creditCardInvoiceCents,
            ),
          ],
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Você possui ${(state.availableBudgetPercent * 100).round()}% do orçamento disponível',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });

  final String label;
  final String value;
  final Color color;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _PendingSummary extends StatelessWidget {
  const _PendingSummary({
    required this.pendingIncomeCents,
    required this.pendingExpenseCents,
    required this.creditCardInvoiceCents,
  });

  final int pendingIncomeCents;
  final int pendingExpenseCents;
  final int creditCardInvoiceCents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            if (pendingIncomeCents > 0)
              _PendingLine(
                icon: Icons.schedule_rounded,
                label: 'A receber',
                value: CurrencyUtils.formatCents(pendingIncomeCents),
                color: AppColors.success,
              ),
            if (pendingIncomeCents > 0 &&
                (pendingExpenseCents > 0 || creditCardInvoiceCents > 0))
              const SizedBox(height: 10),
            if (pendingExpenseCents > 0)
              _PendingLine(
                icon: Icons.event_busy_rounded,
                label: 'A pagar',
                value: CurrencyUtils.formatCents(pendingExpenseCents),
                color: AppColors.danger,
              ),
            if (pendingExpenseCents > 0 && creditCardInvoiceCents > 0)
              const SizedBox(height: 10),
            if (creditCardInvoiceCents > 0)
              _PendingLine(
                icon: Icons.credit_card_rounded,
                label: 'Faturas em aberto',
                value: CurrencyUtils.formatCents(creditCardInvoiceCents),
                color: AppColors.info,
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingLine extends StatelessWidget {
  const _PendingLine({
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
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _CreditCardSummary extends StatelessWidget {
  const _CreditCardSummary({required this.card});

  final CreditCardPreview card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (card.id == 0) {
      return SectionCard(
        title: 'CartÃ£o',
        trailing: const _SectionAction(label: 'Ver'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.accentSoft,
                foregroundColor: colors.primary,
                child: const Icon(Icons.credit_card_off_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cadastre um cartÃ£o para acompanhar fatura e limite.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Cartão',
      trailing: const _SectionAction(label: 'Ver'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primaryDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: card.color,
                  child: Text(
                    card.name.substring(0, 2).toLowerCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${card.name} •••• ${card.lastDigits}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Fatura atual',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.formatCents(card.invoiceCents),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: card.usedPercent,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vencimento dia ${card.dueDay}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({
    required this.categories,
    required this.onViewReport,
  });

  final List<CategoryExpensePreview> categories;
  final VoidCallback onViewReport;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Gastos por categoria',
      trailing: _SectionAction(
        label: 'Relatório',
        onTap: onViewReport,
      ),
      child: categories.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.pie_chart_outline_rounded,
              message: 'Os gastos por categoria aparecem apÃ³s lanÃ§amentos.',
            )
          : Column(
              children: [
                for (final category in categories) ...[
                  _CategoryRow(category: category),
                  if (category != categories.last) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: colors.textSecondary, size: 38),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final CategoryExpensePreview category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.12),
          foregroundColor: category.color,
          child: Icon(category.icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(CurrencyUtils.formatCents(category.amountCents)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: category.percent,
                  minHeight: 7,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(category.color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '${(category.percent * 100).round()}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: category.color,
                ),
          ),
        ),
      ],
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.transactions});

  final List<TransactionPreview> transactions;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Últimos lançamentos',
      trailing: _SectionAction(
        label: 'Ver todos',
        onTap: () => context.push(AppRoutes.transactions),
      ),
      child: transactions.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.receipt_long_outlined,
              message: 'Seus lanÃ§amentos recentes aparecerÃ£o aqui.',
            )
          : Column(
              children: [
                for (final transaction in transactions)
                  _TransactionTile(transaction: transaction),
              ],
            ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final TransactionPreview transaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = !transaction.isPaid
        ? AppColors.warning
        : transaction.isIncome
            ? AppColors.success
            : colors.textPrimary;
    final prefix = transaction.isIncome ? '+ ' : '- ';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: transaction.iconColor.withValues(alpha: 0.12),
            foregroundColor: transaction.iconColor,
            child: Icon(transaction.icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  transaction.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TransactionAmountDate(
            amount: CurrencyUtils.formatCents(transaction.amountCents),
            date: transaction.dateLabel ?? '',
            prefix: prefix,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _TransactionAmountDate extends StatelessWidget {
  const _TransactionAmountDate({
    required this.amount,
    required this.date,
    required this.prefix,
    required this.color,
  });

  final String amount;
  final String date;
  final String prefix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$prefix$amount',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenInvestments});

  final VoidCallback onOpenInvestments;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Ações rápidas',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _QuickActionButton(
            icon: Icons.add_rounded,
            label: 'Receita',
            color: AppColors.success,
            onTap: () {},
          ),
          _QuickActionButton(
            icon: Icons.remove_rounded,
            label: 'Despesa',
            color: AppColors.danger,
            onTap: () {},
          ),
          _QuickActionButton(
            icon: Icons.credit_card_rounded,
            label: 'Cartão',
            color: AppColors.info,
            onTap: () {},
          ),
          _QuickActionButton(
            icon: Icons.savings_rounded,
            label: 'Investir',
            color: AppColors.warning,
            onTap: onOpenInvestments,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 142,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color,
              foregroundColor: Colors.white,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
