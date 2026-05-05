import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/credit_card_invoice_preview.dart';
import '../../data/models/credit_card_preview.dart';
import '../../shared/widgets/section_card.dart';
import 'cards_view_model.dart';
import 'credit_card_invoice_page.dart';

class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardsViewModelProvider);
    final visibleInvoices = [
      for (final card in state.cards)
        state.invoiceForCardMonth(
          card,
          month: _visibleMonth.month,
          year: _visibleMonth.year,
        ),
    ];
    final invoicesByCardId = {
      for (final invoice in visibleInvoices) invoice.cardId: invoice,
    };
    final expenseCategoriesById = {
      for (final category in state.expenseCategories) category.id: category,
    };
    final categoriesById = {
      for (final category in state.categories) category.id: category,
    };
    final visiblePurchases = [
      for (final invoice in visibleInvoices)
        for (final transaction in invoice.transactions)
          _CardsInvoicePurchase(invoice: invoice, transaction: transaction),
    ]..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    final totalInvoicesCents = visibleInvoices.fold<int>(
      0,
      (total, invoice) => total + invoice.displayAmountCents,
    );
    final availableLimitCents = state.cards.fold<int>(
      0,
      (total, card) {
        final invoiceAmount =
            invoicesByCardId[card.id]?.displayAmountCents ?? 0;
        return total +
            (card.displayLimitCents - invoiceAmount).clamp(0, 1 << 31).toInt();
      },
    );
    final unpaidInvoicesCount = visibleInvoices
        .where((invoice) => !invoice.isPaid && invoice.amountCents > 0)
        .length;
    final categorySpending = _buildCategorySpending(
      visiblePurchases.map((purchase) => purchase.transaction),
      expenseCategoriesById,
    );

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
            _CardsHeader(
              onAdd: () => _openCardForm(context, ref),
            ),
            const SizedBox(height: 14),
            _CardsMonthPager(
              month: _visibleMonth,
              onPrevious: () => _moveMonth(-1),
              onNext: () => _moveMonth(1),
            ),
            if (state.isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 20),
            if (state.cards.isEmpty)
              _EmptyCards(
                hasAccounts: state.accounts.isNotEmpty,
                onAdd: () => _openCardForm(context, ref),
              )
            else
              _HeroCreditCardsList(
                cards: state.cards,
                invoicesByCardId: invoicesByCardId,
                onTapCard: (card) => _openCardInvoice(
                  context,
                  invoicesByCardId[card.id] ?? state.invoiceForCard(card),
                ),
                onEditCard: (card) => _openCardForm(
                  context,
                  ref,
                  card: card,
                ),
                onPayCard: (card) => _confirmPayInvoice(
                  context,
                  ref,
                  card,
                  invoice: invoicesByCardId[card.id],
                ),
                onDeleteCard: (card) => _confirmDeleteCard(context, ref, card),
              ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CardsMetric(
                  title: 'Total em faturas',
                  value: CurrencyUtils.formatCents(
                    totalInvoicesCents,
                    currencyCode: state.currencyCode,
                  ),
                  icon: Icons.receipt_long_rounded,
                ),
                _CardsMetric(
                  title: 'Limite disponível',
                  value: CurrencyUtils.formatCents(
                    availableLimitCents,
                    currencyCode: state.currencyCode,
                  ),
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _CardsMetric(
                  title: 'Próximos vencimentos',
                  value: '$unpaidInvoicesCount faturas',
                  icon: Icons.calendar_month_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Gastos por categoria',
              child: _CardsCategorySpendingChart(
                spending: categorySpending,
                currencyCode: state.currencyCode,
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Registros da fatura',
              trailing: Text(
                '${visiblePurchases.length} itens',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              child: visiblePurchases.isEmpty
                  ? const _EmptyCardsPurchases()
                  : Column(
                      children: [
                        for (final purchase in visiblePurchases)
                          _CardsInvoicePurchaseTile(
                            purchase: purchase,
                            category:
                                categoriesById[purchase.transaction.categoryId],
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  List<_CardsCategorySpending> _buildCategorySpending(
    Iterable<CreditCardInvoiceTransactionPreview> transactions,
    Map<int, CategoryModel> categoriesById,
  ) {
    final totalsByCategory = <int, int>{};
    final countsByCategory = <int, int>{};

    for (final transaction in transactions) {
      if (!transaction.isExpense) {
        continue;
      }
      totalsByCategory.update(
        transaction.categoryId,
        (total) => total + transaction.displayAmountCents,
        ifAbsent: () => transaction.displayAmountCents,
      );
      countsByCategory.update(
        transaction.categoryId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final spending = [
      for (final entry in totalsByCategory.entries)
        _CardsCategorySpending(
          categoryId: entry.key,
          name: categoriesById[entry.key]?.name ?? 'Categoria',
          amountCents: entry.value,
          transactionCount: countsByCategory[entry.key] ?? 0,
          icon: categoriesById[entry.key]?.icon ?? Icons.category_rounded,
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

  Future<void> _openCardInvoice(
    BuildContext context,
    CreditCardInvoicePreview invoice,
  ) async {
    await _openInvoicePage(
      context,
      cardId: invoice.cardId,
      month: invoice.month,
      year: invoice.year,
    );
  }

  Future<void> _openInvoicePage(
    BuildContext context, {
    required int cardId,
    required int month,
    required int year,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CreditCardInvoicePage(
          cardId: cardId,
          initialMonth: month,
          initialYear: year,
        ),
      ),
    );
  }

  Future<void> _openCardForm(
    BuildContext context,
    WidgetRef ref, {
    CreditCardPreview? card,
  }) async {
    final state = ref.read(cardsViewModelProvider);
    final viewModel = ref.read(cardsViewModelProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (state.accounts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cadastre uma conta bancária antes de criar cartões.'),
        ),
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _CreditCardFormSheet(
          card: card,
          accounts: state.accounts,
          onSubmit: ({
            required String name,
            required String lastDigits,
            required String brand,
            required int limitCents,
            required int currentInvoiceCents,
            required int defaultPaymentAccountId,
            required int closingDay,
            required int dueDay,
            required bool isPrimary,
            required String color,
            String? bankName,
          }) async {
            if (card == null) {
              await viewModel.createCard(
                name: name,
                bankName: bankName,
                lastDigits: lastDigits,
                brand: brand,
                limitCents: limitCents,
                currentInvoiceCents: currentInvoiceCents,
                defaultPaymentAccountId: defaultPaymentAccountId,
                closingDay: closingDay,
                dueDay: dueDay,
                isPrimary: isPrimary,
                color: color,
              );
            } else {
              await viewModel.updateCard(
                card: card,
                name: name,
                bankName: bankName,
                lastDigits: lastDigits,
                brand: brand,
                limitCents: limitCents,
                currentInvoiceCents: currentInvoiceCents,
                defaultPaymentAccountId: defaultPaymentAccountId,
                closingDay: closingDay,
                dueDay: dueDay,
                isPrimary: isPrimary,
                color: color,
              );
            }
          },
          onDelete: card == null ? null : () => viewModel.deleteCard(card),
        );
      },
    );

    if (saved == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(card == null ? 'Cartão criado.' : 'Cartão atualizado.'),
        ),
      );
    }
  }

  Future<void> _confirmPayInvoice(
    BuildContext context,
    WidgetRef ref,
    CreditCardPreview card, {
    CreditCardInvoicePreview? invoice,
  }) async {
    final targetInvoice =
        invoice ?? ref.read(cardsViewModelProvider).invoiceForCard(card);
    if (targetInvoice.amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cartão não tem fatura em aberto.')),
      );
      return;
    }

    final now = DateTime.now();
    final isCurrentMonth =
        targetInvoice.month == now.month && targetInvoice.year == now.year;
    if (!isCurrentMonth && targetInvoice.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta fatura ainda não pode ser marcada como paga.'),
        ),
      );
      return;
    }

    final shouldPay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pagar fatura?'),
          content: Text(
            'Vamos descontar ${CurrencyUtils.formatCents(targetInvoice.amountCents, currencyCode: targetInvoice.currencyCode)} da conta ${targetInvoice.paymentAccountName ?? card.defaultPaymentAccountName ?? 'padrão'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Marcar como paga'),
            ),
          ],
        );
      },
    );

    if (shouldPay != true) {
      return;
    }

    if (targetInvoice.id > 0) {
      await ref.read(cardsViewModelProvider.notifier).payInvoice(targetInvoice);
    } else {
      await ref.read(cardsViewModelProvider.notifier).payCurrentInvoice(card);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura paga.')),
      );
    }
  }

  Future<void> _confirmDeleteCard(
    BuildContext context,
    WidgetRef ref,
    CreditCardPreview card,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover cartão?'),
          content: Text('O cartão ${card.name} será removido localmente.'),
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

    await ref.read(cardsViewModelProvider.notifier).deleteCard(card);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cartão removido.')),
      );
    }
  }
}

class _CardsHeader extends StatelessWidget {
  const _CardsHeader({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cartões',
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _CardsMonthPager extends StatelessWidget {
  const _CardsMonthPager({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
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
            onPressed: onPrevious,
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

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({
    required this.hasAccounts,
    required this.onAdd,
  });

  final bool hasAccounts;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SectionCard(
      title: 'Cartões',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(
              Icons.credit_card_off_rounded,
              color: colors.textSecondary,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              hasAccounts
                  ? 'Nenhum cartão cadastrado ainda.'
                  : 'Crie uma conta bancária antes do primeiro cartão.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: hasAccounts ? onAdd : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar cartão'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCreditCardsList extends StatelessWidget {
  const _HeroCreditCardsList({
    required this.cards,
    required this.invoicesByCardId,
    required this.onTapCard,
    required this.onEditCard,
    required this.onPayCard,
    required this.onDeleteCard,
  });

  final List<CreditCardPreview> cards;
  final Map<int, CreditCardInvoicePreview> invoicesByCardId;
  final void Function(CreditCardPreview card) onTapCard;
  final void Function(CreditCardPreview card) onEditCard;
  final void Function(CreditCardPreview card) onPayCard;
  final void Function(CreditCardPreview card) onDeleteCard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final isTablet = viewportWidth >= 680;
        final cardWidth = isTablet
            ? ((viewportWidth - 14) / 2).clamp(300.0, viewportWidth)
            : viewportWidth;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth.toDouble(),
                child: _PhysicalCreditCard(
                  card: card,
                  invoiceCents: invoicesByCardId[card.id]?.amountCents,
                  onTap: () => onTapCard(card),
                  isHero: true,
                  menu: _CardActionsMenu(
                    onEdit: () => onEditCard(card),
                    onPay: () => onPayCard(card),
                    onDelete: () => onDeleteCard(card),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhysicalCreditCard extends StatefulWidget {
  const _PhysicalCreditCard({
    required this.card,
    required this.onTap,
    this.invoiceCents,
    this.menu,
    this.isHero = false,
  });

  final CreditCardPreview card;
  final VoidCallback onTap;
  final int? invoiceCents;
  final Widget? menu;
  final bool isHero;

  @override
  State<_PhysicalCreditCard> createState() => _PhysicalCreditCardState();
}

class _PhysicalCreditCardState extends State<_PhysicalCreditCard> {
  static const _aspectRatio = 315 / 184;

  Offset _tilt = Offset.zero;
  bool _isHolding = false;

  CreditCardPreview get card => widget.card;
  bool get isHero => widget.isHero;
  int get _invoiceCents => widget.invoiceCents ?? card.invoiceCents;

  int get _availableLimitCents {
    return (card.limitCents - _invoiceCents).clamp(0, 1 << 31).toInt();
  }

  void _updateTilt(Offset position, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final normalizedDx = ((position.dx / size.width) - 0.5) * 2;
    final normalizedDy = ((position.dy / size.height) - 0.5) * 2;

    setState(() {
      _isHolding = true;
      _tilt = Offset(
        normalizedDx.clamp(-1.0, 1.0).toDouble(),
        normalizedDy.clamp(-1.0, 1.0).toDouble(),
      );
    });
  }

  void _resetTilt() {
    if (!_isHolding && _tilt == Offset.zero) {
      return;
    }

    setState(() {
      _isHolding = false;
      _tilt = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = card.color;
    final gradientStart = _shiftColor(baseColor, lightnessDelta: 0.12);
    final gradientEnd = _shiftColor(baseColor, lightnessDelta: -0.18);

    final cardBody = AspectRatio(
      aspectRatio: _aspectRatio,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(isHero ? 28 : 24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isHero ? 28 : 24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradientStart, gradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.28),
                  blurRadius: isHero ? 26 : 18,
                  offset: Offset(0, isHero ? 14 : 9),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isHero ? 28 : 24),
              child: Stack(
                children: [
                  Positioned(
                    left: -78,
                    bottom: -92,
                    child: _CardGlow(
                      size: isHero ? 245 : 210,
                      opacity: 0.11,
                    ),
                  ),
                  Positioned(
                    right: -92,
                    top: -96,
                    child: _CardGlow(
                      size: isHero ? 230 : 198,
                      opacity: 0.10,
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final padding = isHero ? 22.0 : 18.0;
                      final amountTop = constraints.maxHeight * 0.46;
                      final footerBottom = isHero ? 20.0 : 16.0;

                      return Stack(
                        children: [
                          Positioned(
                            left: padding,
                            right: padding,
                            top: padding,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        card.bankName?.isNotEmpty == true
                                            ? card.bankName!
                                            : card.name,
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              card.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontSize: isHero ? 23 : 19,
                                                  ),
                                            ),
                                          ),
                                          if (card.isPrimary) ...[
                                            const SizedBox(width: 8),
                                            const _CardPrimaryDot(),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${card.brandLabel} • Fecha ${card.closingDay} • Vence ${card.dueDay}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _CardBrandMark(
                                  brand: card.brand,
                                  label: card.brandLabel,
                                ),
                                if (widget.menu != null) ...[
                                  const SizedBox(width: 2),
                                  widget.menu!,
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            left: padding,
                            right: padding,
                            top: amountTop,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Fatura atual',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyUtils.formatCents(
                                          _invoiceCents,
                                          currencyCode: card.currencyCode,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontSize: isHero ? 29 : 23,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: padding,
                            right: padding,
                            bottom: footerBottom,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _CardFooterDatum(
                                    label: 'Disponível',
                                    value: CurrencyUtils.formatCents(
                                      _availableLimitCents,
                                      currencyCode: card.currencyCode,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _CardFooterDatum(
                                  label: 'Limite total',
                                  value: CurrencyUtils.formatCents(
                                    card.limitCents,
                                    currencyCode: card.currencyCode,
                                  ),
                                  alignEnd: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth / _aspectRatio;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (details) {
            _updateTilt(details.localPosition, Size(cardWidth, cardHeight));
          },
          onLongPressMoveUpdate: (details) {
            _updateTilt(details.localPosition, Size(cardWidth, cardHeight));
          },
          onLongPressEnd: (_) => _resetTilt(),
          onLongPressCancel: _resetTilt,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(end: _tilt),
            duration: Duration(milliseconds: _isHolding ? 70 : 240),
            curve: Curves.easeOutCubic,
            builder: (context, tilt, child) {
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-tilt.dy * 0.12)
                ..rotateY(tilt.dx * 0.16);

              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: Transform.scale(
                  scale: _isHolding ? 1.012 : 1,
                  child: child,
                ),
              );
            },
            child: cardBody,
          ),
        );
      },
    );
  }
}

class _CardGlow extends StatelessWidget {
  const _CardGlow({
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

class _CardBrandMark extends StatelessWidget {
  const _CardBrandMark({
    required this.brand,
    required this.label,
  });

  final String brand;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (brand == 'mastercard') {
      return const SizedBox(
        width: 48,
        height: 32,
        child: Stack(
          children: [
            Positioned(
              left: 4,
              top: 4,
              child: _BrandCircle(color: Color(0xFFEB001B)),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: _BrandCircle(color: Color(0xFFF79E1B)),
            ),
          ],
        ),
      );
    }

    final display = switch (brand) {
      'visa' => 'VISA',
      'elo' => 'elo',
      'amex' => 'AMEX',
      'hipercard' => 'HIPER',
      _ => label,
    };

    return Text(
      display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
    );
  }
}

class _BrandCircle extends StatelessWidget {
  const _BrandCircle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CardFooterDatum extends StatelessWidget {
  const _CardFooterDatum({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _CardPrimaryDot extends StatelessWidget {
  const _CardPrimaryDot();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cartão principal',
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFF8EE6A4),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

Color _shiftColor(Color color, {required double lightnessDelta}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness(
        (hsl.lightness + lightnessDelta).clamp(0.18, 0.72).toDouble(),
      )
      .toColor();
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
    final colors = context.colors;

    return Container(
      width: 162,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.32 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.accentSoft,
            foregroundColor: colors.primary,
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

class _CardsInvoicePurchase {
  const _CardsInvoicePurchase({
    required this.invoice,
    required this.transaction,
  });

  final CreditCardInvoicePreview invoice;
  final CreditCardInvoiceTransactionPreview transaction;
}

class _CardsCategorySpending {
  const _CardsCategorySpending({
    required this.categoryId,
    required this.name,
    required this.amountCents,
    required this.transactionCount,
    required this.icon,
    this.color,
  });

  final int categoryId;
  final String name;
  final int amountCents;
  final int transactionCount;
  final IconData icon;
  final Color? color;

  _CardsCategorySpending copyWith({Color? color}) {
    return _CardsCategorySpending(
      categoryId: categoryId,
      name: name,
      amountCents: amountCents,
      transactionCount: transactionCount,
      icon: icon,
      color: color ?? this.color,
    );
  }
}

class _CardsCategorySpendingChart extends StatelessWidget {
  const _CardsCategorySpendingChart({
    required this.spending,
    required this.currencyCode,
  });

  final List<_CardsCategorySpending> spending;
  final String currencyCode;

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
      return const _EmptyCardsCategoryChart();
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
                painter: _CardsCategoryDonutPainter(
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
                    CurrencyUtils.formatCents(
                      chartTotal,
                      currencyCode: currencyCode,
                    ),
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
              _CardsCategorySpendingRow(
                item: item,
                totalCents: chartTotal,
                currencyCode: currencyCode,
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyCardsCategoryChart extends StatelessWidget {
  const _EmptyCardsCategoryChart();

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
            'As categorias aparecerão quando houver compras neste mês.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CardsCategorySpendingRow extends StatelessWidget {
  const _CardsCategorySpendingRow({
    required this.item,
    required this.totalCents,
    required this.currencyCode,
  });

  final _CardsCategorySpending item;
  final int totalCents;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = totalCents == 0 ? 0 : item.amountCents / totalCents;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _CardsCategoryIconBadge(
            icon: item.icon,
            color: item.color ?? AppColors.primary,
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
            CurrencyUtils.formatCents(
              item.amountCents,
              currencyCode: currencyCode,
            ),
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

class _CardsCategoryIconBadge extends StatelessWidget {
  const _CardsCategoryIconBadge({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}

class _CardsCategoryDonutPainter extends CustomPainter {
  const _CardsCategoryDonutPainter({
    required this.spending,
    required this.totalCents,
    required this.baseColor,
  });

  final List<_CardsCategorySpending> spending;
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
  bool shouldRepaint(covariant _CardsCategoryDonutPainter oldDelegate) {
    return oldDelegate.spending != spending ||
        oldDelegate.totalCents != totalCents ||
        oldDelegate.baseColor != baseColor;
  }
}

class _EmptyCardsPurchases extends StatelessWidget {
  const _EmptyCardsPurchases();

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
            'Nenhum registro em cartões neste mês.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _CardsInvoicePurchaseTile extends StatelessWidget {
  const _CardsInvoicePurchaseTile({
    required this.purchase,
    required this.category,
  });

  final _CardsInvoicePurchase purchase;
  final CategoryModel? category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final transaction = purchase.transaction;
    final installment = transaction.installmentNumber == null ||
            transaction.totalInstallments == null
        ? ''
        : ' • ${transaction.installmentNumber}/${transaction.totalInstallments}';
    final categoryLabel = transaction.subcategoryName == null
        ? transaction.categoryName
        : '${transaction.categoryName} • ${transaction.subcategoryName}';
    final categoryIcon = category?.icon ?? Icons.category_rounded;
    final categoryColor = category?.color ?? AppColors.primary;
    final displayDetail = transaction.isCredit
        ? '${transaction.entryKindLabel} - $categoryLabel - ${purchase.invoice.cardName}'
        : '$categoryLabel$installment - ${purchase.invoice.cardName}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _CardsCategoryIconBadge(icon: categoryIcon, color: categoryColor),
          const SizedBox(width: 12),
          Expanded(
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
                  displayDetail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TransactionAmountDate(
            amount: transaction.isCredit
                ? '+ ${CurrencyUtils.formatCents(
                    transaction.amountCents,
                    currencyCode: transaction.currencyCode,
                  )}'
                : CurrencyUtils.formatCents(
                    transaction.amountCents,
                    currencyCode: transaction.currencyCode,
                  ),
            date: _formatDate(transaction.date),
            amountColor: transaction.isCredit ? colors.success : null,
          ),
        ],
      ),
    );
  }
}

class _TransactionAmountDate extends StatelessWidget {
  const _TransactionAmountDate({
    required this.amount,
    required this.date,
    this.amountColor,
  });

  final String amount;
  final String date;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CardActionsMenu extends StatelessWidget {
  const _CardActionsMenu({
    required this.onEdit,
    required this.onPay,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CardAction>(
      tooltip: 'Ações do cartão',
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: (action) {
        switch (action) {
          case _CardAction.edit:
            onEdit();
          case _CardAction.pay:
            onPay();
          case _CardAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _CardAction.edit,
            child: Text('Editar'),
          ),
          PopupMenuItem(
            value: _CardAction.pay,
            child: Text('Pagar fatura'),
          ),
          PopupMenuItem(
            value: _CardAction.delete,
            child: Text('Remover'),
          ),
        ];
      },
    );
  }
}

enum _CardAction { edit, pay, delete }

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CreditCardFormSheet extends StatefulWidget {
  const _CreditCardFormSheet({
    required this.accounts,
    required this.onSubmit,
    this.card,
    this.onDelete,
  });

  final List<AccountPreview> accounts;
  final CreditCardPreview? card;
  final Future<void> Function({
    required String name,
    required String lastDigits,
    required String brand,
    required int limitCents,
    required int currentInvoiceCents,
    required int defaultPaymentAccountId,
    required int closingDay,
    required int dueDay,
    required bool isPrimary,
    required String color,
    String? bankName,
  }) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<_CreditCardFormSheet> createState() => _CreditCardFormSheetState();
}

class _CreditCardFormSheetState extends State<_CreditCardFormSheet> {
  static const _brands = [
    _BrandOption('visa', 'Visa'),
    _BrandOption('mastercard', 'Mastercard'),
    _BrandOption('elo', 'Elo'),
    _BrandOption('amex', 'American Express'),
    _BrandOption('hipercard', 'Hipercard'),
    _BrandOption('other', 'Outra'),
  ];

  static const _colors = [
    '#006B4F',
    '#2F80ED',
    '#7C3AED',
    '#F59E0B',
    '#D93025',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _lastDigitsController;
  late final TextEditingController _limitController;
  late final TextEditingController _invoiceController;
  late String _selectedBrand;
  late String _selectedColor;
  late int _defaultPaymentAccountId;
  late int _closingDay;
  late int _dueDay;
  late bool _isPrimary;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _nameController = TextEditingController(text: card?.name ?? '');
    _bankNameController = TextEditingController(text: card?.bankName ?? '');
    _lastDigitsController = TextEditingController(
      text: card?.lastDigits == '0000' ? '' : card?.lastDigits ?? '',
    );
    _limitController = TextEditingController(
      text: card == null
          ? ''
          : CurrencyUtils.formatCents(
              card.limitCents,
              currencyCode: card.currencyCode,
            ),
    );
    _invoiceController = TextEditingController(
      text: card == null
          ? ''
          : CurrencyUtils.formatCents(
              card.invoiceCents,
              currencyCode: card.currencyCode,
            ),
    );
    _selectedBrand = _brands.any((brand) => brand.value == card?.brand)
        ? card!.brand
        : _brands.first.value;
    _selectedColor = card?.colorHex ?? _colors.first;
    _defaultPaymentAccountId = _initialAccountId(card);
    _closingDay = card?.closingDay ?? 5;
    _dueDay = card?.dueDay ?? 15;
    _isPrimary = card?.isPrimary ?? false;
  }

  int _initialAccountId(CreditCardPreview? card) {
    final cardAccountId = card?.defaultPaymentAccountId;
    if (cardAccountId != null &&
        widget.accounts.any((account) => account.id == cardAccountId)) {
      return cardAccountId;
    }
    return widget.accounts.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _lastDigitsController.dispose();
    _limitController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

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
                card == null ? 'Novo cartão' : 'Editar cartão',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do cartão',
                  hintText: 'Ex: Nubank Ultravioleta',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome do cartão.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ex: Nubank, Inter, Itaú',
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedBrand,
                decoration: const InputDecoration(
                  labelText: 'Bandeira',
                  prefixIcon: Icon(Icons.style_rounded),
                ),
                items: [
                  for (final brand in _brands)
                    DropdownMenuItem(
                      value: brand.value,
                      child: Text(brand.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedBrand = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastDigitsController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Final do cartão',
                  hintText: 'Ex: 1234',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
                validator: (value) {
                  final digits = value?.trim() ?? '';
                  if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
                    return 'Informe os 4 últimos dígitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Limite',
                  hintText: 'Ex: 5000,00',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty ||
                      CurrencyUtils.parseToCents(value) <= 0) {
                    return 'Informe um limite válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _invoiceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fatura atual',
                  hintText: 'Ex: 1258,40',
                  prefixIcon: Icon(Icons.receipt_long_rounded),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _defaultPaymentAccountId,
                decoration: const InputDecoration(
                  labelText: 'Conta padrão de pagamento',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _defaultPaymentAccountId = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _closingDay,
                      decoration: const InputDecoration(
                        labelText: 'Fechamento',
                        prefixIcon: Icon(Icons.event_available_rounded),
                      ),
                      items: _dayItems(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _closingDay = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _dueDay,
                      decoration: const InputDecoration(
                        labelText: 'Vencimento',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      items: _dayItems(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _dueDay = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPrimary,
                title: const Text('Cartão principal'),
                subtitle: const Text('Usar este cartão como destaque da Home.'),
                onChanged: (value) => setState(() => _isPrimary = value),
              ),
              const SizedBox(height: 14),
              Text('Cor', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  for (final color in _colors)
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
                  child: Text(_isSubmitting ? 'Salvando...' : 'Salvar cartão'),
                ),
              ),
              if (widget.onDelete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remover cartão'),
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

  List<DropdownMenuItem<int>> _dayItems() {
    return [
      for (var day = 1; day <= 31; day++)
        DropdownMenuItem(value: day, child: Text('$day')),
    ];
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
        lastDigits: _lastDigitsController.text.trim(),
        brand: _selectedBrand,
        limitCents: CurrencyUtils.parseToCents(_limitController.text),
        currentInvoiceCents: _invoiceController.text.trim().isEmpty
            ? 0
            : CurrencyUtils.parseToCents(_invoiceController.text),
        defaultPaymentAccountId: _defaultPaymentAccountId,
        closingDay: _closingDay,
        dueDay: _dueDay,
        isPrimary: _isPrimary,
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
          title: const Text('Remover cartão?'),
          content: const Text('Esta ação remove o cartão localmente.'),
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
}

class _BrandOption {
  const _BrandOption(this.value, this.label);

  final String value;
  final String label;
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
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : null,
      ),
    );
  }
}
