import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../shared/widgets/section_card.dart';
import 'finest_pet_avatar.dart';
import 'pet_view_model.dart';

class PetPage extends ConsumerWidget {
  const PetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finest'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            if (state.isLoading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor: context.colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (state.errorMessage != null) ...[
              _PetStatusCard(message: state.errorMessage!),
              const SizedBox(height: 14),
            ],
            _PetHeroCard(state: state),
            const SizedBox(height: 18),
            _NextEvolutionCard(state: state),
            const SizedBox(height: 18),
            _PetMetrics(state: state),
            const SizedBox(height: 18),
            _EvolutionHistoryCard(state: state),
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

class _PetStatusCard extends StatelessWidget {
  const _PetStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
              ),
            ),
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
    final colors = context.colors;

    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: FinestPetAvatar(
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
                            color: colors.primary,
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
                  color: colors.textSecondary,
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
                      color: colors.textSecondary,
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
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors.primaryLight,
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
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Nv. $level',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.primary,
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

class _NextEvolutionCard extends StatelessWidget {
  const _NextEvolutionCard({required this.state});

  final PetState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nextLevel = state.nextLevel;
    final target = state.suggestedContributionTargetCents;
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return SectionCard(
      title: 'Próxima evolução',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextLevel == null) ...[
            Text(
              'Nível máximo alcançado. Agora o foco é manter consistência e proteger sua reserva.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ] else ...[
            Text(
              'Nv. ${nextLevel.level}: ${nextLevel.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              nextLevel.trigger,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: state.progressToNextLevel,
                minHeight: 10,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primaryLight),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${(state.progressToNextLevel * 100).round()}% concluído',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  'faltam ${state.remainingXp} XP',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PetInsightChip(
                label: 'Meta sugerida',
                value: target <= 0
                    ? 'sem renda'
                    : CurrencyUtils.formatCents(
                        target,
                        currencyCode: state.currencyCode,
                      ),
              ),
              _PetInsightChip(
                label: 'Aporte atual',
                value: CurrencyUtils.formatCents(
                  state.monthlyContributionCents,
                  currencyCode: state.currencyCode,
                ),
              ),
              _PetInsightChip(
                label: 'Runway',
                value: '${state.runwayMonths.toStringAsFixed(1)} mês',
              ),
              _PetInsightChip(
                label: 'Sequência',
                value: '${state.contributionStreakMonths} meses',
              ),
            ],
          ),
          if (state.lastEvolutionAt != null) ...[
            const SizedBox(height: 14),
            Text(
              'Última evolução em ${dateFormatter.format(state.lastEvolutionAt!)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PetInsightChip extends StatelessWidget {
  const _PetInsightChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
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
                      currencyCode: state.currencyCode,
                    ),
                    progress: state.contributionTargetProgress,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.flag_rounded,
                    title: 'Meta sugerida',
                    value: state.suggestedContributionTargetCents <= 0
                        ? 'sem renda'
                        : CurrencyUtils.formatCents(
                            state.suggestedContributionTargetCents,
                            currencyCode: state.currencyCode,
                          ),
                    progress: state.contributionTargetProgress,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.health_and_safety_rounded,
                    title: 'Reserva',
                    value: CurrencyUtils.formatCents(
                      state.emergencyReserveCents,
                      currencyCode: state.currencyCode,
                    ),
                    progress: state.runwayProgress,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PetMetricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Total investido',
                    value: CurrencyUtils.formatCents(
                      state.totalInvestedCents,
                      currencyCode: state.currencyCode,
                    ),
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
    final colors = context.colors;

    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.32 : 0.05),
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
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionHistoryCard extends StatelessWidget {
  const _EvolutionHistoryCard({required this.state});

  final PetState state;

  @override
  Widget build(BuildContext context) {
    final events = state.evolutionEvents;
    final colors = context.colors;

    return SectionCard(
      title: 'Histórico de evolução',
      child: events.isEmpty
          ? Text(
              'Quando um novo nível for alcançado, o marco aparece aqui com os dados financeiros daquele momento.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            )
          : Column(
              children: [
                for (final event in events.take(6)) ...[
                  _EvolutionHistoryTile(
                    event: event,
                    currencyCode: state.currencyCode,
                  ),
                  if (event != events.take(6).last)
                    Divider(height: 22, color: colors.border),
                ],
              ],
            ),
    );
  }
}

class _EvolutionHistoryTile extends StatelessWidget {
  const _EvolutionHistoryTile({
    required this.event,
    required this.currencyCode,
  });

  final PetEvolutionEvent event;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formatter = DateFormat('dd/MM/yyyy');
    final fromLevel = event.fromLevel == null ? null : 'Nv. ${event.fromLevel}';
    final levelLabel = fromLevel == null
        ? 'Começou no Nv. ${event.toLevel}'
        : '$fromLevel para Nv. ${event.toLevel}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: 0.12),
          foregroundColor: colors.primary,
          child: const Icon(Icons.auto_awesome_rounded, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      levelLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    formatter.format(event.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                event.reason,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PetInsightChip(
                    label: 'Aporte',
                    value: CurrencyUtils.formatCents(
                      event.monthlyContribution,
                      currencyCode: currencyCode,
                    ),
                  ),
                  _PetInsightChip(
                    label: 'Taxa',
                    value: '${(event.savingsRate * 100).round()}%',
                  ),
                  _PetInsightChip(
                    label: 'Runway',
                    value: '${event.runwayMonths.toStringAsFixed(1)} mês',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
              Divider(height: 20, color: context.colors.border),
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
    final colors = context.colors;
    final color = switch (status) {
      _EvolutionLevelStatus.completed => AppColors.success,
      _EvolutionLevelStatus.current => colors.primary,
      _EvolutionLevelStatus.locked => colors.textSecondary,
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
                        color: colors.textSecondary,
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
    final colors = context.colors;

    return SectionCard(
      title: 'Mecânicas',
      child: Column(
        children: [
          for (final mechanic in petMechanics) ...[
            _MechanicRow(mechanic: mechanic),
            if (mechanic != petMechanics.last)
              Divider(height: 22, color: context.colors.border),
          ],
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
                  Icon(Icons.calendar_month_rounded, color: colors.primary),
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
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: 0.10),
          foregroundColor: colors.primary,
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
                      color: colors.textSecondary,
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
