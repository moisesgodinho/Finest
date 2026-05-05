import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/models/subcategory_model.dart';
import '../../shared/widgets/section_card.dart';
import 'reports_view_model.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsViewModelProvider);
    final viewModel = ref.read(reportsViewModelProvider.notifier);

    ref.listen(reportsViewModelProvider.select((state) => state.errorMessage), (
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
      appBar: AppBar(title: const Text('Relatórios')),
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
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            _MonthSelector(
              selectedMonth: state.selectedMonth,
              onPrevious: viewModel.selectPreviousMonth,
              onNext: viewModel.selectNextMonth,
            ),
            const SizedBox(height: 14),
            _MonthlySummarySection(
              summary: state.summary,
              currencyCode: state.currencyCode,
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Fluxo de caixa por mês',
              child: _CashFlowChart(
                items: state.cashFlow,
                currencyCode: state.currencyCode,
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Comparativo mês a mês',
              child: _ComparisonSection(
                comparison: state.comparison,
                currencyCode: state.currencyCode,
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: state.selectedType == 'expense'
                  ? 'Gastos por categoria'
                  : 'Receitas por categoria',
              child: _CategoryBreakdownSection(
                state: state,
                viewModel: viewModel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              tooltip: 'Mês anterior',
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                AppDateUtils.monthYearLabel(selectedMonth),
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
      ),
    );
  }
}

class _MonthlySummarySection extends StatelessWidget {
  const _MonthlySummarySection({
    required this.summary,
    required this.currencyCode,
  });

  final MonthlyReportSummary summary;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ReportMetricCard(
          title: 'Receitas',
          value: CurrencyUtils.formatCents(
            summary.incomeCents,
            currencyCode: currencyCode,
          ),
          icon: Icons.trending_up_rounded,
          color: context.colors.success,
        ),
        _ReportMetricCard(
          title: 'Despesas',
          value: CurrencyUtils.formatCents(
            summary.totalExpenseCents,
            currencyCode: currencyCode,
          ),
          icon: Icons.trending_down_rounded,
          color: AppColors.danger,
        ),
        _ReportMetricCard(
          title: 'Saldo do mês',
          value: CurrencyUtils.formatCents(
            summary.netCents,
            currencyCode: currencyCode,
          ),
          icon: Icons.account_balance_wallet_rounded,
          color:
              summary.netCents >= 0 ? context.colors.primary : AppColors.danger,
        ),
        _ReportMetricCard(
          title: 'Pendentes',
          value: CurrencyUtils.formatCents(
            summary.pendingCents,
            currencyCode: currencyCode,
          ),
          icon: Icons.schedule_rounded,
          color: context.colors.warning,
        ),
        _ReportMetricCard(
          title: 'No cartão',
          value: CurrencyUtils.formatCents(
            summary.cardExpenseCents,
            currencyCode: currencyCode,
          ),
          icon: Icons.credit_card_rounded,
          color: context.colors.info,
        ),
        _ReportMetricCard(
          title: 'Na conta',
          value: CurrencyUtils.formatCents(
            summary.accountExpenseCents,
            currencyCode: currencyCode,
          ),
          icon: Icons.account_balance_rounded,
          color: context.colors.primary,
        ),
      ],
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final availableWidth = MediaQuery.sizeOf(context).width - 40;
    final cardWidth = availableWidth >= 720
        ? (availableWidth - 24) / 3
        : (availableWidth - 12) / 2;

    return SizedBox(
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  colors.shadow.withValues(alpha: colors.isDark ? 0.30 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.13),
                foregroundColor: color,
                child: Icon(icon, size: 19),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({
    required this.items,
    required this.currencyCode,
  });

  final List<CashFlowMonthReport> items;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<int>(
      0,
      (max, item) => [
        max,
        item.summary.incomeCents,
        item.summary.totalExpenseCents,
      ].reduce((left, right) => left > right ? left : right),
    );

    if (items.isEmpty || maxValue <= 0) {
      return const _EmptyReportMessage(
        icon: Icons.stacked_bar_chart_rounded,
        message: 'O fluxo aparece quando houver receitas ou despesas.',
      );
    }

    return Column(
      children: [
        for (final item in items)
          _CashFlowRow(
            item: item,
            maxValue: maxValue,
            currencyCode: currencyCode,
          ),
      ],
    );
  }
}

class _CashFlowRow extends StatelessWidget {
  const _CashFlowRow({
    required this.item,
    required this.maxValue,
    required this.currencyCode,
  });

  final CashFlowMonthReport item;
  final int maxValue;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final incomePercent = item.summary.incomeCents / maxValue;
    final expensePercent = item.summary.totalExpenseCents / maxValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              _shortMonth(item.month),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _ProgressLine(
                  value: incomePercent,
                  color: colors.success,
                  backgroundColor: colors.border,
                ),
                const SizedBox(height: 5),
                _ProgressLine(
                  value: expensePercent,
                  color: AppColors.danger,
                  backgroundColor: colors.border,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 98,
            child: Text(
              CurrencyUtils.formatCents(
                item.summary.netCents,
                currencyCode: currencyCode,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: item.summary.netCents >= 0
                        ? colors.primary
                        : AppColors.danger,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: 7,
        color: color,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({
    required this.comparison,
    required this.currencyCode,
  });

  final MonthComparisonReport comparison;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ComparisonRow(
          title: 'Receitas',
          currentCents: comparison.current.incomeCents,
          previousCents: comparison.previous.incomeCents,
          currencyCode: currencyCode,
          positiveIsGood: true,
        ),
        _ComparisonRow(
          title: 'Despesas',
          currentCents: comparison.current.totalExpenseCents,
          previousCents: comparison.previous.totalExpenseCents,
          currencyCode: currencyCode,
          positiveIsGood: false,
        ),
        _ComparisonRow(
          title: 'Resultado',
          currentCents: comparison.current.netCents,
          previousCents: comparison.previous.netCents,
          currencyCode: currencyCode,
          positiveIsGood: true,
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.title,
    required this.currentCents,
    required this.previousCents,
    required this.currencyCode,
    required this.positiveIsGood,
  });

  final String title;
  final int currentCents;
  final int previousCents;
  final String currencyCode;
  final bool positiveIsGood;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final change = _changePercent(currentCents, previousCents);
    final isPositive = change >= 0;
    final changeColor =
        isPositive == positiveIsGood ? colors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.formatCents(
                  currentCents,
                  currencyCode: currencyCode,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}% vs. mês anterior',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownSection extends StatelessWidget {
  const _CategoryBreakdownSection({
    required this.state,
    required this.viewModel,
  });

  final ReportsState state;
  final ReportsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TypeSelector(
          selectedType: state.selectedType,
          onChanged: viewModel.selectType,
        ),
        const SizedBox(height: 12),
        _FilterRow(
          categories: state.filterCategories,
          subcategories: state.filterSubcategories,
          selectedCategoryId: state.selectedCategoryId,
          selectedSubcategoryId: state.selectedSubcategoryId,
          onCategoryChanged: viewModel.selectCategory,
          onSubcategoryChanged: viewModel.selectSubcategory,
        ),
        const SizedBox(height: 14),
        if (state.categoryItems.isEmpty)
          const _EmptyReportMessage(
            icon: Icons.pie_chart_outline_rounded,
            message: 'Nenhum lançamento encontrado para os filtros.',
          )
        else
          for (final item in state.categoryItems)
            _CategoryBreakdownTile(
              item: item,
              currencyCode: state.currencyCode,
            ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'expense',
          label: Text('Despesas'),
          icon: Icon(Icons.trending_down_rounded),
        ),
        ButtonSegment(
          value: 'income',
          label: Text('Receitas'),
          icon: Icon(Icons.trending_up_rounded),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.categories,
    required this.subcategories,
    required this.selectedCategoryId,
    required this.selectedSubcategoryId,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
  });

  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final int? selectedCategoryId;
  final int? selectedSubcategoryId;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onSubcategoryChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final categoryField = DropdownButtonFormField<int?>(
          initialValue: selectedCategoryId,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todas'),
            ),
            for (final category in categories)
              DropdownMenuItem<int?>(
                value: category.id,
                child: Text(category.name),
              ),
          ],
          onChanged: onCategoryChanged,
        );
        final subcategoryField = DropdownButtonFormField<int?>(
          initialValue: selectedSubcategoryId,
          decoration: const InputDecoration(
            labelText: 'Subcategoria',
            prefixIcon: Icon(Icons.label_outline_rounded),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todas'),
            ),
            for (final subcategory in subcategories)
              DropdownMenuItem<int?>(
                value: subcategory.id,
                child: Text(subcategory.name),
              ),
          ],
          onChanged: selectedCategoryId == null ? null : onSubcategoryChanged,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: categoryField),
              const SizedBox(width: 12),
              Expanded(child: subcategoryField),
            ],
          );
        }

        return Column(
          children: [
            categoryField,
            const SizedBox(height: 12),
            subcategoryField,
          ],
        );
      },
    );
  }
}

class _CategoryBreakdownTile extends StatelessWidget {
  const _CategoryBreakdownTile({
    required this.item,
    required this.currencyCode,
  });

  final CategoryBreakdownReport item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: item.category.color.withValues(alpha: 0.13),
                foregroundColor: item.category.color,
                child: Icon(item.category.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      item.transactionCount == 1
                          ? '1 lançamento'
                          : '${item.transactionCount} lançamentos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.formatCents(
                      item.totalCents,
                      currencyCode: currencyCode,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    '${(item.percent * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressLine(
            value: item.percent,
            color: item.category.color,
            backgroundColor: colors.border,
          ),
          if (item.subcategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final subcategory in item.subcategories.take(4))
              _SubcategoryRow(
                item: subcategory,
                currencyCode: currencyCode,
              ),
          ],
        ],
      ),
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.item,
    required this.currencyCode,
  });

  final SubcategoryBreakdownReport item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            CurrencyUtils.formatCents(
              item.totalCents,
              currencyCode: currencyCode,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReportMessage extends StatelessWidget {
  const _EmptyReportMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(icon, size: 42, color: colors.textSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _shortMonth(DateTime date) {
  const months = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];
  return months[date.month - 1];
}

double _changePercent(int current, int previous) {
  if (previous == 0) {
    if (current == 0) {
      return 0;
    }
    return current > 0 ? 100 : -100;
  }

  return ((current - previous) / previous.abs()) * 100;
}
