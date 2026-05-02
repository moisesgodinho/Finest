import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/models/subcategory_model.dart';
import '../../shared/widgets/section_card.dart';
import 'categories_view_model.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriesViewModelProvider);
    final viewModel = ref.read(categoriesViewModelProvider.notifier);

    ref.listen(
      categoriesViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        actions: [
          IconButton(
            tooltip: 'Nova categoria',
            onPressed: () => _openCategoryForm(context, viewModel, state),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
            _CategoryReportHeader(summary: state.reportSummary),
            const SizedBox(height: 14),
            _CategoryReportCard(
              items: state.reportItems,
              summary: state.reportSummary,
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Organização das categorias',
              trailing: IconButton(
                tooltip: 'Nova categoria',
                onPressed: () => _openCategoryForm(context, viewModel, state),
                icon: const Icon(Icons.add_rounded),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeSelector(
                    selectedType: state.selectedType,
                    onChanged: viewModel.selectType,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state.selectedType == 'expense'
                        ? 'Categorias de despesas'
                        : 'Categorias de receitas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  if (state.visibleCategories.isEmpty)
                    _EmptyCategoriesMessage(
                      type: state.selectedType,
                      onCreate: () =>
                          _openCategoryForm(context, viewModel, state),
                    )
                  else
                    for (final category in state.visibleCategories)
                      _CategoryTile(
                        category: category,
                        subcategories: state.subcategoriesFor(category.id),
                        onEdit: () => _openCategoryForm(
                          context,
                          viewModel,
                          state,
                          category: category,
                        ),
                        onDelete: () => _confirmDeleteCategory(
                          context,
                          viewModel,
                          category,
                        ),
                        onCreateSubcategory: () => _openSubcategoryForm(
                          context,
                          viewModel,
                          category: category,
                        ),
                        onEditSubcategory: (subcategory) =>
                            _openSubcategoryForm(
                          context,
                          viewModel,
                          category: category,
                          subcategory: subcategory,
                        ),
                        onDeleteSubcategory: (subcategory) =>
                            _confirmDeleteSubcategory(
                          context,
                          viewModel,
                          subcategory,
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

  Future<void> _openCategoryForm(
    BuildContext context,
    CategoriesViewModel viewModel,
    CategoriesState state, {
    CategoryModel? category,
  }) async {
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
        return _CategoryFormSheet(
          category: category,
          type: category?.type ?? state.selectedType,
          onSubmit: ({
            required String name,
            required String type,
            required String icon,
            required String color,
          }) async {
            if (category == null) {
              await viewModel.createCategory(
                name: name,
                type: type,
                icon: icon,
                color: color,
              );
            } else {
              await viewModel.updateCategory(
                categoryId: category.id,
                name: name,
                icon: icon,
                color: color,
              );
            }
          },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            category == null ? 'Categoria criada.' : 'Categoria atualizada.',
          ),
        ),
      );
    }
  }

  Future<void> _openSubcategoryForm(
    BuildContext context,
    CategoriesViewModel viewModel, {
    required CategoryModel category,
    SubcategoryModel? subcategory,
  }) async {
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
        return _SubcategoryFormSheet(
          category: category,
          subcategory: subcategory,
          onSubmit: (name) async {
            if (subcategory == null) {
              await viewModel.createSubcategory(
                categoryId: category.id,
                name: name,
              );
            } else {
              await viewModel.updateSubcategory(
                subcategoryId: subcategory.id,
                name: name,
              );
            }
          },
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            subcategory == null
                ? 'Subcategoria criada.'
                : 'Subcategoria atualizada.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    CategoriesViewModel viewModel,
    CategoryModel category,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir categoria?'),
          content: Text(
            'A categoria "${category.name}" só poderá ser excluída se não houver lançamentos usando ela.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await viewModel.deleteCategory(category.id);
    }
  }

  Future<void> _confirmDeleteSubcategory(
    BuildContext context,
    CategoriesViewModel viewModel,
    SubcategoryModel subcategory,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir subcategoria?'),
          content: Text('Excluir "${subcategory.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await viewModel.deleteSubcategory(subcategory.id);
    }
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: onPrevious,
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
            tooltip: 'Próximo mês',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CategoryReportHeader extends StatelessWidget {
  const _CategoryReportHeader({required this.summary});

  final CategoryReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Resumo por categoria',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ReportMetric(
                  icon: Icons.pie_chart_rounded,
                  label: 'Total gasto',
                  value: CurrencyUtils.formatCents(summary.totalExpenseCents),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetric(
                  icon: Icons.receipt_long_rounded,
                  label: 'Lançamentos',
                  value: '${summary.transactionCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReportMetric(
                  icon: Icons.check_circle_rounded,
                  label: 'Efetivado',
                  value: CurrencyUtils.formatCents(summary.paidExpenseCents),
                  tone: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetric(
                  icon: Icons.schedule_rounded,
                  label: 'Previsto',
                  value: CurrencyUtils.formatCents(
                    summary.pendingExpenseCents,
                  ),
                  tone: AppColors.warning,
                ),
              ),
            ],
          ),
          if (summary.biggestCategory != null) ...[
            const SizedBox(height: 14),
            _TopCategoryInsight(item: summary.biggestCategory!),
          ],
        ],
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = tone ?? colors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
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

class _TopCategoryInsight extends StatelessWidget {
  const _TopCategoryInsight({required this.item});

  final CategoryReportItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.category.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: item.category.color.withValues(alpha: 0.14),
            foregroundColor: item.category.color,
            child: Icon(item.category.icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Maior categoria: ${item.category.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            _percentLabel(item.percent),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryReportCard extends StatelessWidget {
  const _CategoryReportCard({
    required this.items,
    required this.summary,
  });

  final List<CategoryReportItem> items;
  final CategoryReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Gastos por categoria',
      trailing: Text(
        '${summary.categoryCount} categorias',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      child: items.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.pie_chart_outline_rounded,
              message: 'Nenhuma despesa encontrada neste mês.',
            )
          : Column(
              children: [
                for (final item in items) ...[
                  _CategoryReportTile(item: item),
                  if (item != items.last)
                    Divider(height: 18, color: context.colors.border),
                ],
              ],
            ),
    );
  }
}

class _CategoryReportTile extends StatelessWidget {
  const _CategoryReportTile({required this.item});

  final CategoryReportItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        leading: CircleAvatar(
          backgroundColor: item.category.color.withValues(alpha: 0.12),
          foregroundColor: item.category.color,
          child: Icon(item.category.icon, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              CurrencyUtils.formatCents(item.totalCents),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_countLabel(item.transactionCount)} • ${_percentLabel(item.percent)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.percent.clamp(0.0, 1.0).toDouble(),
                  minHeight: 7,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.category.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          _PaidPendingBreakdown(item: item),
          const SizedBox(height: 10),
          for (final subcategory in item.subcategories) ...[
            _SubcategoryBreakdownRow(
              subcategory: subcategory,
              color: item.category.color,
            ),
            if (subcategory != item.subcategories.last)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PaidPendingBreakdown extends StatelessWidget {
  const _PaidPendingBreakdown({required this.item});

  final CategoryReportItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniBreakdownPill(
            label: 'Efetivado',
            value: CurrencyUtils.formatCents(item.paidCents),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniBreakdownPill(
            label: 'Previsto',
            value: CurrencyUtils.formatCents(item.pendingCents),
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _MiniBreakdownPill extends StatelessWidget {
  const _MiniBreakdownPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SubcategoryBreakdownRow extends StatelessWidget {
  const _SubcategoryBreakdownRow({
    required this.subcategory,
    required this.color,
  });

  final SubcategoryReportItem subcategory;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subcategory.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatCents(subcategory.totalCents),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: subcategory.percent.clamp(0.0, 1.0).toDouble(),
                  minHeight: 5,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _percentLabel(subcategory.percent),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: colors.textSecondary, size: 38),
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
          icon: Icon(Icons.arrow_upward_rounded),
        ),
        ButtonSegment(
          value: 'income',
          label: Text('Receitas'),
          icon: Icon(Icons.arrow_downward_rounded),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _EmptyCategoriesMessage extends StatelessWidget {
  const _EmptyCategoriesMessage({
    required this.type,
    required this.onCreate,
  });

  final String type;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(Icons.category_outlined, color: colors.textSecondary, size: 44),
          const SizedBox(height: 12),
          Text(
            type == 'expense'
                ? 'Nenhuma categoria de despesa.'
                : 'Nenhuma categoria de receita.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Crie categorias para organizar melhor seus lançamentos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Criar categoria'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.subcategories,
    required this.onEdit,
    required this.onDelete,
    required this.onCreateSubcategory,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
  });

  final CategoryModel category;
  final List<SubcategoryModel> subcategories;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCreateSubcategory;
  final ValueChanged<SubcategoryModel> onEditSubcategory;
  final ValueChanged<SubcategoryModel> onDeleteSubcategory;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: CircleAvatar(
              backgroundColor: category.color.withValues(alpha: 0.14),
              foregroundColor: category.color,
              child: Icon(category.icon),
            ),
            title: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${subcategories.length} subcategorias',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Ações',
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir'),
                    ),
                  ],
                ),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
            children: [
              if (subcategories.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nenhuma subcategoria ainda.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                for (final subcategory in subcategories)
                  _SubcategoryTile(
                    subcategory: subcategory,
                    onEdit: () => onEditSubcategory(subcategory),
                    onDelete: () => onDeleteSubcategory(subcategory),
                  ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onCreateSubcategory,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Subcategoria'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.subcategory,
    required this.onEdit,
    required this.onDelete,
  });

  final SubcategoryModel subcategory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right_rounded,
              color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subcategory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton(
            tooltip: 'Editar subcategoria',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Excluir subcategoria',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({
    required this.type,
    required this.onSubmit,
    this.category,
  });

  final String type;
  final CategoryModel? category;
  final Future<void> Function({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) onSubmit;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _iconName;
  late String _colorHex;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _iconName = category?.iconName ?? _defaultIconForType(widget.type);
    _colorHex = category?.colorHex ?? _defaultColorForType(widget.type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

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
                isEditing ? 'Editar categoria' : 'Nova categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Text('Ícone', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in categoryIconOptions)
                    _IconChoice(
                      option: option,
                      selected: option.name == _iconName,
                      onTap: () => setState(() => _iconName = option.name),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Cor', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final colorHex in categoryColorOptions)
                    _ColorChoice(
                      colorHex: colorHex,
                      selected: colorHex == _colorHex,
                      onTap: () => setState(() => _colorHex = colorHex),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar'),
                ),
              ),
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
        type: widget.type,
        icon: _iconName,
        color: _colorHex,
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
}

class _SubcategoryFormSheet extends StatefulWidget {
  const _SubcategoryFormSheet({
    required this.category,
    required this.onSubmit,
    this.subcategory,
  });

  final CategoryModel category;
  final SubcategoryModel? subcategory;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_SubcategoryFormSheet> createState() => _SubcategoryFormSheetState();
}

class _SubcategoryFormSheetState extends State<_SubcategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.subcategory?.name ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subcategory != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Editar subcategoria' : 'Nova subcategoria',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              widget.category.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o nome.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_isSubmitting ? 'Salvando...' : 'Salvar'),
              ),
            ),
          ],
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
      await widget.onSubmit(_nameController.text.trim());
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

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CategoryIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: option.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.accentSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Icon(
            option.icon,
            color: selected ? colors.onPrimary : colors.primary,
          ),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(colorHex);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? context.colors.textPrimary : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

String _percentLabel(double value) {
  final percent = (value * 100).clamp(0, 999).toDouble();
  final hasDecimal = percent < 10 && percent != percent.roundToDouble();
  return '${percent.toStringAsFixed(hasDecimal ? 1 : 0).replaceAll('.', ',')}%';
}

String _countLabel(int count) {
  return count == 1 ? '1 lançamento' : '$count lançamentos';
}

String _defaultIconForType(String type) {
  return type == 'income' ? 'income' : 'category';
}

String _defaultColorForType(String type) {
  return type == 'income' ? '#0A8F4D' : '#006B4F';
}

Color _colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? AppColors.primary : Color(parsed);
}
