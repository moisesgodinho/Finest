import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../shared/widgets/balance_card.dart';
import '../../shared/widgets/section_card.dart';
import 'accounts_view_model.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsViewModelProvider);
    final viewModel = ref.read(accountsViewModelProvider.notifier);

    ref.listen(accountsViewModelProvider.select((state) => state.errorMessage),
        (
      previous,
      next,
    ) {
      if (next == null || next == previous) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next)),
      );
    });

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              title: 'Contas',
              subtitle: AppDateUtils.monthYearLabel(DateTime.now()),
              onAdd: () => _openAccountForm(context, ref),
            ),
            if (state.isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 20),
            BalanceCard(
              title: 'Saldo total em contas',
              value: CurrencyUtils.formatCents(state.totalBalanceCents),
              subtitle: '${state.accounts.length} contas vinculadas',
              isVisible: state.isBalanceVisible,
              onToggleVisibility: viewModel.toggleBalanceVisibility,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AccountStatCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Contas ativas',
                  value: '${state.accounts.length}',
                ),
                _AccountStatCard(
                  icon: Icons.credit_card_rounded,
                  title: 'Conta corrente',
                  value: CurrencyUtils.formatCents(state.checkingBalanceCents),
                ),
                _AccountStatCard(
                  icon: Icons.savings_rounded,
                  title: 'Poupança',
                  value: CurrencyUtils.formatCents(state.savingsBalanceCents),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Minhas contas',
              trailing: TextButton.icon(
                onPressed: () => _openAccountForm(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Adicionar'),
              ),
              child: state.accounts.isEmpty
                  ? const _EmptyAccounts()
                  : Column(
                      children: [
                        for (final account in state.accounts)
                          _AccountTile(
                            account: account,
                            onTap: () => _openAccountForm(
                              context,
                              ref,
                              account: account,
                            ),
                          ),
                      ],
                    ),
            ),
            if (state.accounts.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionCard(
                title: 'Distribuição por conta',
                child: Column(
                  children: [
                    for (final account in state.accounts)
                      _DistributionRow(
                        account: account,
                        totalCents: state.totalBalanceCents,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAccountForm(
    BuildContext context,
    WidgetRef ref, {
    AccountPreview? account,
  }) async {
    final viewModel = ref.read(accountsViewModelProvider.notifier);
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
        return _AccountFormSheet(
          account: account,
          onSubmit: ({
            required String name,
            required String type,
            required int balanceCents,
            required String color,
            String? bankName,
          }) async {
            if (account == null) {
              await viewModel.createAccount(
                name: name,
                type: type,
                bankName: bankName,
                initialBalance: balanceCents,
                color: color,
              );
            } else {
              await viewModel.updateAccount(
                account: account,
                name: name,
                type: type,
                bankName: bankName,
                balanceCents: balanceCents,
                color: color,
              );
            }
          },
          onDelete: account == null
              ? null
              : () async {
                  await viewModel.deleteAccount(account);
                },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(account == null ? 'Conta criada.' : 'Conta atualizada.'),
        ),
      );
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: onAdd,
          tooltip: 'Adicionar conta',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _AccountStatCard extends StatelessWidget {
  const _AccountStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.primary,
            child: Icon(icon),
          ),
          const SizedBox(height: 12),
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
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhuma conta cadastrada ainda.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Adicione sua primeira conta para começar a calcular seu saldo real.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onTap,
  });

  final AccountPreview account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedName = account.name.trim();
    final initials = trimmedName.isEmpty
        ? '?'
        : trimmedName.characters.take(2).toString().toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: account.color,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '${account.type} • ${account.bankName ?? 'Sem banco'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyUtils.formatCents(account.balanceCents),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.account,
    required this.totalCents,
  });

  final AccountPreview account;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final percent = totalCents == 0 ? 0.0 : account.balanceCents / totalCents;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: account.color,
            child: Text(
              account.name.characters.first.toLowerCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 7,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(account.color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '${(percent * 100).round()}%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountFormSheet extends StatefulWidget {
  const _AccountFormSheet({
    required this.onSubmit,
    this.account,
    this.onDelete,
  });

  final AccountPreview? account;
  final Future<void> Function({
    required String name,
    required String type,
    required int balanceCents,
    required String color,
    String? bankName,
  }) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  static const _accountTypes = [
    'Conta corrente',
    'Poupança',
    'Conta digital',
    'Carteira',
    'Investimento',
  ];

  static const _colors = [
    '#006B4F',
    '#2F80ED',
    '#7C3AED',
    '#F59E0B',
    '#D93025',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _balanceController;
  late String _selectedType;
  late String _selectedColor;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _balanceController = TextEditingController(
      text: account == null
          ? ''
          : CurrencyUtils.formatCents(account.balanceCents),
    );
    _selectedType = _accountTypes.contains(account?.type)
        ? account!.type
        : _accountTypes.first;
    _selectedColor = account?.colorHex ?? _colors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;

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
                account == null ? 'Nova conta' : 'Editar conta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da conta',
                  hintText: 'Ex: Nubank',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da conta.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ex: Nubank, Inter, Caixa',
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  for (final type in _accountTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial',
                  hintText: 'Ex: 1500,00',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o saldo inicial.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Cor', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  for (final color in _colors)
                    _ColorOption(
                      color: color,
                      isSelected: color == _selectedColor,
                      onTap: () => setState(() => _selectedColor = color),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar conta'),
                ),
              ),
              if (widget.onDelete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remover conta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        type: _selectedType,
        balanceCents: CurrencyUtils.parseToCents(_balanceController.text),
        color: _selectedColor,
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

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover conta?'),
          content: const Text(
            'Esta ação remove a conta localmente. Quando houver lançamentos vinculados, vamos bloquear remoções inseguras.',
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

    if (shouldDelete != true || widget.onDelete == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onDelete!();
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

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsedColor = Color(
      int.parse('FF${color.replaceFirst('#', '')}', radix: 16),
    );

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: parsedColor,
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : null,
      ),
    );
  }
}
