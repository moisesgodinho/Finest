import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../shared/widgets/section_card.dart';
import 'pet_view_model.dart';

class PetPage extends ConsumerWidget {
  const PetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet financeiro'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SectionCard(
              title: state.petName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        size: 86,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    state.currentStage,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nível ${state.level} • ${state.xp} XP',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (state.xp % 500) / 500,
                      minHeight: 10,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Total investido: ${CurrencyUtils.formatCents(state.totalInvestedCents)}',
                    style: Theme.of(context).textTheme.bodyLarge,
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
