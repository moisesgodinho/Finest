import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/models/credit_card_invoice_preview.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/subcategory_model.dart';
import '../../shared/widgets/section_card.dart';
import 'cards_view_model.dart';

class CreditCardInvoicePage extends ConsumerStatefulWidget {
  const CreditCardInvoicePage({
    super.key,
    required this.cardId,
    required this.initialMonth,
    required this.initialYear,
  });

  final int cardId;
  final int initialMonth;
  final int initialYear;

  @override
  ConsumerState<CreditCardInvoicePage> createState() =>
      _CreditCardInvoicePageState();
}

class _CreditCardInvoicePageState extends ConsumerState<CreditCardInvoicePage> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialYear, widget.initialMonth);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardsViewModelProvider);
    final viewModel = ref.read(cardsViewModelProvider.notifier);

    ref.listen(cardsViewModelProvider.select((state) => state.errorMessage), (
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

    final card = _findCard(state);

    if (card == null) {
      if (state.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Fatura')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Fatura')),
        body: const Center(
          child: Text('Cartão não encontrado.'),
        ),
      );
    }

    final invoice = state.invoiceForCardMonth(
      card,
      month: _visibleMonth.month,
      year: _visibleMonth.year,
    );
    final invoiceMonths = state.invoiceMonthsForCard(card);
    final expenseCategories = state.expenseCategories;
    final categorySpending = _buildCategorySpending(
      invoice,
      expenseCategories,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Fatura ${card.name}'),
        actions: [
          PopupMenuButton<DateTime>(
            tooltip: 'Selecionar fatura',
            icon: const Icon(Icons.calendar_month_rounded),
            onSelected: (month) {
              setState(() => _visibleMonth = month);
            },
            itemBuilder: (context) {
              return [
                for (final month in invoiceMonths)
                  PopupMenuItem(
                    value: month,
                    child: Text(AppDateUtils.monthYearLabel(month)),
                  ),
              ];
            },
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
            _InvoiceHero(
              invoice: invoice,
              onPrevious: () => _moveMonth(-1),
              onNext: () => _moveMonth(1),
              onPay: invoice.canPay && invoice.id > 0
                  ? () => _confirmPayInvoice(context, viewModel, invoice)
                  : null,
            ),
            const SizedBox(height: 14),
            if (invoice.isPaid)
              const _LockedInvoiceNotice()
            else if (invoice.status == 'closed')
              const _ClosedInvoiceNotice(),
            if (invoice.isPaid || invoice.status == 'closed')
              const SizedBox(height: 14),
            SectionCard(
              title: 'Pagamento',
              child: _PaymentAccountInfo(invoice: invoice),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Gastos por categoria',
              child: _CategorySpendingChart(spending: categorySpending),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Compras da fatura',
              trailing: Text(
                '${invoice.transactions.length} itens',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              child: invoice.transactions.isEmpty
                  ? const _EmptyInvoicePurchases()
                  : Column(
                      children: [
                        for (final transaction in invoice.transactions)
                          _InvoicePurchaseTile(
                            transaction: transaction,
                            isLocked: invoice.isPaid,
                            onEdit: () => _openEditPurchaseSheet(
                              context,
                              viewModel,
                              invoice,
                              transaction,
                              expenseCategories,
                              state.subcategories,
                            ),
                            onDelete: () => _confirmDeletePurchase(
                              context,
                              viewModel,
                              invoice,
                              transaction,
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

  List<_CategorySpending> _buildCategorySpending(
    CreditCardInvoicePreview invoice,
    List<CategoryModel> categories,
  ) {
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final totalsByCategory = <int, int>{};
    final countsByCategory = <int, int>{};

    for (final transaction in invoice.transactions) {
      totalsByCategory.update(
        transaction.categoryId,
        (total) => total + transaction.amountCents,
        ifAbsent: () => transaction.amountCents,
      );
      countsByCategory.update(
        transaction.categoryId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final spending = [
      for (final entry in totalsByCategory.entries)
        _CategorySpending(
          categoryId: entry.key,
          name: categoriesById[entry.key]?.name ??
              _categoryNameFromInvoice(invoice, entry.key),
          amountCents: entry.value,
          transactionCount: countsByCategory[entry.key] ?? 0,
          color: categoriesById[entry.key]?.color,
        ),
    ]..sort((a, b) => b.amountCents.compareTo(a.amountCents));

    final usedColors = <int>{};
    return [
      for (var index = 0; index < spending.length; index++)
        spending[index].copyWith(
          color: _chartColorFor(
            categoryId: spending[index].categoryId,
            index: index,
            preferredColor: spending[index].color,
            usedColors: usedColors,
          ),
        ),
    ];
  }

  String _categoryNameFromInvoice(
    CreditCardInvoicePreview invoice,
    int categoryId,
  ) {
    for (final transaction in invoice.transactions) {
      if (transaction.categoryId == categoryId) {
        return transaction.categoryName;
      }
    }
    return 'Categoria';
  }

  Color _chartColorFor({
    required int categoryId,
    required int index,
    required Color? preferredColor,
    required Set<int> usedColors,
  }) {
    if (preferredColor != null && usedColors.add(preferredColor.toARGB32())) {
      return preferredColor;
    }

    const colors = [
      AppColors.primary,
      Color(0xFF2F80ED),
      Color(0xFFF59E0B),
      Color(0xFF7C3AED),
      Color(0xFFEC4899),
      Color(0xFF19A974),
      Color(0xFFE11D48),
      Color(0xFF0891B2),
      Color(0xFF84CC16),
      Color(0xFFEA580C),
    ];
    for (var offset = 0; offset < colors.length; offset++) {
      final color = colors[(index + offset + categoryId.abs()) % colors.length];
      if (usedColors.add(color.toARGB32())) {
        return color;
      }
    }

    return colors[index % colors.length];
  }

  CreditCardPreview? _findCard(CardsState state) {
    for (final card in state.cards) {
      if (card.id == widget.cardId) {
        return card;
      }
    }
    return null;
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Future<void> _confirmPayInvoice(
    BuildContext context,
    CardsViewModel viewModel,
    CreditCardInvoicePreview invoice,
  ) async {
    final shouldPay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pagar fatura?'),
          content: Text(
            'Serão debitados ${CurrencyUtils.formatCents(invoice.amountCents)} da conta ${invoice.paymentAccountName ?? 'padrão do cartão'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pagar'),
            ),
          ],
        );
      },
    );

    if (shouldPay != true) {
      return;
    }

    await viewModel.payInvoice(invoice);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura paga.')),
      );
    }
  }

  Future<void> _openEditPurchaseSheet(
    BuildContext context,
    CardsViewModel viewModel,
    CreditCardInvoicePreview invoice,
    CreditCardInvoiceTransactionPreview transaction,
    List<CategoryModel> categories,
    List<SubcategoryModel> subcategories,
  ) async {
    if (invoice.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura paga não pode ser alterada.')),
      );
      return;
    }
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Crie uma categoria de despesa primeiro.')),
      );
      return;
    }

    final edit = await showModalBottomSheet<_PurchaseEditData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _PurchaseEditSheet(
          transaction: transaction,
          categories: categories,
          subcategories: subcategories,
        );
      },
    );

    if (edit == null) {
      return;
    }

    await viewModel.updateInvoiceTransaction(
      invoice: invoice,
      transaction: transaction,
      description: edit.description,
      amountCents: edit.amountCents,
      categoryId: edit.categoryId,
      subcategoryId: edit.subcategoryId,
      date: edit.date,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compra atualizada.')),
      );
    }
  }

  Future<void> _confirmDeletePurchase(
    BuildContext context,
    CardsViewModel viewModel,
    CreditCardInvoicePreview invoice,
    CreditCardInvoiceTransactionPreview transaction,
  ) async {
    if (invoice.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura paga não pode ser alterada.')),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover compra?'),
          content: const Text(
            'O total da fatura será recalculado automaticamente.',
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

    if (shouldDelete != true) {
      return;
    }

    await viewModel.deleteInvoiceTransaction(
      invoice: invoice,
      transaction: transaction,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compra removida.')),
      );
    }
  }
}

class _CategorySpending {
  const _CategorySpending({
    required this.categoryId,
    required this.name,
    required this.amountCents,
    required this.transactionCount,
    this.color,
  });

  final int categoryId;
  final String name;
  final int amountCents;
  final int transactionCount;
  final Color? color;

  _CategorySpending copyWith({
    Color? color,
  }) {
    return _CategorySpending(
      categoryId: categoryId,
      name: name,
      amountCents: amountCents,
      transactionCount: transactionCount,
      color: color ?? this.color,
    );
  }
}

class _CategorySpendingChart extends StatelessWidget {
  const _CategorySpendingChart({
    required this.spending,
  });

  final List<_CategorySpending> spending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chartTotal = spending.fold<int>(
      0,
      (total, item) => total + item.amountCents,
    );
    final transactionCount = spending.fold<int>(
      0,
      (total, item) => total + item.transactionCount,
    );

    if (spending.isEmpty || chartTotal <= 0) {
      return const _EmptyCategoryChart();
    }

    return Column(
      children: [
        SizedBox(
          height: 178,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(164),
                painter: _CategoryDonutPainter(
                  spending: spending,
                  totalCents: chartTotal,
                  baseColor: colors.border,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$transactionCount compras',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    CurrencyUtils.formatCents(chartTotal),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            for (final item in spending)
              _CategorySpendingRow(
                item: item,
                totalCents: chartTotal,
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyCategoryChart extends StatelessWidget {
  const _EmptyCategoryChart();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            color: colors.textSecondary,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            'As categorias aparecerão quando houver compras nesta fatura.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CategorySpendingRow extends StatelessWidget {
  const _CategorySpendingRow({
    required this.item,
    required this.totalCents,
  });

  final _CategorySpending item;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = totalCents == 0 ? 0 : item.amountCents / totalCents;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  item.transactionCount == 1
                      ? '1 compra'
                      : '${item.transactionCount} compras',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            CurrencyUtils.formatCents(item.amountCents),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '${(percent * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDonutPainter extends CustomPainter {
  const _CategoryDonutPainter({
    required this.spending,
    required this.totalCents,
    required this.baseColor,
  });

  final List<_CategorySpending> spending;
  final int totalCents;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.14;
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(
          size.width - strokeWidth,
          size.height - strokeWidth,
        );
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = baseColor;
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    var startAngle = -math.pi / 2;
    final gapAngle = spending.length > 1 ? 0.018 : 0.0;
    for (final item in spending) {
      final sweepAngle = (item.amountCents / totalCents) * math.pi * 2;
      if (sweepAngle <= 0) {
        continue;
      }
      segmentPaint.color = item.color ?? AppColors.primary;
      canvas.drawArc(
        rect,
        startAngle + gapAngle / 2,
        math.max(0, sweepAngle - gapAngle),
        false,
        segmentPaint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.spending != spending ||
        oldDelegate.totalCents != totalCents ||
        oldDelegate.baseColor != baseColor;
  }
}

class _InvoiceHero extends StatelessWidget {
  const _InvoiceHero({
    required this.invoice,
    required this.onPrevious,
    required this.onNext,
    required this.onPay,
  });

  final CreditCardInvoicePreview invoice;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onPrevious,
                tooltip: 'Fatura anterior',
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      AppDateUtils.monthYearLabel(
                        DateTime(invoice.year, invoice.month),
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _InvoiceStatusBadge(invoice: invoice),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onNext,
                tooltip: 'Próxima fatura',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '${invoice.cardName} •••• ${invoice.cardLastDigits}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.formatCents(invoice.amountCents),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                icon: Icons.event_rounded,
                label: 'Vence ${_formatDate(invoice.dueDate)}',
              ),
              _HeroPill(
                icon: Icons.account_balance_wallet_rounded,
                label: invoice.paymentAccountName ?? 'Conta padrão',
              ),
            ],
          ),
          if (onPay != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPay,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Marcar fatura como paga'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceStatusBadge extends StatelessWidget {
  const _InvoiceStatusBadge({required this.invoice});

  final CreditCardInvoicePreview invoice;

  @override
  Widget build(BuildContext context) {
    final color = invoice.isPaid
        ? AppColors.success
        : invoice.status == 'closed'
            ? AppColors.warning
            : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: invoice.isPaid || invoice.status == 'closed'
            ? color.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          invoice.statusLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _LockedInvoiceNotice extends StatelessWidget {
  const _LockedInvoiceNotice();

  @override
  Widget build(BuildContext context) {
    return const _InvoiceNotice(
      icon: Icons.lock_rounded,
      title: 'Fatura paga',
      message: 'Compras desta fatura não podem ser editadas ou removidas.',
    );
  }
}

class _ClosedInvoiceNotice extends StatelessWidget {
  const _ClosedInvoiceNotice();

  @override
  Widget build(BuildContext context) {
    return const _InvoiceNotice(
      icon: Icons.event_busy_rounded,
      title: 'Fatura fechada',
      message: 'A fatura ainda pode ser ajustada enquanto não for paga.',
    );
  }
}

class _InvoiceNotice extends StatelessWidget {
  const _InvoiceNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentAccountInfo extends StatelessWidget {
  const _PaymentAccountInfo({required this.invoice});

  final CreditCardInvoicePreview invoice;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colors.accentSoft,
          foregroundColor: colors.primary,
          child: const Icon(Icons.account_balance_wallet_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.paymentAccountName ?? 'Conta padrão do cartão',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'O pagamento da fatura será debitado desta conta.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyInvoicePurchases extends StatelessWidget {
  const _EmptyInvoicePurchases();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: colors.textSecondary,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhuma compra nesta fatura.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _InvoicePurchaseTile extends StatelessWidget {
  const _InvoicePurchaseTile({
    required this.transaction,
    required this.isLocked,
    required this.onEdit,
    required this.onDelete,
  });

  final CreditCardInvoiceTransactionPreview transaction;
  final bool isLocked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final installment = transaction.installmentNumber == null ||
            transaction.totalInstallments == null
        ? ''
        : ' • ${transaction.installmentNumber}/${transaction.totalInstallments}';
    final category = transaction.subcategoryName == null
        ? transaction.categoryName
        : '${transaction.categoryName} • ${transaction.subcategoryName}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.accentSoft,
            foregroundColor: colors.primary,
            child: const Icon(Icons.shopping_bag_outlined, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: isLocked ? null : onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$category$installment • ${_formatDate(transaction.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyUtils.formatCents(transaction.amountCents),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (!isLocked)
            PopupMenuButton<_PurchaseAction>(
              onSelected: (action) {
                switch (action) {
                  case _PurchaseAction.edit:
                    onEdit();
                  case _PurchaseAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: _PurchaseAction.edit,
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: _PurchaseAction.delete,
                    child: Text('Remover'),
                  ),
                ];
              },
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.lock_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

enum _PurchaseAction { edit, delete }

class _PurchaseEditData {
  const _PurchaseEditData({
    required this.description,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    this.subcategoryId,
  });

  final String description;
  final int amountCents;
  final int categoryId;
  final int? subcategoryId;
  final DateTime date;
}

class _PurchaseEditSheet extends StatefulWidget {
  const _PurchaseEditSheet({
    required this.transaction,
    required this.categories,
    required this.subcategories,
  });

  final CreditCardInvoiceTransactionPreview transaction;
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;

  @override
  State<_PurchaseEditSheet> createState() => _PurchaseEditSheetState();
}

class _PurchaseEditSheetState extends State<_PurchaseEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late int _selectedCategoryId;
  int? _selectedSubcategoryId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.transaction.description,
    );
    _amountController = TextEditingController(
      text: CurrencyUtils.formatCents(widget.transaction.amountCents),
    );
    _selectedCategoryId = widget.categories
            .any((category) => category.id == widget.transaction.categoryId)
        ? widget.transaction.categoryId
        : widget.categories.first.id;
    _selectedSubcategoryId = widget.subcategoriesFor(_selectedCategoryId).any(
            (subcategory) => subcategory.id == widget.transaction.subcategoryId)
        ? widget.transaction.subcategoryId
        : null;
    _date = widget.transaction.date;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subcategories = widget.subcategoriesFor(_selectedCategoryId);

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar compra',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da compra.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: (value) {
                  if (value == null || CurrencyUtils.parseToCents(value) <= 0) {
                    return 'Informe um valor válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedCategoryId = value;
                    _selectedSubcategoryId = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: _selectedSubcategoryId,
                decoration: const InputDecoration(
                  labelText: 'Subcategoria',
                  prefixIcon: Icon(Icons.label_rounded),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sem subcategoria'),
                  ),
                  for (final subcategory in subcategories)
                    DropdownMenuItem<int?>(
                      value: subcategory.id,
                      child: Text(subcategory.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _selectedSubcategoryId = value);
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data da compra',
                    prefixIcon: Icon(Icons.today_rounded),
                  ),
                  child: Text(_formatDate(_date)),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Salvar alterações'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _PurchaseEditData(
        description: _descriptionController.text.trim(),
        amountCents: CurrencyUtils.parseToCents(_amountController.text),
        categoryId: _selectedCategoryId,
        subcategoryId: _selectedSubcategoryId,
        date: _date,
      ),
    );
  }
}

extension on _PurchaseEditSheet {
  List<SubcategoryModel> subcategoriesFor(int categoryId) {
    return subcategories
        .where((subcategory) => subcategory.categoryId == categoryId)
        .toList();
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
