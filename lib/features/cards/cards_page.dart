import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/credit_card_invoice_preview.dart';
import '../../data/models/credit_card_preview.dart';
import '../../shared/widgets/section_card.dart';
import 'cards_view_model.dart';
import 'credit_card_invoice_page.dart';

class CardsPage extends ConsumerWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardsViewModelProvider);
    final primaryCard = state.primaryCard;

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardsHeader(
              monthLabel: AppDateUtils.monthYearLabel(DateTime.now()),
              onAdd: () => _openCardForm(context, ref),
            ),
            if (state.isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 20),
            if (primaryCard == null)
              _EmptyCards(
                hasAccounts: state.accounts.isNotEmpty,
                onAdd: () => _openCardForm(context, ref),
              )
            else
              _HeroCreditCard(
                card: primaryCard,
                onPay: () => _confirmPayInvoice(context, ref, primaryCard),
              ),
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
                  value:
                      '${state.invoices.where((invoice) => !invoice.isPaid).length} faturas',
                  icon: Icons.calendar_month_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Meus cartões',
              trailing: TextButton.icon(
                onPressed: () => _openCardForm(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Adicionar'),
              ),
              child: state.cards.isEmpty
                  ? const _CardsListEmpty()
                  : Column(
                      children: [
                        for (final card in state.cards)
                          _CreditCardTile(
                            card: card,
                            onTap: () => _openCardInvoice(
                              context,
                              state.invoiceForCard(card),
                            ),
                            onEdit: () => _openCardForm(
                              context,
                              ref,
                              card: card,
                            ),
                            onPay: () => _confirmPayInvoice(context, ref, card),
                            onDelete: () =>
                                _confirmDeleteCard(context, ref, card),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: Colors.white,
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
    CreditCardPreview card,
  ) async {
    if (card.invoiceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cartão não tem fatura em aberto.')),
      );
      return;
    }

    final shouldPay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pagar fatura?'),
          content: Text(
            'Vamos descontar ${CurrencyUtils.formatCents(card.invoiceCents)} da conta ${card.defaultPaymentAccountName ?? 'padrão'}.',
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

    await ref.read(cardsViewModelProvider.notifier).payCurrentInvoice(card);
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
    required this.monthLabel,
    required this.onAdd,
  });

  final String monthLabel;
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
              const SizedBox(height: 4),
              Text(monthLabel, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: onAdd,
          tooltip: 'Adicionar cartão',
          icon: const Icon(Icons.add_card_rounded),
        ),
      ],
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
    return SectionCard(
      title: 'Cartões',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(
              Icons.credit_card_off_rounded,
              color: AppColors.textSecondary,
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

class _HeroCreditCard extends StatelessWidget {
  const _HeroCreditCard({
    required this.card,
    required this.onPay,
  });

  final CreditCardPreview card;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, card.color],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          child: Text(
                            _initials(card.name),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${card.brandLabel} • Fecha dia ${card.closingDay}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Fatura atual',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    Text(
                      CurrencyUtils.formatCents(card.invoiceCents),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Vencimento dia ${card.dueDay}',
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pagamento: ${card.defaultPaymentAccountName ?? 'conta padrão'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: card.invoiceCents > 0 ? onPay : null,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Pagar'),
              ),
            ],
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

class _CardsListEmpty extends StatelessWidget {
  const _CardsListEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        'Adicione seu primeiro cartão para acompanhar limite, fatura e vencimento.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  const _CreditCardTile({
    required this.card,
    required this.onTap,
    required this.onEdit,
    required this.onPay,
    required this.onDelete,
  });

  final CreditCardPreview card;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: card.color,
              child: Text(
                _initials(card.name),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${card.name} •••• ${card.lastDigits}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      if (card.isPrimary) const SizedBox(width: 6),
                      if (card.isPrimary)
                        const _PrimaryBadge(label: 'Principal'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${card.brandLabel} • Vence dia ${card.dueDay}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
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
            PopupMenuButton<_CardAction>(
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
                return [
                  const PopupMenuItem(
                    value: _CardAction.edit,
                    child: Text('Editar'),
                  ),
                  const PopupMenuItem(
                    value: _CardAction.pay,
                    child: Text('Pagar fatura'),
                  ),
                  const PopupMenuItem(
                    value: _CardAction.delete,
                    child: Text('Remover'),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardAction { edit, pay, delete }

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
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
      text: card == null ? '' : CurrencyUtils.formatCents(card.limitCents),
    );
    _invoiceController = TextEditingController(
      text: card == null ? '' : CurrencyUtils.formatCents(card.invoiceCents),
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
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
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

String _initials(String name) {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    return '?';
  }
  return trimmedName.characters.take(2).toString().toUpperCase();
}
