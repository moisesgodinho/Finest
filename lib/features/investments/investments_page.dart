import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../shared/widgets/section_card.dart';
import 'investments_view_model.dart';

class InvestmentsPage extends ConsumerWidget {
  const InvestmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(investmentsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investimentos'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SectionCard(
              title: 'Carteira inicial',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyUtils.formatCents(state.totalInvestedCents),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${CurrencyUtils.formatCents(state.monthlyInvestedCents)} investidos neste mês',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar investimento'),
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
