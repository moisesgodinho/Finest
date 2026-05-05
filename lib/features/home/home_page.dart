import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/category_expense_preview.dart';
import '../../data/models/transaction_preview.dart';
import '../../data/models/transaction_series_scope.dart';
import '../../shared/widgets/balance_card.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import '../../shared/widgets/section_card.dart';
import '../accounts/accounts_page.dart';
import '../cards/cards_page.dart';
import '../planning/planning_page.dart';
import '../pet/finest_pet_avatar.dart';
import '../pet/pet_view_model.dart';
import '../settings/settings_page.dart';
import '../transactions/transactions_page.dart';
import '../transactions/transactions_view_model.dart';
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
      bottomNavigationBar: FinestBottomNavBar(
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
    final transactionsState = ref.watch(transactionsViewModelProvider);
    final pendingTransactions =
        _currentMonthPendingTransactions(transactionsState);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final firstName = state.userName.split(' ').first;
    final colors = context.colors;

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
              value: CurrencyUtils.formatCents(
                state.currentBalanceCents,
                currencyCode: state.currencyCode,
              ),
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
                      currencyCode: state.currencyCode,
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
                      currencyCode: state.currencyCode,
                    ),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _FinestHomeCard(
              state: petState,
              onTap: () => context.push(AppRoutes.pet),
            ),
            const SizedBox(height: 18),
            _ResponsiveSummarySection(
              state: state,
              pendingTransactions: pendingTransactions,
              onOpenPendingTransactions: () => _openPendingTransactionsSheet(
                context,
                ref,
                pendingTransactions,
              ),
            ),
            const SizedBox(height: 18),
            _CategoriesCard(
              categories: state.categories,
              currencyCode: state.currencyCode,
              onViewReport: () => context.push(AppRoutes.reports),
            ),
            const SizedBox(height: 18),
            _RecentTransactionsCard(transactions: state.recentTransactions),
          ],
        ),
      ),
    );
  }

  Future<void> _openPendingTransactionsSheet(
    BuildContext context,
    WidgetRef ref,
    List<TransactionListItem> transactions,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _PendingTransactionsSheet(
          transactions: transactions,
          onEdit: (transaction) async {
            Navigator.of(sheetContext).pop();
            if (!context.mounted) {
              return;
            }
            await _openPendingEditForm(context, ref, transaction);
          },
          onMarkAsPaid: (transaction) async {
            Navigator.of(sheetContext).pop();
            if (!context.mounted) {
              return;
            }
            await _confirmMarkPendingAsPaid(context, ref, transaction);
          },
          onDelete: (transaction) async {
            Navigator.of(sheetContext).pop();
            if (!context.mounted) {
              return;
            }
            await _confirmDeletePending(context, ref, transaction);
          },
        );
      },
    );
  }

  Future<void> _openPendingEditForm(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem transaction,
  ) async {
    final scope = await _selectPendingSeriesScope(
      context,
      transaction,
      actionLabel: 'editar',
    );
    if (scope == null || !context.mounted) {
      return;
    }

    final state = ref.read(transactionsViewModelProvider);
    final viewModel = ref.read(transactionsViewModelProvider.notifier);
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
        if (transaction.isTransfer) {
          return TransferEditFormSheet(
            transfer: transaction,
            accounts: state.accounts,
            onSubmit: ({
              required int fromAccountId,
              required int toAccountId,
              required String name,
              required int amountCents,
              required String transferKind,
              required DateTime dueDate,
              required bool isPaid,
              required DateTime date,
              int? totalInstallments,
            }) async {
              await viewModel.updateTransfer(
                transfer: transaction,
                fromAccountId: fromAccountId,
                toAccountId: toAccountId,
                name: name,
                amountCents: amountCents,
                transferKind: transferKind,
                dueDate: dueDate,
                isPaid: isPaid,
                date: date,
                totalInstallments: totalInstallments,
                scope: scope,
              );
            },
          );
        }

        return TransactionEditFormSheet(
          transaction: transaction,
          accounts: state.accounts,
          categories: state.categories,
          subcategories: state.subcategories,
          onSubmit: ({
            required int accountId,
            required int categoryId,
            required String type,
            required String description,
            required int amountCents,
            required DateTime? dueDate,
            required DateTime date,
            required bool isPaid,
            int? subcategoryId,
            String? transactionKind,
            int? totalInstallments,
          }) async {
            await viewModel.updateTransaction(
              transaction: transaction,
              accountId: accountId,
              categoryId: categoryId,
              type: type,
              description: description,
              amountCents: amountCents,
              dueDate: dueDate,
              date: date,
              isPaid: isPaid,
              subcategoryId: subcategoryId,
              transactionKind: transactionKind,
              totalInstallments: totalInstallments,
              scope: scope,
            );
          },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pendência atualizada.')),
      );
    }
  }

  Future<void> _confirmMarkPendingAsPaid(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Efetivar pendência?'),
          content: Text(
            transaction.isTransfer
                ? 'O valor será movimentado entre as contas.'
                : 'O saldo da conta será atualizado automaticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Efetivar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(transactionsViewModelProvider.notifier)
          .markItemAsPaid(transaction);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pendência efetivada.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _confirmDeletePending(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem transaction,
  ) async {
    final scope = await _selectPendingSeriesScope(
      context,
      transaction,
      actionLabel: 'excluir',
    );
    if (scope == null || !context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir pendência?'),
          content: const Text('Esta ação remove o lançamento previsto.'),
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
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(transactionsViewModelProvider.notifier)
          .deleteItem(transaction, scope: scope);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pendência excluída.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<TransactionSeriesScope?> _selectPendingSeriesScope(
    BuildContext context,
    TransactionListItem transaction, {
    required String actionLabel,
  }) async {
    if (!transaction.supportsSeriesScope) {
      return TransactionSeriesScope.current;
    }

    return showModalBottomSheet<TransactionSeriesScope>(
      context: context,
      useSafeArea: true,
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
                  'Aplicar ao $actionLabel',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha quais parcelas devem receber esta alteração.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
                const SizedBox(height: 14),
                _PendingSeriesScopeTile(
                  icon: Icons.event_rounded,
                  title: 'Somente este mês',
                  subtitle: 'Aplica apenas na parcela selecionada.',
                  onTap: () => Navigator.of(context).pop(
                    TransactionSeriesScope.current,
                  ),
                ),
                _PendingSeriesScopeTile(
                  icon: Icons.update_rounded,
                  title: 'Este mês e próximos',
                  subtitle: 'Aplica desta parcela em diante.',
                  onTap: () => Navigator.of(context).pop(
                    TransactionSeriesScope.currentAndFuture,
                  ),
                ),
                _PendingSeriesScopeTile(
                  icon: Icons.all_inclusive_rounded,
                  title: 'Todas as parcelas',
                  subtitle: 'Inclui parcelas anteriores e futuras.',
                  onTap: () => Navigator.of(context).pop(
                    TransactionSeriesScope.all,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingSeriesScopeTile extends StatelessWidget {
  const _PendingSeriesScopeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colors.accentSoft,
        foregroundColor: colors.primary,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _FinestHomeCard extends StatelessWidget {
  const _FinestHomeCard({
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
              FinestPetAvatar(
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
                            'Finest',
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
  const _ResponsiveSummarySection({
    required this.state,
    required this.pendingTransactions,
    required this.onOpenPendingTransactions,
  });

  static const double _tabletBreakpoint = 700;

  final HomeState state;
  final List<TransactionListItem> pendingTransactions;
  final VoidCallback onOpenPendingTransactions;

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
              Expanded(
                child: _PendingTransactionsCard(
                  transactions: pendingTransactions,
                  currencyCode: state.currencyCode,
                  onTap: onOpenPendingTransactions,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _MonthlySummaryCard(state: state),
            const SizedBox(height: 18),
            _PendingTransactionsCard(
              transactions: pendingTransactions,
              currencyCode: state.currencyCode,
              onTap: onOpenPendingTransactions,
            ),
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
            value: CurrencyUtils.formatCents(
              state.incomeCents,
              currencyCode: state.currencyCode,
            ),
            color: AppColors.success,
            percent: state.incomeProgressPercent,
          ),
          const SizedBox(height: 12),
          _AmountLine(
            label: 'Despesas',
            value: CurrencyUtils.formatCents(
              state.expenseCents,
              currencyCode: state.currencyCode,
            ),
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
              currencyCode: state.currencyCode,
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
    required this.currencyCode,
  });

  final int pendingIncomeCents;
  final int pendingExpenseCents;
  final int creditCardInvoiceCents;
  final String currencyCode;

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
                value: CurrencyUtils.formatCents(
                  pendingIncomeCents,
                  currencyCode: currencyCode,
                ),
                color: AppColors.success,
              ),
            if (pendingIncomeCents > 0 &&
                (pendingExpenseCents > 0 || creditCardInvoiceCents > 0))
              const SizedBox(height: 10),
            if (pendingExpenseCents > 0)
              _PendingLine(
                icon: Icons.event_busy_rounded,
                label: 'A pagar',
                value: CurrencyUtils.formatCents(
                  pendingExpenseCents,
                  currencyCode: currencyCode,
                ),
                color: AppColors.danger,
              ),
            if (pendingExpenseCents > 0 && creditCardInvoiceCents > 0)
              const SizedBox(height: 10),
            if (creditCardInvoiceCents > 0)
              _PendingLine(
                icon: Icons.credit_card_rounded,
                label: 'Faturas em aberto',
                value: CurrencyUtils.formatCents(
                  creditCardInvoiceCents,
                  currencyCode: currencyCode,
                ),
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

class _PendingTransactionsCard extends StatelessWidget {
  const _PendingTransactionsCard({
    required this.transactions,
    required this.currencyCode,
    required this.onTap,
  });

  final List<TransactionListItem> transactions;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pendingIncomeCents = _pendingIncomeCents(transactions);
    final pendingExpenseCents = _pendingExpenseCents(transactions);
    final pendingTransferCents = _pendingTransferCents(transactions);
    final totalPendingCents = _pendingTotalCents(transactions);

    return SectionCard(
      title: 'Transações pendentes',
      trailing: _SectionAction(
        label: 'Ver',
        onTap: transactions.isEmpty ? null : onTap,
      ),
      child: transactions.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.fact_check_outlined,
              message:
                  'Nenhuma receita, despesa ou transferência pendente neste mês.',
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                colors.warning.withValues(alpha: 0.12),
                            foregroundColor: colors.warning,
                            child: const Icon(Icons.pending_actions_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyUtils.formatCents(
                                    totalPendingCents,
                                    currencyCode: currencyCode,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: colors.warning),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${transactions.length} pendências no mês',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (pendingIncomeCents > 0)
                            _PendingChip(
                              label: 'A receber',
                              value: CurrencyUtils.formatCents(
                                pendingIncomeCents,
                                currencyCode: currencyCode,
                              ),
                              color: AppColors.success,
                            ),
                          if (pendingExpenseCents > 0)
                            _PendingChip(
                              label: 'A pagar',
                              value: CurrencyUtils.formatCents(
                                pendingExpenseCents,
                                currencyCode: currencyCode,
                              ),
                              color: AppColors.danger,
                            ),
                          if (pendingTransferCents > 0)
                            _PendingChip(
                              label: 'Transferências',
                              value: CurrencyUtils.formatCents(
                                pendingTransferCents,
                                currencyCode: currencyCode,
                              ),
                              color: AppColors.info,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (final transaction in transactions.take(3)) ...[
                        _PendingPreviewRow(transaction: transaction),
                        if (transaction != transactions.take(3).last)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _PendingPreviewRow extends StatelessWidget {
  const _PendingPreviewRow({required this.transaction});

  final TransactionListItem transaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amountColor = transaction.isIncome
        ? AppColors.success
        : transaction.isTransfer
            ? AppColors.info
            : colors.textPrimary;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: transaction.iconColor.withValues(alpha: 0.12),
          foregroundColor: transaction.iconColor,
          child: Icon(transaction.icon, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                _pendingSubtitle(transaction),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _amountWithPrefix(transaction),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({
    required this.categories,
    required this.currencyCode,
    required this.onViewReport,
  });

  final List<CategoryExpensePreview> categories;
  final String currencyCode;
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
              message: 'Os gastos por categoria aparecem após lançamentos.',
            )
          : Column(
              children: [
                for (final category in categories) ...[
                  _CategoryRow(
                    category: category,
                    currencyCode: currencyCode,
                  ),
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
  const _CategoryRow({
    required this.category,
    required this.currencyCode,
  });

  final CategoryExpensePreview category;
  final String currencyCode;

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
                  Text(
                    CurrencyUtils.formatCents(
                      category.amountCents,
                      currencyCode: currencyCode,
                    ),
                  ),
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
              message: 'Seus lançamentos recentes aparecerão aqui.',
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
            amount: CurrencyUtils.formatCents(
              transaction.amountCents,
              currencyCode: transaction.currencyCode,
            ),
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

class _PendingTransactionsSheet extends StatelessWidget {
  const _PendingTransactionsSheet({
    required this.transactions,
    required this.onEdit,
    required this.onMarkAsPaid,
    required this.onDelete,
  });

  final List<TransactionListItem> transactions;
  final ValueChanged<TransactionListItem> onEdit;
  final ValueChanged<TransactionListItem> onMarkAsPaid;
  final ValueChanged<TransactionListItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: transactions.length > 5 ? 0.72 : 0.56,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pendências do mês',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${transactions.length} itens',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (transactions.isEmpty)
              const _EmptySectionMessage(
                icon: Icons.fact_check_outlined,
                message: 'Nenhuma pendência para este mês.',
              )
            else
              for (final transaction in transactions) ...[
                _PendingTransactionTile(
                  transaction: transaction,
                  onEdit: () => onEdit(transaction),
                  onMarkAsPaid: () => onMarkAsPaid(transaction),
                  onDelete: () => onDelete(transaction),
                ),
                if (transaction != transactions.last) const Divider(height: 18),
              ],
          ],
        );
      },
    );
  }
}

class _PendingTransactionTile extends StatelessWidget {
  const _PendingTransactionTile({
    required this.transaction,
    required this.onEdit,
    required this.onMarkAsPaid,
    required this.onDelete,
  });

  final TransactionListItem transaction;
  final VoidCallback onEdit;
  final VoidCallback onMarkAsPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amountColor = transaction.isIncome
        ? AppColors.success
        : transaction.isTransfer
            ? AppColors.info
            : colors.textPrimary;
    final dueDate = _pendingReferenceDate(transaction);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: transaction.iconColor.withValues(alpha: 0.12),
        foregroundColor: transaction.iconColor,
        child: Icon(transaction.icon, size: 20),
      ),
      title: Text(
        transaction.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _pendingSubtitle(transaction),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isOverdue(transaction)) ...[
            const SizedBox(height: 3),
            Text(
              'Vencida',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TransactionAmountDate(
            amount: CurrencyUtils.formatCents(
              transaction.amountCents,
              currencyCode: transaction.currencyCode,
            ),
            date: _formatShortDate(dueDate),
            prefix: _amountPrefix(transaction),
            color: amountColor,
          ),
          PopupMenuButton<_PendingTransactionAction>(
            tooltip: 'Opções',
            onSelected: (action) {
              switch (action) {
                case _PendingTransactionAction.edit:
                  onEdit();
                  break;
                case _PendingTransactionAction.markAsPaid:
                  onMarkAsPaid();
                  break;
                case _PendingTransactionAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PendingTransactionAction.edit,
                child: Text('Editar'),
              ),
              PopupMenuItem(
                value: _PendingTransactionAction.markAsPaid,
                child: Text('Efetivar'),
              ),
              PopupMenuItem(
                value: _PendingTransactionAction.delete,
                child: Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PendingTransactionAction { edit, markAsPaid, delete }

List<TransactionListItem> _currentMonthPendingTransactions(
  TransactionsState state,
) {
  final now = DateTime.now();
  final transactions = state.transactions.where((transaction) {
    if (transaction.isPaid || transaction.isCreditCard) {
      return false;
    }
    return _isSameMonth(_pendingReferenceDate(transaction), now);
  }).toList()
    ..sort((a, b) {
      final dateCompare =
          _pendingReferenceDate(a).compareTo(_pendingReferenceDate(b));
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.title.compareTo(b.title);
    });

  return transactions;
}

int _pendingIncomeCents(List<TransactionListItem> transactions) {
  return transactions.where((transaction) => transaction.isIncome).fold<int>(
        0,
        (total, transaction) => total + transaction.summaryAmountCents,
      );
}

int _pendingExpenseCents(List<TransactionListItem> transactions) {
  return transactions
      .where(
        (transaction) => transaction.isExpense && !transaction.isCreditCard,
      )
      .fold<int>(
        0,
        (total, transaction) => total + transaction.summaryAmountCents,
      );
}

int _pendingTransferCents(List<TransactionListItem> transactions) {
  return transactions.where((transaction) => transaction.isTransfer).fold<int>(
        0,
        (total, transaction) => total + transaction.summaryAmountCents,
      );
}

int _pendingTotalCents(List<TransactionListItem> transactions) {
  return transactions.fold<int>(
    0,
    (total, transaction) => total + transaction.summaryAmountCents,
  );
}

DateTime _pendingReferenceDate(TransactionListItem transaction) {
  return transaction.dueDate ?? transaction.date;
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.month == right.month && left.year == right.year;
}

bool _isOverdue(TransactionListItem transaction) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = _pendingReferenceDate(transaction);
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  return dueDay.isBefore(today);
}

String _pendingSubtitle(TransactionListItem transaction) {
  if (transaction.isTransfer) {
    return '${transaction.accountName} -> ${transaction.toAccountName ?? 'Conta removida'}';
  }

  final category = transaction.subcategoryName == null
      ? transaction.categoryName
      : '${transaction.categoryName} · ${transaction.subcategoryName}';
  return '$category · ${transaction.accountName}';
}

String _amountPrefix(TransactionListItem transaction) {
  if (transaction.isIncome) {
    return '+ ';
  }
  if (transaction.isTransfer) {
    return '';
  }
  return '- ';
}

String _amountWithPrefix(TransactionListItem transaction) {
  return '${_amountPrefix(transaction)}${CurrencyUtils.formatCents(
    transaction.amountCents,
    currencyCode: transaction.currencyCode,
  )}';
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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
