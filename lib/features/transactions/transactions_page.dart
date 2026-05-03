import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/subcategory_model.dart';
import '../../shared/widgets/section_card.dart';
import 'transactions_view_model.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionsViewModelProvider);
    final viewModel = ref.read(transactionsViewModelProvider.notifier);

    ref.listen(
      transactionsViewModelProvider.select((state) => state.errorMessage),
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
        title: const Text('Transações'),
        actions: [
          IconButton(
            tooltip: 'Selecionar mês',
            onPressed: () =>
                _pickMonth(context, viewModel, state.selectedMonth),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      floatingActionButton: state.accounts.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openTransactionForm(context, ref),
              child: const Icon(Icons.add_rounded, size: 34),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
          children: [
            if (state.isLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            _MonthSelector(
              label: state.monthLabel,
              onPrevious: viewModel.selectPreviousMonth,
              onNext: viewModel.selectNextMonth,
            ),
            const SizedBox(height: 14),
            _SummaryGrid(summary: state.summary),
            const SizedBox(height: 14),
            _FilterPanel(
              state: state,
              onSearchChanged: viewModel.search,
              onTypeChanged: viewModel.selectType,
              onAccountChanged: viewModel.selectAccount,
              onCategoryChanged: viewModel.selectCategory,
              onCreditCardChanged: viewModel.selectCreditCard,
              onClear: viewModel.clearFilters,
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Extrato',
              trailing: Text(
                '${state.filteredTransactions.length} itens',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              child: state.accounts.isEmpty
                  ? const _NoAccountsMessage()
                  : state.filteredTransactions.isEmpty
                      ? const _EmptyTransactionsMessage()
                      : Column(
                          children: [
                            for (final group in state.groupedTransactions)
                              _TransactionDaySection(
                                group: group,
                                onOpen: (transaction) => _openTransactionDetail(
                                  context,
                                  ref,
                                  viewModel,
                                  transaction,
                                ),
                                onEdit: (transaction) => _openEditForm(
                                  context,
                                  ref,
                                  transaction,
                                ),
                                onMarkAsPaid: (transaction) =>
                                    _confirmMarkAsPaid(
                                  context,
                                  viewModel,
                                  transaction,
                                ),
                                onDelete: (transaction) => _confirmDelete(
                                  context,
                                  viewModel,
                                  transaction,
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

  Future<void> _pickMonth(
    BuildContext context,
    TransactionsViewModel viewModel,
    DateTime selectedMonth,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecione uma data do mês',
    );
    if (picked != null) {
      viewModel.selectMonth(picked);
    }
  }

  Future<void> _openTransactionForm(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
        return _TransactionFormSheet(
          accounts: state.accounts,
          categories: state.categories,
          onSubmit: ({
            required int accountId,
            required int categoryId,
            required String type,
            required String description,
            required int amountCents,
            required DateTime dueDate,
            required DateTime date,
            required bool isPaid,
          }) async {
            await viewModel.createTransaction(
              accountId: accountId,
              categoryId: categoryId,
              type: type,
              description: description,
              amountCents: amountCents,
              dueDate: dueDate,
              date: date,
              isPaid: isPaid,
            );
          },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Lançamento registrado.')),
      );
    }
  }

  Future<void> _openTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    TransactionsViewModel viewModel,
    TransactionListItem transaction,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _TransactionDetailSheet(
          transaction: transaction,
          onEdit: transaction.isCreditCard
              ? null
              : () async {
                  Navigator.of(context).pop();
                  await _openEditForm(context, ref, transaction);
                },
          onMarkAsPaid: transaction.isPaid
              ? null
              : () async {
                  Navigator.of(context).pop();
                  await _confirmMarkAsPaid(context, viewModel, transaction);
                },
          onDelete: () async {
            Navigator.of(context).pop();
            await _confirmDelete(context, viewModel, transaction);
          },
        );
      },
    );
  }

  Future<void> _openEditForm(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem transaction,
  ) async {
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
          return _TransferEditFormSheet(
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
              );
            },
          );
        }

        return _TransactionEditFormSheet(
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
            );
          },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Lançamento atualizado.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionsViewModel viewModel,
    TransactionListItem transaction,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover lançamento?'),
          content: Text(
            transaction.isTransfer
                ? 'As contas da transferência serão ajustadas automaticamente.'
                : 'O saldo da conta ou a fatura serão ajustados automaticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await viewModel.deleteItem(transaction);
    }
  }

  Future<void> _confirmMarkAsPaid(
    BuildContext context,
    TransactionsViewModel viewModel,
    TransactionListItem transaction,
  ) async {
    final shouldMark = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Efetivar lançamento?'),
          content: Text(
            transaction.isTransfer
                ? 'O valor sairá da origem e entrará na conta de destino.'
                : 'O saldo da conta ou a fatura serão atualizados automaticamente.',
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

    if (shouldMark == true) {
      await viewModel.markItemAsPaid(transaction);
    }
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final TransactionSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.75 : 1.45,
          children: [
            _SummaryTile(
              title: 'Receitas',
              value: CurrencyUtils.formatCents(summary.incomeCents),
              icon: Icons.arrow_downward_rounded,
              color: AppColors.success,
            ),
            _SummaryTile(
              title: 'Despesas',
              value: CurrencyUtils.formatCents(summary.accountExpenseCents),
              icon: Icons.arrow_upward_rounded,
              color: context.colors.danger,
            ),
            _SummaryTile(
              title: 'Cartão',
              value: CurrencyUtils.formatCents(summary.cardExpenseCents),
              icon: Icons.credit_card_rounded,
              color: context.colors.purple,
            ),
            _SummaryTile(
              title: 'Previstos',
              value: CurrencyUtils.formatCents(summary.pendingCents),
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(icon, size: 19),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.state,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onAccountChanged,
    required this.onCategoryChanged,
    required this.onCreditCardChanged,
    required this.onClear,
  });

  final TransactionsState state;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int?> onAccountChanged;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onCreditCardChanged;
  final VoidCallback onClear;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.searchQuery != _searchController.text) {
      _searchController.value = TextEditingValue(
        text: widget.state.searchQuery,
        selection: TextSelection.collapsed(
          offset: widget.state.searchQuery.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return SectionCard(
      title: 'Filtros',
      trailing: state.hasActiveFilters
          ? TextButton(
              onPressed: widget.onClear,
              child: const Text('Limpar'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Buscar',
              hintText: 'Nome, conta, categoria ou cartão',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: TransactionFilters.all,
                  label: Text('Todos'),
                  icon: Icon(Icons.list_alt_rounded),
                ),
                ButtonSegment(
                  value: TransactionFilters.income,
                  label: Text('Receitas'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: TransactionFilters.expense,
                  label: Text('Despesas'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: TransactionFilters.creditCard,
                  label: Text('Cartão'),
                  icon: Icon(Icons.credit_card_rounded),
                ),
                ButtonSegment(
                  value: TransactionFilters.transfer,
                  label: Text('Transferências'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
                ButtonSegment(
                  value: TransactionFilters.pending,
                  label: Text('Previstos'),
                  icon: Icon(Icons.schedule_rounded),
                ),
              ],
              selected: {state.selectedType},
              onSelectionChanged: (selection) {
                widget.onTypeChanged(selection.first);
              },
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final width = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _OptionDropdown(
                      label: 'Conta',
                      icon: Icons.account_balance_wallet_rounded,
                      value: state.selectedAccountId,
                      options: [
                        for (final account in state.accounts)
                          TransactionFilterOption(
                            id: account.id,
                            label: account.name,
                          ),
                      ],
                      onChanged: widget.onAccountChanged,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _OptionDropdown(
                      label: 'Categoria',
                      icon: Icons.category_rounded,
                      value: state.selectedCategoryId,
                      options: [
                        for (final category in state.filterCategories)
                          TransactionFilterOption(
                            id: category.id,
                            label: category.name,
                          ),
                      ],
                      onChanged: widget.onCategoryChanged,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _OptionDropdown(
                      label: 'Cartão',
                      icon: Icons.credit_card_rounded,
                      value: state.selectedCreditCardId,
                      options: state.creditCards,
                      onChanged: widget.onCreditCardChanged,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int? value;
  final List<TransactionFilterOption> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    const allValue = -1;

    return DropdownButtonFormField<int>(
      key: ValueKey('$label-${value ?? allValue}-${options.length}'),
      initialValue: value ?? allValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: [
        const DropdownMenuItem(
          value: allValue,
          child: Text('Todos'),
        ),
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (selected) {
        onChanged(selected == allValue ? null : selected);
      },
    );
  }
}

class _NoAccountsMessage extends StatelessWidget {
  const _NoAccountsMessage();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Cadastre uma conta primeiro.',
      subtitle: 'Os lançamentos precisam estar vinculados a uma conta local.',
    );
  }
}

class _EmptyTransactionsMessage extends StatelessWidget {
  const _EmptyTransactionsMessage();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.receipt_long_outlined,
      title: 'Nenhum lançamento encontrado.',
      subtitle: 'Ajuste os filtros ou adicione uma nova movimentação.',
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(icon, color: colors.textSecondary, size: 46),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TransactionDaySection extends StatelessWidget {
  const _TransactionDaySection({
    required this.group,
    required this.onOpen,
    required this.onEdit,
    required this.onMarkAsPaid,
    required this.onDelete,
  });

  final TransactionDayGroup group;
  final ValueChanged<TransactionListItem> onOpen;
  final ValueChanged<TransactionListItem> onEdit;
  final ValueChanged<TransactionListItem> onMarkAsPaid;
  final ValueChanged<TransactionListItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDateLong(group.date),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          for (final transaction in group.items)
            _TransactionTile(
              transaction: transaction,
              onTap: () => onOpen(transaction),
              onEdit:
                  transaction.isCreditCard ? null : () => onEdit(transaction),
              onMarkAsPaid:
                  transaction.isPaid ? null : () => onMarkAsPaid(transaction),
              onDelete: () => onDelete(transaction),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onTap,
    required this.onEdit,
    required this.onMarkAsPaid,
    required this.onDelete,
  });

  final TransactionListItem transaction;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onMarkAsPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amountColor = _amountColor(context, transaction);
    final amountPrefix = _amountPrefix(transaction);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (!transaction.isPaid) const _SmallStatusBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(transaction),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (transaction.kindLabel != null ||
                        transaction.installmentNumber != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _detailsLabel(transaction),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TransactionAmountDate(
                amount: CurrencyUtils.formatCents(transaction.amountCents),
                date: _formatDateShort(transaction.date),
                prefix: amountPrefix,
                color: amountColor,
              ),
              PopupMenuButton<String>(
                tooltip: 'Ações',
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit?.call();
                  } else if (value == 'pay') {
                    onMarkAsPaid?.call();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar'),
                    ),
                  if (onMarkAsPaid != null)
                    const PopupMenuItem(
                      value: 'pay',
                      child: Text('Efetivar'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remover'),
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

class _SmallStatusBadge extends StatelessWidget {
  const _SmallStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Previsto',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w900,
            ),
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
      constraints: const BoxConstraints(maxWidth: 112),
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
                  fontWeight: FontWeight.w900,
                ),
          ),
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
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    required this.transaction,
    required this.onEdit,
    required this.onMarkAsPaid,
    required this.onDelete,
  });

  final TransactionListItem transaction;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onMarkAsPaid;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amountColor = _amountColor(context, transaction);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      transaction.iconColor.withValues(alpha: 0.12),
                  foregroundColor: transaction.iconColor,
                  child: Icon(transaction.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transaction.isPaid ? 'Efetivado' : 'Previsto',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '${_amountPrefix(transaction)}${CurrencyUtils.formatCents(transaction.amountCents)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Data', value: _formatDate(transaction.date)),
            if (transaction.dueDate != null)
              _DetailRow(
                label: 'Vencimento',
                value: _formatDate(transaction.dueDate!),
              ),
            _DetailRow(label: 'Tipo', value: _typeLabel(transaction)),
            _DetailRow(label: 'Meio', value: transaction.paymentMethodLabel),
            if (transaction.isTransfer) ...[
              _DetailRow(label: 'Origem', value: transaction.accountName),
              _DetailRow(
                label: 'Destino',
                value: transaction.toAccountName ?? 'Conta removida',
              ),
            ] else ...[
              _DetailRow(label: 'Conta', value: transaction.accountName),
              _DetailRow(label: 'Categoria', value: transaction.categoryName),
              if (transaction.subcategoryName != null)
                _DetailRow(
                  label: 'Subcategoria',
                  value: transaction.subcategoryName!,
                ),
              if (transaction.creditCardName != null)
                _DetailRow(label: 'Cartão', value: transaction.creditCardName!),
              if (transaction.invoiceMonth != null &&
                  transaction.invoiceYear != null)
                _DetailRow(
                  label: 'Fatura',
                  value:
                      '${transaction.invoiceMonth.toString().padLeft(2, '0')}/${transaction.invoiceYear}',
                ),
            ],
            if (transaction.kindLabel != null)
              _DetailRow(label: 'Recorrência', value: transaction.kindLabel!),
            if (transaction.installmentNumber != null &&
                transaction.totalInstallments != null)
              _DetailRow(
                label: 'Parcela',
                value:
                    '${transaction.installmentNumber}/${transaction.totalInstallments}',
              ),
            const SizedBox(height: 20),
            if (onEdit != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (onMarkAsPaid != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onMarkAsPaid,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Efetivar lançamento'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
                label: Text(
                  'Remover',
                  style: TextStyle(color: colors.danger),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionEditFormSheet extends StatefulWidget {
  const _TransactionEditFormSheet({
    required this.transaction,
    required this.accounts,
    required this.categories,
    required this.subcategories,
    required this.onSubmit,
  });

  final TransactionListItem transaction;
  final List<AccountPreview> accounts;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final Future<void> Function({
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
  }) onSubmit;

  @override
  State<_TransactionEditFormSheet> createState() =>
      _TransactionEditFormSheetState();
}

class _TransactionEditFormSheetState extends State<_TransactionEditFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _installmentsController;
  late String _type;
  late String _kind;
  int? _accountId;
  int? _categoryId;
  int? _subcategoryId;
  late DateTime _dueDate;
  late DateTime _date;
  late bool _isPaid;
  bool _isSubmitting = false;

  List<CategoryModel> get _availableCategories {
    return widget.categories
        .where((category) => category.type == _type)
        .toList();
  }

  List<SubcategoryModel> get _availableSubcategories {
    final categoryId = _categoryId;
    if (categoryId == null) {
      return const [];
    }
    return widget.subcategories
        .where((subcategory) => subcategory.categoryId == categoryId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _descriptionController = TextEditingController(text: transaction.title);
    _amountController = TextEditingController(
      text: _formatCentsForInput(transaction.amountCents),
    );
    _installmentsController = TextEditingController(
      text: transaction.totalInstallments?.toString() ?? '',
    );
    _type = transaction.type == TransactionFilters.income
        ? TransactionFilters.income
        : TransactionFilters.expense;
    _kind = transaction.kindCode ?? 'single';
    _accountId =
        widget.accounts.any((account) => account.id == transaction.accountId)
            ? transaction.accountId
            : widget.accounts.isEmpty
                ? null
                : widget.accounts.first.id;
    _categoryId = _availableCategories
            .any((category) => category.id == transaction.categoryId)
        ? transaction.categoryId
        : _availableCategories.isEmpty
            ? null
            : _availableCategories.first.id;
    _subcategoryId = _availableSubcategories
            .any((subcategory) => subcategory.id == transaction.subcategoryId)
        ? transaction.subcategoryId
        : null;
    _dueDate = transaction.dueDate ?? transaction.date;
    _date = transaction.date;
    _isPaid = transaction.isPaid;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _availableCategories;
    if (_categoryId == null ||
        !categories.any((category) => category.id == _categoryId)) {
      _categoryId = categories.isEmpty ? null : categories.first.id;
      _subcategoryId = null;
    }

    final subcategories = _availableSubcategories;
    if (_subcategoryId != null &&
        !subcategories.any((subcategory) => subcategory.id == _subcategoryId)) {
      _subcategoryId = null;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar lançamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: TransactionFilters.expense,
                    label: Text('Despesa'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionFilters.income,
                    label: Text('Receita'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() {
                    _type = selection.first;
                    _categoryId = _availableCategories.isEmpty
                        ? null
                        : _availableCategories.first.id;
                    _subcategoryId = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe uma descrição.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Conta',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
                validator: (value) {
                  if (value == null) {
                    return 'Selecione uma conta.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: ValueKey('edit-category-$_type-${categories.length}'),
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;
                    _subcategoryId = null;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecione uma categoria.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: ValueKey(
                  'edit-subcategory-${_categoryId ?? 0}-${subcategories.length}',
                ),
                initialValue: _subcategoryId ?? -1,
                decoration: const InputDecoration(
                  labelText: 'Subcategoria',
                  prefixIcon: Icon(Icons.sell_rounded),
                ),
                items: [
                  const DropdownMenuItem(value: -1, child: Text('Nenhuma')),
                  for (final subcategory in subcategories)
                    DropdownMenuItem(
                      value: subcategory.id,
                      child: Text(subcategory.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _subcategoryId = value == -1 ? null : value);
                },
              ),
              const SizedBox(height: 14),
              _KindSelector(
                value: _kind,
                onChanged: (value) => setState(() => _kind = value),
              ),
              if (_kind == 'installment') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _installmentsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total de parcelas',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                  validator: _validateInstallments,
                ),
              ],
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(isDueDate: true),
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de vencimento',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                  child: Text(_formatDate(_dueDate)),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isDueDate: false),
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text('Data: ${_formatDate(_date)}'),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPaid,
                title: const Text('Pagamento efetivado'),
                subtitle: Text(
                  _isPaid
                      ? 'Mantém o impacto no saldo ao salvar.'
                      : 'Remove do saldo e deixa como previsto.',
                ),
                onChanged: (value) => setState(() => _isPaid = value),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar edição'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final currentDate = isDueDate ? _dueDate : _date;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = selectedDate;
        } else {
          _date = selectedDate;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        accountId: _accountId!,
        categoryId: _categoryId!,
        type: _type,
        description: _descriptionController.text.trim(),
        amountCents: CurrencyUtils.parseToCents(_amountController.text),
        dueDate: _dueDate,
        date: _date,
        isPaid: _isPaid,
        subcategoryId: _subcategoryId,
        transactionKind: _kind,
        totalInstallments: _kind == 'installment'
            ? int.tryParse(_installmentsController.text.trim())
            : null,
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
}

class _TransferEditFormSheet extends StatefulWidget {
  const _TransferEditFormSheet({
    required this.transfer,
    required this.accounts,
    required this.onSubmit,
  });

  final TransactionListItem transfer;
  final List<AccountPreview> accounts;
  final Future<void> Function({
    required int fromAccountId,
    required int toAccountId,
    required String name,
    required int amountCents,
    required String transferKind,
    required DateTime dueDate,
    required bool isPaid,
    required DateTime date,
    int? totalInstallments,
  }) onSubmit;

  @override
  State<_TransferEditFormSheet> createState() => _TransferEditFormSheetState();
}

class _TransferEditFormSheetState extends State<_TransferEditFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _installmentsController;
  int? _fromAccountId;
  int? _toAccountId;
  late String _kind;
  late DateTime _dueDate;
  late DateTime _date;
  late bool _isPaid;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final transfer = widget.transfer;
    _nameController = TextEditingController(text: transfer.title);
    _amountController = TextEditingController(
      text: _formatCentsForInput(transfer.amountCents),
    );
    _installmentsController = TextEditingController(
      text: transfer.totalInstallments?.toString() ?? '',
    );
    _fromAccountId =
        widget.accounts.any((account) => account.id == transfer.fromAccountId)
            ? transfer.fromAccountId
            : widget.accounts.isEmpty
                ? null
                : widget.accounts.first.id;
    _toAccountId =
        widget.accounts.any((account) => account.id == transfer.toAccountId)
            ? transfer.toAccountId
            : _firstAccountIdExcept(_fromAccountId);
    _kind = transfer.kindCode ?? 'single';
    _dueDate = transfer.dueDate ?? transfer.date;
    _date = transfer.date;
    _isPaid = transfer.isPaid;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  int? _firstAccountIdExcept(int? accountId) {
    for (final account in widget.accounts) {
      if (account.id != accountId) {
        return account.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar transferência',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 14),
              _KindSelector(
                value: _kind,
                onChanged: (value) => setState(() => _kind = value),
              ),
              if (_kind == 'installment') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _installmentsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total de parcelas',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                  validator: _validateInstallments,
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _fromAccountId,
                decoration: const InputDecoration(
                  labelText: 'Conta de origem',
                  prefixIcon: Icon(Icons.call_made_rounded),
                ),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _fromAccountId = value),
                validator: (value) {
                  if (value == null) {
                    return 'Selecione a origem.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(
                  labelText: 'Conta de destino',
                  prefixIcon: Icon(Icons.call_received_rounded),
                ),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _toAccountId = value),
                validator: (value) {
                  if (value == null) {
                    return 'Selecione o destino.';
                  }
                  if (value == _fromAccountId) {
                    return 'Escolha uma conta diferente.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(isDueDate: true),
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de vencimento',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                  child: Text(_formatDate(_dueDate)),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isDueDate: false),
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text('Data: ${_formatDate(_date)}'),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPaid,
                title: const Text('Transferência efetivada'),
                subtitle: Text(
                  _isPaid
                      ? 'Mantém o valor movimentado entre as contas.'
                      : 'Remove dos saldos e deixa como prevista.',
                ),
                onChanged: (value) => setState(() => _isPaid = value),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar edição'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final currentDate = isDueDate ? _dueDate : _date;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = selectedDate;
        } else {
          _date = selectedDate;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        name: _nameController.text.trim(),
        amountCents: CurrencyUtils.parseToCents(_amountController.text),
        transferKind: _kind,
        dueDate: _dueDate,
        isPaid: _isPaid,
        date: _date,
        totalInstallments: _kind == 'installment'
            ? int.tryParse(_installmentsController.text.trim())
            : null,
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
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'single',
          label: Text('Única'),
          icon: Icon(Icons.looks_one_rounded),
        ),
        ButtonSegment(
          value: 'installment',
          label: Text('Parcelada'),
          icon: Icon(Icons.format_list_numbered_rounded),
        ),
        ButtonSegment(
          value: 'fixed_monthly',
          label: Text('Fixa'),
          icon: Icon(Icons.repeat_rounded),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    required this.accounts,
    required this.categories,
    required this.onSubmit,
  });

  final List<AccountPreview> accounts;
  final List<CategoryModel> categories;
  final Future<void> Function({
    required int accountId,
    required int categoryId,
    required String type,
    required String description,
    required int amountCents,
    required DateTime dueDate,
    required DateTime date,
    required bool isPaid,
  }) onSubmit;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = TransactionFilters.expense;
  int? _accountId;
  int? _categoryId;
  DateTime _dueDate = DateTime.now();
  DateTime _date = DateTime.now();
  bool _isPaid = true;
  bool _isSubmitting = false;

  List<CategoryModel> get _availableCategories {
    return widget.categories
        .where((category) => category.type == _type)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.isEmpty ? null : widget.accounts.first.id;
    _categoryId =
        _availableCategories.isEmpty ? null : _availableCategories.first.id;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _availableCategories;
    if (_categoryId == null ||
        !categories.any((item) => item.id == _categoryId)) {
      _categoryId = categories.isEmpty ? null : categories.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Novo lançamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: TransactionFilters.expense,
                    label: Text('Despesa'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionFilters.income,
                    label: Text('Receita'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() {
                    _type = selection.first;
                    final categories = _availableCategories;
                    _categoryId =
                        categories.isEmpty ? null : categories.first.id;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex: Mercado, salário, aluguel',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe uma descrição.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: 'Ex: 120,00',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o valor.';
                  }
                  if (CurrencyUtils.parseToCents(value) <= 0) {
                    return 'Informe um valor maior que zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Conta',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
                validator: (value) {
                  if (value == null) {
                    return 'Selecione uma conta.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) {
                  if (value == null) {
                    return 'Selecione uma categoria.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(isDueDate: true),
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de vencimento',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                  child: Text(_formatDate(_dueDate)),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPaid,
                title: const Text('Pagamento efetivado'),
                subtitle: Text(
                  _isPaid
                      ? 'Atualiza o saldo da conta ao salvar.'
                      : 'Salva como previsto e não altera o saldo agora.',
                ),
                onChanged: (value) => setState(() => _isPaid = value),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isDueDate: false),
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(_formatDate(_date)),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final currentDate = isDueDate ? _dueDate : _date;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = selectedDate;
        } else {
          _date = selectedDate;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        accountId: _accountId!,
        categoryId: _categoryId!,
        type: _type,
        description: _descriptionController.text.trim(),
        amountCents: CurrencyUtils.parseToCents(_amountController.text),
        dueDate: _dueDate,
        date: _date,
        isPaid: _isPaid,
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
}

String _subtitle(TransactionListItem transaction) {
  if (transaction.isTransfer) {
    return '${transaction.accountName} para ${transaction.toAccountName ?? 'Conta removida'}';
  }

  final category = transaction.subcategoryName == null
      ? transaction.categoryName
      : '${transaction.categoryName} • ${transaction.subcategoryName}';

  if (transaction.isCreditCard) {
    final invoice = transaction.invoiceMonth == null ||
            transaction.invoiceYear == null
        ? null
        : '${transaction.invoiceMonth.toString().padLeft(2, '0')}/${transaction.invoiceYear}';
    final card = transaction.creditCardName ?? 'Cartão removido';
    return invoice == null
        ? '$category • $card'
        : '$category • $card • fatura $invoice';
  }

  return '$category • ${transaction.accountName}';
}

String _detailsLabel(TransactionListItem transaction) {
  final parts = <String>[
    if (transaction.kindLabel != null) transaction.kindLabel!,
    if (transaction.installmentNumber != null &&
        transaction.totalInstallments != null)
      'parcela ${transaction.installmentNumber}/${transaction.totalInstallments}',
    if (!transaction.isPaid && transaction.dueDate != null)
      'vence ${_formatDateShort(transaction.dueDate!)}',
  ];
  return parts.join(' • ');
}

Color _amountColor(BuildContext context, TransactionListItem transaction) {
  final colors = context.colors;
  if (!transaction.isPaid) {
    return AppColors.warning;
  }
  if (transaction.isIncome) {
    return colors.success;
  }
  if (transaction.isTransfer) {
    return colors.info;
  }
  return colors.danger;
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

String _typeLabel(TransactionListItem transaction) {
  if (transaction.isTransfer) {
    return 'Transferência';
  }
  if (transaction.isIncome) {
    return 'Receita';
  }
  return 'Despesa';
}

String? _validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Informe o valor.';
  }
  if (CurrencyUtils.parseToCents(value) <= 0) {
    return 'Informe um valor maior que zero.';
  }
  return null;
}

String? _validateInstallments(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed < 2) {
    return 'Informe 2 parcelas ou mais.';
  }
  return null;
}

String _formatCentsForInput(int cents) {
  final value = cents / 100;
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDateShort(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _formatDateLong(DateTime date) {
  const weekdays = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];
  return '${_formatDate(date)} • ${weekdays[date.weekday - 1]}';
}
