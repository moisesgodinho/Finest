import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/app_currency.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../shared/widgets/balance_card.dart';
import '../../shared/widgets/section_card.dart';
import '../transactions/transactions_view_model.dart';
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
              value: CurrencyUtils.formatCents(
                state.totalBalanceCents,
                currencyCode: state.currencyCode,
              ),
              subtitle: '${state.accounts.length} contas vinculadas',
              isVisible: state.isBalanceVisible,
              onToggleVisibility: viewModel.toggleBalanceVisibility,
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
                            displayCurrencyCode: state.currencyCode,
                            onTap: () => _openAccountDetails(
                              context,
                              ref,
                              account,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            _EmergencyReserveCard(
              state: state,
              onCreate: () => _openAccountForm(
                context,
                ref,
                isEmergencyReserve: true,
                initialName: 'Reserva de emergência',
                initialType: 'Conta digital',
                suggestedReserveCents: state.suggestedEmergencyReserveCents,
              ),
              onEdit: (account) => _openAccountForm(
                context,
                ref,
                account: account,
                isEmergencyReserve: true,
                suggestedReserveCents: state.suggestedEmergencyReserveCents,
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

  Future<void> _openAccountDetails(
    BuildContext context,
    WidgetRef ref,
    AccountPreview account,
  ) async {
    final shouldEdit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final accountsState = ref.read(accountsViewModelProvider);
        final currentAccount = accountsState.accounts
            .where((item) => item.id == account.id)
            .firstOrNull;
        final detailAccount = currentAccount ?? account;
        final transactionsState = ref.read(transactionsViewModelProvider);

        return _AccountDetailSheet(
          account: detailAccount,
          displayCurrencyCode: accountsState.currencyCode,
          history: _accountHistoryFor(
            transactionsState.transactions,
            detailAccount.id,
          ),
          onEdit: () {
            Navigator.of(sheetContext).pop(true);
          },
        );
      },
    );

    if (shouldEdit != true || !context.mounted) {
      return;
    }

    final currentAccount = ref
        .read(accountsViewModelProvider)
        .accounts
        .where((item) => item.id == account.id)
        .firstOrNull;
    await _openAccountForm(
      context,
      ref,
      account: currentAccount ?? account,
    );
  }

  List<TransactionListItem> _accountHistoryFor(
    List<TransactionListItem> transactions,
    int accountId,
  ) {
    final history = transactions.where((transaction) {
      if (transaction.isTransfer) {
        return transaction.fromAccountId == accountId ||
            transaction.toAccountId == accountId;
      }
      return transaction.accountId == accountId;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return history.take(25).toList();
  }

  Future<void> _openAccountForm(
    BuildContext context,
    WidgetRef ref, {
    AccountPreview? account,
    bool isEmergencyReserve = false,
    String? initialName,
    String? initialType,
    int? suggestedReserveCents,
  }) async {
    final viewModel = ref.read(accountsViewModelProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final defaultCurrencyCode = ref.read(currencyControllerProvider);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _AccountFormSheet(
          account: account,
          defaultCurrencyCode: defaultCurrencyCode,
          isEmergencyReserve:
              isEmergencyReserve || account?.isEmergencyReserve == true,
          initialName: initialName,
          initialType: initialType,
          suggestedReserveCents: suggestedReserveCents,
          onSubmit: ({
            required String name,
            required String type,
            required int balanceCents,
            int? emergencyReserveTargetCents,
            required String color,
            required String currencyCode,
            String? bankName,
          }) async {
            if (account == null) {
              await viewModel.createAccount(
                name: name,
                type: type,
                bankName: bankName,
                initialBalance: balanceCents,
                currencyCode: currencyCode,
                emergencyReserveTarget: emergencyReserveTargetCents,
                color: color,
              );
            } else {
              await viewModel.updateAccount(
                account: account,
                name: name,
                type: type,
                bankName: bankName,
                balanceCents: balanceCents,
                currencyCode: currencyCode,
                emergencyReserveTarget: emergencyReserveTargetCents,
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

class _EmergencyReserveCard extends StatelessWidget {
  const _EmergencyReserveCard({
    required this.state,
    required this.onCreate,
    required this.onEdit,
  });

  final AccountsState state;
  final VoidCallback onCreate;
  final ValueChanged<AccountPreview> onEdit;

  @override
  Widget build(BuildContext context) {
    final hasSuggestion = state.hasEmergencyReserveSuggestion;
    final reserveAccount = state.emergencyReserveAccount;
    final colors = context.colors;

    if (reserveAccount != null) {
      final targetCents = state.emergencyReserveTargetCents;
      final remainingCents = (targetCents - reserveAccount.balanceCents)
          .clamp(0, targetCents)
          .toInt();
      final shouldShowConvertedBalance =
          reserveAccount.currencyCode.toUpperCase() !=
              state.currencyCode.toUpperCase();

      return SectionCard(
        title: 'Reserva de emergência',
        trailing: TextButton.icon(
          onPressed: () => onEdit(reserveAccount),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Editar'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: reserveAccount.color,
                  foregroundColor: colors.onPrimary,
                  child: const Icon(Icons.shield_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reserveAccount.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '${reserveAccount.type} • ${reserveAccount.bankName ?? 'Sem banco'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ReserveDataBlock(
                    label: 'Saldo reservado',
                    value: CurrencyUtils.formatCents(
                      reserveAccount.balanceCents,
                      currencyCode: reserveAccount.currencyCode,
                    ),
                    secondaryValue: shouldShowConvertedBalance
                        ? '≈ ${CurrencyUtils.formatCents(
                            reserveAccount.consolidatedBalanceCents,
                            currencyCode: state.currencyCode,
                          )}'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReserveDataBlock(
                    label: 'Meta',
                    value: targetCents > 0
                        ? CurrencyUtils.formatCents(targetCents)
                        : 'Definir',
                  ),
                ),
              ],
            ),
            if (targetCents > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: state.emergencyReserveProgress,
                  minHeight: 10,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                remainingCents == 0
                    ? 'Meta alcançada.'
                    : 'Faltam ${CurrencyUtils.formatCents(remainingCents)} para completar a reserva.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    return SectionCard(
      title: 'Reserva de emergência',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primary.withValues(alpha: 0.10),
                foregroundColor: colors.primary,
                child: const Icon(Icons.shield_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  hasSuggestion
                      ? 'Uma reserva protege seu mês quando aparece um imprevisto. Pela sua média recente, esta é uma boa meta inicial.'
                      : 'Comece separando uma conta para sua reserva. Quando houver mais despesas registradas, o app calcula uma meta automática.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (hasSuggestion) ...[
            Text(
              'Meta sugerida',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.formatCents(state.suggestedEmergencyReserveCents),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Baseada em 6 meses de uma média de ${CurrencyUtils.formatCents(state.monthlyExpenseAverageCents)} em despesas pagas.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else ...[
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
                      Icons.lightbulb_outline_rounded,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use como referência uma meta entre 3 e 6 meses do seu custo de vida.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (state.emergencyReserveBalanceCents > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Já reservado',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  CurrencyUtils.formatCents(
                    state.emergencyReserveBalanceCents,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: state.emergencyReserveProgress,
                minHeight: 9,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colors.primaryLight,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar reserva'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReserveDataBlock extends StatelessWidget {
  const _ReserveDataBlock({
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  final String label;
  final String value;
  final String? secondaryValue;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                  ),
            ),
            if (secondaryValue != null) ...[
              const SizedBox(height: 2),
              Text(
                secondaryValue!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: colors.textSecondary,
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

class _AccountDetailSheet extends StatelessWidget {
  const _AccountDetailSheet({
    required this.account,
    required this.displayCurrencyCode,
    required this.history,
    required this.onEdit,
  });

  final AccountPreview account;
  final String displayCurrencyCode;
  final List<TransactionListItem> history;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shouldShowConvertedBalance =
        account.currencyCode.toUpperCase() != displayCurrencyCode.toUpperCase();

    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
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
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: account.color,
                  foregroundColor: colors.onPrimary,
                  child: Text(
                    _initialsFor(account.name),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.type} â€¢ ${account.bankName ?? 'Sem banco'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onEdit,
                  tooltip: 'Editar conta',
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo da conta',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyUtils.formatCents(
                              account.balanceCents,
                              currencyCode: account.currencyCode,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: colors.primary),
                          ),
                          if (shouldShowConvertedBalance) ...[
                            const SizedBox(height: 3),
                            Text(
                              'â‰ˆ ${CurrencyUtils.formatCents(
                                account.consolidatedBalanceCents,
                                currencyCode: displayCurrencyCode,
                              )}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      account.includeInTotalBalance
                          ? Icons.add_chart_rounded
                          : Icons.visibility_off_rounded,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'HistÃ³rico da conta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: history.isEmpty
                  ? const _EmptyAccountHistory()
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => Divider(
                        color: colors.border,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        return _AccountHistoryTile(
                          account: account,
                          transaction: history[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '?';
    }
    return trimmedName.characters.take(2).toString().toUpperCase();
  }
}

class _EmptyAccountHistory extends StatelessWidget {
  const _EmptyAccountHistory();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              'Ainda nÃ£o hÃ¡ lanÃ§amentos nesta conta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountHistoryTile extends StatelessWidget {
  const _AccountHistoryTile({
    required this.account,
    required this.transaction,
  });

  final AccountPreview account;
  final TransactionListItem transaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isIncomingTransfer =
        transaction.isTransfer && transaction.toAccountId == account.id;
    final isPositive =
        transaction.isTransfer ? isIncomingTransfer : transaction.isIncome;
    final amountCents = isIncomingTransfer
        ? transaction.toAmountCents ?? transaction.amountCents
        : transaction.amountCents;
    final currencyCode = isIncomingTransfer
        ? transaction.toCurrencyCode ?? transaction.currencyCode
        : transaction.currencyCode;
    final detail = transaction.isTransfer
        ? '${transaction.accountName} â†’ ${transaction.toAccountName ?? 'Conta'}'
        : '${transaction.categoryName} â€¢ ${transaction.paymentMethodLabel}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: transaction.iconColor.withValues(alpha: 0.13),
            foregroundColor: transaction.iconColor,
            child: Icon(transaction.icon, size: 19),
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
                const SizedBox(height: 2),
                Text(
                  '$detail â€¢ ${_shortDate(transaction.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+ ' : '- '}${CurrencyUtils.formatCents(
                  amountCents,
                  currencyCode: currencyCode,
                )}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isPositive ? colors.success : colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction.isPaid ? 'Efetivado' : 'Pendente',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: transaction.isPaid
                          ? colors.textSecondary
                          : colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.displayCurrencyCode,
    required this.onTap,
  });

  final AccountPreview account;
  final String displayCurrencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trimmedName = account.name.trim();
    final initials = trimmedName.isEmpty
        ? '?'
        : trimmedName.characters.take(2).toString().toUpperCase();
    final shouldShowConvertedBalance =
        account.currencyCode.toUpperCase() != displayCurrencyCode.toUpperCase();

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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 126),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.formatCents(
                      account.balanceCents,
                      currencyCode: account.currencyCode,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (shouldShowConvertedBalance) ...[
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${CurrencyUtils.formatCents(
                        account.consolidatedBalanceCents,
                        currencyCode: displayCurrencyCode,
                      )}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textSecondary,
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
    final colors = context.colors;
    final percent =
        totalCents == 0 ? 0.0 : account.consolidatedBalanceCents / totalCents;

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
                backgroundColor: colors.border,
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
    this.isEmergencyReserve = false,
    this.defaultCurrencyCode = AppCurrencies.defaultCode,
    this.initialName,
    this.initialType,
    this.suggestedReserveCents,
    this.onDelete,
  });

  final AccountPreview? account;
  final bool isEmergencyReserve;
  final String defaultCurrencyCode;
  final String? initialName;
  final String? initialType;
  final int? suggestedReserveCents;
  final Future<void> Function({
    required String name,
    required String type,
    required int balanceCents,
    int? emergencyReserveTargetCents,
    required String color,
    required String currencyCode,
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
  late final TextEditingController _reserveTargetController;
  late String _selectedType;
  late String _selectedColor;
  late String _selectedCurrencyCode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(
      text: account?.name ?? widget.initialName ?? '',
    );
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _balanceController = TextEditingController(
      text: account == null
          ? ''
          : CurrencyUtils.formatCents(
              account.balanceCents,
              currencyCode: account.currencyCode,
            ),
    );
    _reserveTargetController = TextEditingController(
      text: _initialReserveTargetText(account),
    );
    final initialType = widget.initialType;
    _selectedType = _accountTypes.contains(account?.type)
        ? account!.type
        : _accountTypes.contains(initialType)
            ? initialType!
            : _accountTypes.first;
    _selectedColor = account?.colorHex ?? _colors.first;
    _selectedCurrencyCode = account?.currencyCode ?? widget.defaultCurrencyCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _balanceController.dispose();
    _reserveTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final isEmergencyReserve = widget.isEmergencyReserve;
    final colors = context.colors;

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
              Text(
                isEmergencyReserve
                    ? account == null
                        ? 'Nova reserva'
                        : 'Editar reserva'
                    : account == null
                        ? 'Nova conta'
                        : 'Editar conta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (isEmergencyReserve &&
                  widget.suggestedReserveCents != null &&
                  widget.suggestedReserveCents! > 0) ...[
                const SizedBox(height: 14),
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
                          Icons.shield_rounded,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Meta sugerida: ${CurrencyUtils.formatCents(widget.suggestedReserveCents!)}. Você pode ajustar a meta antes de salvar.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrencyCode,
                decoration: InputDecoration(
                  labelText: 'Moeda da conta',
                  prefixIcon: const Icon(Icons.currency_exchange_rounded),
                  helperText: account == null
                      ? 'Esta conta aceitará lançamentos nesta moeda.'
                      : 'A moeda da conta não muda depois de criada.',
                ),
                items: [
                  for (final currency in AppCurrencies.supported)
                    DropdownMenuItem(
                      value: currency.code,
                      child: Text('${currency.code} - ${currency.label}'),
                    ),
                ],
                onChanged: account == null
                    ? (value) {
                        if (value != null) {
                          setState(() => _selectedCurrencyCode = value);
                        }
                      }
                    : null,
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
              if (isEmergencyReserve) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reserveTargetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Meta da reserva',
                    hintText: 'Ex: 30000,00',
                    helperText: widget.suggestedReserveCents != null &&
                            widget.suggestedReserveCents! > 0
                        ? 'Sugerida: ${CurrencyUtils.formatCents(widget.suggestedReserveCents!)}'
                        : 'Defina quanto deseja acumular nesta reserva.',
                    prefixIcon: const Icon(Icons.flag_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a meta da reserva.';
                    }
                    if (CurrencyUtils.parseToCents(value) <= 0) {
                      return 'A meta deve ser maior que zero.';
                    }
                    return null;
                  },
                ),
              ],
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
                  child: Text(
                    _isSubmitting
                        ? 'Salvando...'
                        : isEmergencyReserve
                            ? 'Salvar reserva'
                            : 'Salvar conta',
                  ),
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
        currencyCode: _selectedCurrencyCode,
        emergencyReserveTargetCents: widget.isEmergencyReserve
            ? CurrencyUtils.parseToCents(_reserveTargetController.text)
            : null,
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

  String _initialReserveTargetText(AccountPreview? account) {
    final currentTarget = account?.emergencyReserveTargetCents;
    if (currentTarget != null && currentTarget > 0) {
      return CurrencyUtils.formatCents(currentTarget);
    }

    final suggestedTarget = widget.suggestedReserveCents;
    if (widget.isEmergencyReserve &&
        suggestedTarget != null &&
        suggestedTarget > 0) {
      return CurrencyUtils.formatCents(suggestedTarget);
    }

    return '';
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
    final colors = context.colors;
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
            color: isSelected ? colors.textPrimary : Colors.transparent,
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
