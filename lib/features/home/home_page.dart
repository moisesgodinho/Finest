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
import '../settings/settings_page.dart';
import 'home_view_model.dart';

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
              onPressed: () => context.push(AppRoutes.transactions),
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
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final firstName = state.userName.split(' ').first;

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
                              color: AppColors.textSecondary,
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
              subtitle: '↑ 12,6% vs. mês anterior',
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
            _ResponsiveSummarySection(state: state),
            const SizedBox(height: 18),
            _CategoriesCard(categories: state.categories),
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
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            percent: 0.78,
          ),
          const SizedBox(height: 12),
          _AmountLine(
            label: 'Despesas',
            value: CurrencyUtils.formatCents(state.expenseCents),
            color: AppColors.danger,
            percent: 0.49,
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Você possui ${(state.availableBudgetPercent * 100).round()}% do orçamento disponível',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
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
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
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
    return SectionCard(
      title: 'Cartão',
      trailing: const _SectionAction(label: 'Ver'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
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
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryLight,
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
  const _CategoriesCard({required this.categories});

  final List<CategoryExpensePreview> categories;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Gastos por categoria',
      trailing: const _SectionAction(label: 'Relatório'),
      child: Column(
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final CategoryExpensePreview category;

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: AppColors.border,
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
      trailing: const _SectionAction(label: 'Ver todos'),
      child: Column(
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
    final color =
        transaction.isIncome ? AppColors.success : AppColors.textPrimary;
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
          Text(
            '$prefix${CurrencyUtils.formatCents(transaction.amountCents)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
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
                      color: AppColors.textPrimary,
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
  const _SectionAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ],
    );
  }
}
