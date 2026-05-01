import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/category_model.dart';
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
        title: const Text('Lançamentos'),
      ),
      floatingActionButton: state.accounts.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openTransactionForm(context, ref),
              child: const Icon(Icons.add_rounded, size: 34),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            if (state.isLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            SectionCard(
              title: 'Lançamentos',
              trailing: state.accounts.isEmpty
                  ? null
                  : TextButton.icon(
                      onPressed: () => _openTransactionForm(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Adicionar'),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('Todos'),
                        icon: Icon(Icons.list_alt_rounded),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('Receitas'),
                        icon: Icon(Icons.arrow_downward_rounded),
                      ),
                      ButtonSegment(
                        value: 'expense',
                        label: Text('Despesas'),
                        icon: Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                    selected: {state.selectedType},
                    onSelectionChanged: (selection) {
                      viewModel.selectType(selection.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  if (state.accounts.isEmpty)
                    const _NoAccountsMessage()
                  else if (state.filteredTransactions.isEmpty)
                    const _EmptyTransactionsMessage()
                  else
                    Column(
                      children: [
                        for (final transaction in state.filteredTransactions)
                          _TransactionTile(
                            transaction: transaction,
                            onDelete: () => _confirmDelete(
                              context,
                              viewModel,
                              transaction,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: Colors.white,
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
            required DateTime date,
          }) async {
            await viewModel.createTransaction(
              accountId: accountId,
              categoryId: categoryId,
              type: type,
              description: description,
              amountCents: amountCents,
              date: date,
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
          content: const Text(
            'O saldo da conta será ajustado automaticamente.',
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
      await viewModel.deleteTransaction(transaction);
    }
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
      title: 'Nenhum lançamento ainda.',
      subtitle: 'Toque em Adicionar para registrar sua primeira movimentação.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 46),
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onDelete,
  });

  final TransactionListItem transaction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amountColor =
        transaction.isIncome ? AppColors.success : AppColors.textPrimary;
    final amountPrefix = transaction.isIncome ? '+ ' : '- ';

    return Padding(
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
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${transaction.categoryName} • ${transaction.accountName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$amountPrefix${CurrencyUtils.formatCents(transaction.amountCents)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Remover lançamento',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
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
    required DateTime date,
  }) onSubmit;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  int? _accountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
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
                    value: 'expense',
                    label: Text('Despesa'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: 'income',
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
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(
                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                ),
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

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      setState(() => _date = selectedDate);
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
        date: _date,
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
