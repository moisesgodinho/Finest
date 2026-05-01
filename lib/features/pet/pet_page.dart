import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../shared/widgets/section_card.dart';
import 'finance_pet_avatar.dart';
import 'pet_view_model.dart';

class PetPage extends ConsumerWidget {
  const PetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinancePet'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _PetHeroCard(state: state),
            const SizedBox(height: 18),
            _PetMetrics(state: state),
            const SizedBox(height: 18),
            _EvolutionTrackCard(state: state),
            const SizedBox(height: 18),
            const _MechanicsCard(),
          ],
        ),
      ),
    );
  }
}

class _PetHeroCard extends StatelessWidget {
  const _PetHeroCard({required this.state});

  final PetState state;

  @override
  Widget build(BuildContext context) {
    final currentLevel = state.currentLevel;

    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: FinancePetAvatar(
              level: state.level,
              progress: state.progressToNextLevel,
              size: 190,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.petName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nível ${state.level}: ${currentLevel.title}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                ),
              ),
              _LevelBadge(level: state.level),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            currentLevel.concept,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${state.xp} XP',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                'faltam ${state.remainingXp} XP',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: state.progressToNextLevel,
              minHeight: 12,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryLight,
              ),
            ),
          ),
          if (state.hasEarlyContributionBuff) ...[
            const SizedBox(height: 14),
            const _BuffBanner(),
          ],
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Nv. $level',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _BuffBanner extends StatelessWidget {
  const _BuffBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buff ativo: aporte antes do dia 10 acelera a evolução em 1.5x neste mês.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetMetrics extends StatelessWidget {
  const _PetMetrics({required this.state});

  final PetState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hábitos do mês',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.savings_rounded,
                    title: 'Aporte mensal',
                    value: CurrencyUtils.formatCents(
                      state.monthlyContributionCents,
                    ),
                    progress: state.energyProgress,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Total investido',
                    value: CurrencyUtils.formatCents(state.totalInvestedCents),
                    progress: state.runwayProgress,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.fact_check_rounded,
                    title: 'Registro',
                    value: '${state.trackedDays}/15 dias',
                    progress: state.trackingProgress,
                    color: AppColors.purple,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.bolt_rounded,
                    title: 'Energia',
                    value: '${(state.savingsRate * 100).round()}%',
                    progress: state.energyProgress,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.repeat_rounded,
                    title: 'Consistência',
                    value: '${state.contributionStreakMonths} meses',
                    progress: state.consistencyProgress,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.shield_rounded,
                    title: 'Runway',
                    value: '${state.runwayMonths.toStringAsFixed(1)} mês',
                    progress: state.runwayProgress,
                    color: AppColors.primary,
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

class _PetMetricCard extends StatelessWidget {
  const _PetMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(icon, size: 21),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            maxLines: 1,
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionTrackCard extends StatelessWidget {
  const _EvolutionTrackCard({required this.state});

  final PetState state;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Jornada de evolução',
      child: Column(
        children: [
          for (final level in petEvolutionLevels) ...[
            _EvolutionLevelTile(
              level: level,
              status: _statusFor(level.level),
            ),
            if (level != petEvolutionLevels.last)
              const Divider(height: 20, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  _EvolutionLevelStatus _statusFor(int level) {
    if (level < state.level) {
      return _EvolutionLevelStatus.completed;
    }
    if (level == state.level) {
      return _EvolutionLevelStatus.current;
    }
    return _EvolutionLevelStatus.locked;
  }
}

enum _EvolutionLevelStatus { completed, current, locked }

class _EvolutionLevelTile extends StatelessWidget {
  const _EvolutionLevelTile({
    required this.level,
    required this.status,
  });

  final PetEvolutionLevel level;
  final _EvolutionLevelStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _EvolutionLevelStatus.completed => AppColors.success,
      _EvolutionLevelStatus.current => AppColors.primary,
      _EvolutionLevelStatus.locked => AppColors.textSecondary,
    };
    final icon = switch (status) {
      _EvolutionLevelStatus.completed => Icons.check_rounded,
      _EvolutionLevelStatus.current => Icons.auto_awesome_rounded,
      _EvolutionLevelStatus.locked => Icons.lock_outline_rounded,
    };

    return Opacity(
      opacity: status == _EvolutionLevelStatus.locked ? 0.62 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nível ${level.level}: ${level.title}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  level.trigger,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  level.visual,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
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

class _MechanicsCard extends StatelessWidget {
  const _MechanicsCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Mecânicas',
      child: Column(
        children: [
          for (final mechanic in petMechanics) ...[
            _MechanicRow(mechanic: mechanic),
            if (mechanic != petMechanics.last)
              const Divider(height: 22, color: AppColors.border),
          ],
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A ideia de "pagar-se primeiro" entra como multiplicador de XP quando o aporte acontece antes do dia 10.',
                      style: Theme.of(context).textTheme.bodyMedium,
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

class _MechanicRow extends StatelessWidget {
  const _MechanicRow({required this.mechanic});

  final PetMechanic mechanic;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
          foregroundColor: AppColors.primary,
          child: Icon(_iconFor(mechanic.title), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mechanic.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                mechanic.gameFunction,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 3),
              Text(
                mechanic.financialMeaning,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String title) {
    return switch (title) {
      'Comida' => Icons.restaurant_rounded,
      'Higiene' => Icons.cleaning_services_rounded,
      'Energia' => Icons.bolt_rounded,
      _ => Icons.health_and_safety_rounded,
    };
  }
}
