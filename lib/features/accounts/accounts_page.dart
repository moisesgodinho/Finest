import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/currency/app_currency.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../shared/constants/financial_color_options.dart';
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
            ),
            const SizedBox(height: 14),
            _AccountsMonthPager(
              month: state.selectedMonth,
              canGoPrevious: state.canGoToPreviousMonth,
              onPrevious: viewModel.previousMonth,
              onNext: viewModel.nextMonth,
            ),
            if (state.isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 20),
            _AccountsTotalCard(
              state: state,
              isVisible: state.isBalanceVisible,
              onToggleVisibility: viewModel.toggleBalanceVisibility,
            ),
            const SizedBox(height: 18),
            _AccountsSection(
              accounts: state.accounts,
              displayCurrencyCode: state.currencyCode,
              onAdd: () => _openAccountForm(context, ref),
              onTapAccount: (account) => _openAccountDetails(
                context,
                ref,
                account,
              ),
              onRegisterYield: (account) => _openAccountYieldForm(
                context,
                ref,
                account,
              ),
            ),
            if (state.emergencyReserveAccount == null) ...[
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
            ],
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
    final shouldEdit = await context.push<bool>('/accounts/${account.id}');

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

  static List<TransactionListItem> _accountHistoryFor(
    List<TransactionListItem> transactions,
    int accountId, {
    DateTime? month,
  }) {
    final history = transactions.where((transaction) {
      if (transaction.isTransfer) {
        final belongsToAccount = transaction.fromAccountId == accountId ||
            transaction.toAccountId == accountId;
        return belongsToAccount &&
            (month == null || _isSameMonth(transaction.monthReference, month));
      }
      return transaction.accountId == accountId &&
          (month == null || _isSameMonth(transaction.monthReference, month));
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return history.take(25).toList();
  }

  static bool _isSameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
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

  static Future<void> _openAccountYieldForm(
    BuildContext context,
    WidgetRef ref,
    AccountPreview account,
  ) async {
    final viewModel = ref.read(accountsViewModelProvider.notifier);
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
        final currentAccount = ref
                .read(accountsViewModelProvider)
                .accounts
                .where((item) => item.id == account.id)
                .firstOrNull ??
            account;

        return _AccountYieldFormSheet(
          account: currentAccount,
          onSubmit: ({
            required int amountCents,
            required DateTime date,
          }) async {
            await viewModel.registerAccountYield(
              account: currentAccount,
              amountCents: amountCents,
              date: date,
            );
          },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Rendimento registrado.')),
      );
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountsMonthPager extends StatelessWidget {
  const _AccountsMonthPager({
    required this.month,
    required this.canGoPrevious,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoPrevious;
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
            onPressed: canGoPrevious ? onPrevious : null,
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              AppDateUtils.monthYearLabel(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _AccountsTotalCard extends StatelessWidget {
  const _AccountsTotalCard({
    required this.state,
    required this.isVisible,
    required this.onToggleVisibility,
  });

  final AccountsState state;
  final bool isVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gradientStart = _shiftColor(colors.primary, lightnessDelta: 0.12);
    final gradientEnd = _shiftColor(colors.primaryDark, lightnessDelta: -0.03);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primaryDark.withValues(
              alpha: colors.isDark ? 0.36 : 0.22,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              left: -86,
              bottom: -100,
              child: _AccountsTotalGlow(size: 240, opacity: 0.12),
            ),
            Positioned(
              right: -96,
              top: -104,
              child: _AccountsTotalGlow(size: 230, opacity: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Saldo total em contas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _AccountsVisibilityButton(
                        isVisible: isVisible,
                        onPressed: onToggleVisibility,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isVisible
                          ? CurrencyUtils.formatCents(
                              state.totalBalanceCents,
                              currencyCode: state.currencyCode,
                            )
                          : '${state.currencyCode} ------',
                      maxLines: 1,
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AccountsTotalMetricGrid(
                    isVisible: isVisible,
                    currencyCode: state.currencyCode,
                    metrics: [
                      _AccountsMetricData(
                        label: 'Saldo inicial',
                        amountCents: state.totalInitialBalanceCents,
                      ),
                      _AccountsMetricData(
                        label: 'Receitas',
                        amountCents: state.totalIncomeCents,
                      ),
                      _AccountsMetricData(
                        label: 'Despesas',
                        amountCents: state.totalExpenseCents,
                      ),
                      _AccountsMetricData(
                        label: 'Rendimentos',
                        amountCents: state.totalYieldCents,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${state.accounts.length} contas vinculadas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
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

class _AccountsTotalMetricGrid extends StatelessWidget {
  const _AccountsTotalMetricGrid({
    required this.metrics,
    required this.currencyCode,
    required this.isVisible,
  });

  final List<_AccountsMetricData> metrics;
  final String currencyCode;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final width = isWide
            ? ((constraints.maxWidth - 24) / 4)
            : ((constraints.maxWidth - 8) / 2);

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width.toDouble(),
                child: _AccountsTotalMetric(
                  metric: metric,
                  currencyCode: currencyCode,
                  isVisible: isVisible,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountsTotalMetric extends StatelessWidget {
  const _AccountsTotalMetric({
    required this.metric,
    required this.currencyCode,
    required this.isVisible,
  });

  final _AccountsMetricData metric;
  final String currencyCode;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isVisible
                    ? CurrencyUtils.formatCents(
                        metric.amountCents,
                        currencyCode: currencyCode,
                      )
                    : '$currencyCode --',
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

class _AccountsMetricData {
  const _AccountsMetricData({
    required this.label,
    required this.amountCents,
  });

  final String label;
  final int amountCents;
}

class _AccountsVisibilityButton extends StatelessWidget {
  const _AccountsVisibilityButton({
    required this.isVisible,
    required this.onPressed,
  });

  final bool isVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          foregroundColor: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x33FFFFFF)),
          ),
        ),
        icon: Icon(
          isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          size: 21,
        ),
      ),
    );
  }
}

class _AccountsTotalGlow extends StatelessWidget {
  const _AccountsTotalGlow({
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: opacity),
      ),
    );
  }
}

Color _shiftColor(Color color, {required double lightnessDelta}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
      .toColor();
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
                        '${reserveAccount.type} - ${reserveAccount.bankName ?? 'Sem banco'}',
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
                        ? 'aprox. ${CurrencyUtils.formatCents(
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

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({
    required this.accountId,
    super.key,
  });

  final int accountId;

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  DateTime? _visibleMonth;

  void _moveMonth(
    int delta, {
    required DateTime currentMonth,
    required DateTime firstAvailableMonth,
  }) {
    final nextMonth = _maxMonth(
      DateTime(currentMonth.year, currentMonth.month + delta),
      firstAvailableMonth,
    );
    setState(() {
      _visibleMonth = nextMonth;
    });
    ref.read(accountsViewModelProvider.notifier).selectMonth(nextMonth);
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsViewModelProvider);
    final transactionsState = ref.watch(transactionsViewModelProvider);
    final account = accountsState.accounts
        .where((item) => item.id == widget.accountId)
        .firstOrNull;
    final rawVisibleMonth = _visibleMonth ?? accountsState.selectedMonth;
    final visibleMonth = account == null
        ? rawVisibleMonth
        : _maxMonth(
            rawVisibleMonth,
            account.firstAvailableMonth ?? accountsState.firstAvailableMonth,
          );

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

    return Scaffold(
      appBar: AppBar(
        title: Text(account?.name ?? 'Conta'),
        actions: [
          if (account != null) ...[
            IconButton(
              onPressed: () => AccountsPage._openAccountYieldForm(
                context,
                ref,
                account,
              ),
              tooltip: 'Registrar rendimento',
              icon: const Icon(Icons.trending_up_rounded),
            ),
            IconButton(
              onPressed: () => context.pop(true),
              tooltip: 'Editar conta',
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ],
      ),
      body: account == null
          ? _MissingAccountView(isLoading: accountsState.isLoading)
          : SafeArea(
              bottom: false,
              child: _AccountDetailContent(
                account: account,
                displayCurrencyCode: accountsState.currencyCode,
                visibleMonth: visibleMonth,
                canGoPreviousMonth: _isAfterMonth(
                  visibleMonth,
                  account.firstAvailableMonth ??
                      accountsState.firstAvailableMonth,
                ),
                onPreviousMonth: () => _moveMonth(
                  -1,
                  currentMonth: visibleMonth,
                  firstAvailableMonth: account.firstAvailableMonth ??
                      accountsState.firstAvailableMonth,
                ),
                onNextMonth: () => _moveMonth(
                  1,
                  currentMonth: visibleMonth,
                  firstAvailableMonth: account.firstAvailableMonth ??
                      accountsState.firstAvailableMonth,
                ),
                history: AccountsPage._accountHistoryFor(
                  transactionsState.transactions,
                  account.id,
                  month: visibleMonth,
                ),
                onRegisterYield: () => AccountsPage._openAccountYieldForm(
                  context,
                  ref,
                  account,
                ),
              ),
            ),
    );
  }
}

class _MissingAccountView extends StatelessWidget {
  const _MissingAccountView({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ] else ...[
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 46,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                isLoading ? 'Carregando conta...' : 'Conta não encontrada.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!isLoading) ...[
                const SizedBox(height: 8),
                Text(
                  'Ela pode ter sido removida ou ainda não foi sincronizada na lista local.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDetailContent extends StatelessWidget {
  const _AccountDetailContent({
    required this.account,
    required this.displayCurrencyCode,
    required this.visibleMonth,
    required this.canGoPreviousMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.history,
    required this.onRegisterYield,
  });

  final AccountPreview account;
  final String displayCurrencyCode;
  final DateTime visibleMonth;
  final bool canGoPreviousMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final List<TransactionListItem> history;
  final VoidCallback onRegisterYield;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccountsMonthPager(
            month: visibleMonth,
            canGoPrevious: canGoPreviousMonth,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const SizedBox(height: 18),
          _AccountTile(
            account: account,
            displayCurrencyCode: displayCurrencyCode,
            onTap: null,
            onRegisterYield: onRegisterYield,
          ),
          const SizedBox(height: 18),
          Text(
            'Histórico da conta',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const _EmptyAccountHistory()
          else
            for (var index = 0; index < history.length; index++) ...[
              _AccountHistoryTile(
                account: account,
                transaction: history[index],
                onTap: () => context.push(
                  '/transactions/${history[index].kind.name}/${history[index].id}',
                ),
              ),
              if (index < history.length - 1)
                Divider(
                  color: colors.border,
                  height: 1,
                ),
            ],
        ],
      ),
    );
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
              'Ainda não há lançamentos nesta conta.',
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
    required this.onTap,
  });

  final AccountPreview account;
  final TransactionListItem transaction;
  final VoidCallback onTap;

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
        ? '${transaction.accountName} -> ${transaction.toAccountName ?? 'Conta'}'
        : '${transaction.categoryName} - ${transaction.paymentMethodLabel}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
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
                    '$detail - ${_shortDate(transaction.date)}',
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
      ),
    );
  }

  static String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

bool _isBeforeMonth(DateTime left, DateTime right) {
  return left.year < right.year ||
      (left.year == right.year && left.month < right.month);
}

bool _isAfterMonth(DateTime left, DateTime right) {
  return left.year > right.year ||
      (left.year == right.year && left.month > right.month);
}

DateTime _maxMonth(DateTime left, DateTime right) {
  return _isBeforeMonth(left, right) ? right : left;
}

class _AccountsSection extends StatelessWidget {
  const _AccountsSection({
    required this.accounts,
    required this.displayCurrencyCode,
    required this.onAdd,
    required this.onTapAccount,
    required this.onRegisterYield,
  });

  final List<AccountPreview> accounts;
  final String displayCurrencyCode;
  final VoidCallback onAdd;
  final ValueChanged<AccountPreview> onTapAccount;
  final ValueChanged<AccountPreview> onRegisterYield;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return SectionCard(
        title: 'Minhas contas',
        trailing: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Adicionar'),
        ),
        child: const _EmptyAccounts(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Minhas contas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 680;
            final cardWidth = isTablet
                ? ((constraints.maxWidth - 14) / 2)
                : constraints.maxWidth;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final account in accounts)
                  SizedBox(
                    width: cardWidth.toDouble(),
                    child: _AccountTile(
                      account: account,
                      displayCurrencyCode: displayCurrencyCode,
                      onTap: () => onTapAccount(account),
                      onRegisterYield: () => onRegisterYield(account),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.displayCurrencyCode,
    required this.onTap,
    required this.onRegisterYield,
  });

  final AccountPreview account;
  final String displayCurrencyCode;
  final VoidCallback? onTap;
  final VoidCallback onRegisterYield;

  @override
  Widget build(BuildContext context) {
    final baseColor = account.color;
    final gradientStart = _shiftColor(baseColor, lightnessDelta: 0.10);
    final gradientEnd = _shiftColor(baseColor, lightnessDelta: -0.12);
    final shouldShowConvertedBalance =
        account.currencyCode.toUpperCase() != displayCurrencyCode.toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  right: -48,
                  top: -54,
                  child: _AccountCardGlow(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                Positioned(
                  left: -60,
                  bottom: -70,
                  child: _AccountCardGlow(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                            foregroundColor: Colors.white,
                            child: Text(
                              _initialsFor(account.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${account.type} - ${account.bankName ?? 'Sem banco'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: onRegisterYield,
                            tooltip: 'Registrar rendimento',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.15),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.trending_up_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Saldo atual',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyUtils.formatCents(
                          account.balanceCents,
                          currencyCode: account.currencyCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      if (shouldShowConvertedBalance) ...[
                        const SizedBox(height: 2),
                        Text(
                          'aprox. ${CurrencyUtils.formatCents(
                            account.consolidatedBalanceCents,
                            currencyCode: displayCurrencyCode,
                          )}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _AccountCardMetric(
                              label: 'Inicial',
                              value: CurrencyUtils.formatCents(
                                account.initialBalanceCents,
                                currencyCode: account.currencyCode,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AccountCardMetric(
                              label: 'Receitas',
                              value: CurrencyUtils.formatCents(
                                account.monthlyIncomeCents,
                                currencyCode: account.currencyCode,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _AccountCardMetric(
                              label: 'Despesas',
                              value: CurrencyUtils.formatCents(
                                account.monthlyExpenseCents,
                                currencyCode: account.currencyCode,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AccountCardMetric(
                              label: 'Rendimentos',
                              value: CurrencyUtils.formatCents(
                                account.monthlyYieldCents,
                                currencyCode: account.currencyCode,
                              ),
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

  Color _shiftColor(Color color, {required double lightnessDelta}) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
  }
}

class _AccountCardGlow extends StatelessWidget {
  const _AccountCardGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 105,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _AccountCardMetric extends StatelessWidget {
  const _AccountCardMetric({
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
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
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

class _AccountYieldFormSheet extends StatefulWidget {
  const _AccountYieldFormSheet({
    required this.account,
    required this.onSubmit,
  });

  final AccountPreview account;
  final Future<void> Function({
    required int amountCents,
    required DateTime date,
  }) onSubmit;

  @override
  State<_AccountYieldFormSheet> createState() => _AccountYieldFormSheetState();
}

class _AccountYieldFormSheetState extends State<_AccountYieldFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _yieldController = TextEditingController();
  final _currentBalanceController = TextEditingController();
  late DateTime _date;
  bool _calculateFromCurrentBalance = false;
  bool _isSubmitting = false;

  AccountPreview get account => widget.account;

  int get _calculatedYieldCents {
    if (_calculateFromCurrentBalance) {
      return CurrencyUtils.parseToCents(_currentBalanceController.text) -
          account.balanceCents;
    }

    return CurrencyUtils.parseToCents(_yieldController.text);
  }

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _yieldController.addListener(_refreshPreview);
    _currentBalanceController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _yieldController.removeListener(_refreshPreview);
    _currentBalanceController.removeListener(_refreshPreview);
    _yieldController.dispose();
    _currentBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final calculatedYieldCents = _calculatedYieldCents;

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
                      'Registrar rendimento',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
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
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: account.color,
                        foregroundColor: Colors.white,
                        child: Text(
                          account.name.characters.take(2).toString(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Saldo anterior: ${CurrencyUtils.formatCents(
                                account.balanceCents,
                                currencyCode: account.currencyCode,
                              )}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Como informar?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: !_calculateFromCurrentBalance,
                    label: const Text('Valor do rendimento'),
                    avatar: const Icon(Icons.add_chart_rounded, size: 18),
                    onSelected: (_) {
                      setState(() => _calculateFromCurrentBalance = false);
                    },
                  ),
                  ChoiceChip(
                    selected: _calculateFromCurrentBalance,
                    label: const Text('Saldo atual'),
                    avatar: const Icon(Icons.account_balance_wallet_rounded,
                        size: 18),
                    onSelected: (_) {
                      setState(() => _calculateFromCurrentBalance = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_calculateFromCurrentBalance)
                TextFormField(
                  controller: _currentBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Saldo atual informado',
                    hintText: 'Ex: 2540,20',
                    prefixIcon: const Icon(Icons.payments_rounded),
                    helperText:
                        'O app calcula o rendimento comparando com o saldo anterior.',
                  ),
                  validator: (value) {
                    final currentBalanceCents =
                        CurrencyUtils.parseToCents(value ?? '');
                    if (currentBalanceCents <= 0) {
                      return 'Informe o saldo atual.';
                    }
                    if (currentBalanceCents <= account.balanceCents) {
                      return 'O saldo atual precisa ser maior que o saldo anterior.';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _yieldController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor do rendimento',
                    hintText: 'Ex: 32,45',
                    prefixIcon: Icon(Icons.trending_up_rounded),
                  ),
                  validator: (value) {
                    if (CurrencyUtils.parseToCents(value ?? '') <= 0) {
                      return 'Informe o valor do rendimento.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                  child: Text(_formatDate(_date)),
                ),
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          calculatedYieldCents > 0
                              ? 'Rendimento calculado: ${CurrencyUtils.formatCents(
                                  calculatedYieldCents,
                                  currencyCode: account.currencyCode,
                                )}'
                              : 'O rendimento entra como receita efetivada nesta conta.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting ? 'Salvando...' : 'Salvar rendimento',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amountCents = _calculatedYieldCents;
    if (amountCents <= 0) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        amountCents: amountCents,
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

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
              account.initialBalanceCents,
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
    _selectedColor =
        account?.colorHex ?? FinancialColorOptions.accountAndCard.first;
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
                runSpacing: 10,
                children: [
                  for (final color in FinancialColorOptions.accountAndCard)
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
    final checkColor =
        parsedColor.computeLuminance() > 0.55 ? Colors.black : Colors.white;

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
        child: isSelected ? Icon(Icons.check_rounded, color: checkColor) : null,
      ),
    );
  }
}
