import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/credit_card_preview.dart';
import '../../shared/widgets/section_card.dart';
import 'cards_view_model.dart';

class CardsPage extends ConsumerWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardsViewModelProvider);
    final primaryCard = state.cards.first;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardsHeader(monthLabel: AppDateUtils.monthYearLabel(DateTime.now())),
            const SizedBox(height: 20),
            _HeroCreditCard(card: primaryCard),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CardsMetric(
                  title: 'Total em faturas',
                  value: CurrencyUtils.formatCents(state.totalInvoicesCents),
                  icon: Icons.receipt_long_rounded,
                ),
                _CardsMetric(
                  title: 'Limite disponível',
                  value: CurrencyUtils.formatCents(state.availableLimitCents),
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _CardsMetric(
                  title: 'Próximos vencimentos',
                  value: '${state.cards.length} cartões',
                  icon: Icons.calendar_month_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Meus cartões',
              child: Column(
                children: [
                  for (final card in state.cards) _CreditCardTile(card: card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsHeader extends StatelessWidget {
  const _CardsHeader({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cartões', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(monthLabel, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.add_card_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _HeroCreditCard extends StatelessWidget {
  const _HeroCreditCard({required this.card});

  final CreditCardPreview card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${card.name} •••• ${card.lastDigits}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Fatura atual',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                Text(
                  CurrencyUtils.formatCents(card.invoiceCents),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Vencimento ${card.dueDay}/06',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 92,
            width: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: card.usedPercent,
                  strokeWidth: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF8EE6A4),
                  ),
                ),
                Center(
                  child: Text(
                    '${(card.usedPercent * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
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

class _CardsMetric extends StatelessWidget {
  const _CardsMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.primary,
            child: Icon(icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ),
        ],
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  const _CreditCardTile({required this.card});

  final CreditCardPreview card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: card.color,
            child: Text(
              card.name.substring(0, 2).toLowerCase(),
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
                  '${card.name} •••• ${card.lastDigits}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: card.usedPercent,
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(card.color),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Utilizado ${CurrencyUtils.formatCents(card.invoiceCents)} de ${CurrencyUtils.formatCents(card.limitCents)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.formatCents(card.invoiceCents),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    '${(card.usedPercent * 100).round()}%',
                    style: TextStyle(
                      color: card.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
