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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              title: 'Contas',
              subtitle: AppDateUtils.monthYearLabel(DateTime.now()),
            ),
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
                  value: CurrencyUtils.formatCents(723040),
                ),
                _AccountStatCard(
                  icon: Icons.savings_rounded,
                  title: 'Poupança',
                  value: CurrencyUtils.formatCents(525035),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Minhas contas',
              trailing: Text(
                'Ver todas',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              child: Column(
                children: [
                  for (final account in state.accounts)
                    _AccountTile(account: account),
                ],
              ),
            ),
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
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

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
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded),
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final AccountPreview account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: account.color,
            child: Text(
              account.name.substring(0, 2).toLowerCase(),
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
                  '${account.type} • final ${account.lastDigits ?? '----'}',
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
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
