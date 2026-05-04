import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/transaction_name_suggestion.dart';
import '../../shared/widgets/name_prompt_dialog.dart';
import 'card_expense_form_view_model.dart';
import 'transaction_suggestion_strip.dart';

class CardExpenseFormSheet extends ConsumerStatefulWidget {
  const CardExpenseFormSheet({super.key});

  @override
  ConsumerState<CardExpenseFormSheet> createState() =>
      _CardExpenseFormSheetState();
}

class _CardExpenseFormSheetState extends ConsumerState<CardExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '2');
  _ExpenseKind _expenseKind = _ExpenseKind.single;
  _InstallmentAmountMode _installmentAmountMode =
      _InstallmentAmountMode.totalPurchase;
  int? _selectedCardId;
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _pendingCategoryId;
  int? _pendingSubcategoryId;
  late DateTime _invoiceMonth;
  late DateTime _purchaseDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    final now = DateTime.now();
    _invoiceMonth = DateTime(now.year, now.month);
    _purchaseDate = now;
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardExpenseFormViewModelProvider);
    _syncSelections(state);

    ref.listen(
      cardExpenseFormViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

    final selectedCard = _selectedCard(state.cards);
    final selectedCategory = _selectedCategory(state.categories);
    final subcategories = selectedCategory == null
        ? <SubcategoryModel>[]
        : state.subcategoriesFor(selectedCategory.id);
    final suggestions = state.suggestionsForName(_nameController.text);

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Despesa no cartão',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.isLoading) const LinearProgressIndicator(minHeight: 3),
              if (state.cards.isEmpty || state.categories.isEmpty) ...[
                const SizedBox(height: 18),
                _MissingRequirement(
                  hasCards: state.cards.isNotEmpty,
                  hasCategories: state.categories.isNotEmpty,
                ),
              ] else ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Ex: Mercado, Netflix, Uber',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da despesa.';
                    }
                    return null;
                  },
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TransactionSuggestionStrip(
                    suggestions: suggestions,
                    onSelected: _applySuggestion,
                    detailBuilder: (suggestion) =>
                        _suggestionDetail(state, suggestion),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _amountLabel,
                    hintText: 'Ex: 129,90',
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                  validator: (value) {
                    if (value == null ||
                        CurrencyUtils.parseToCents(value) <= 0) {
                      return 'Informe um valor válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Tipo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in _ExpenseKind.values)
                      ChoiceChip(
                        selected: _expenseKind == kind,
                        label: Text(kind.label),
                        avatar: Icon(kind.icon, size: 18),
                        onSelected: (_) {
                          setState(() => _expenseKind = kind);
                        },
                      ),
                  ],
                ),
                if (_expenseKind == _ExpenseKind.installment) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _installmentsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Parcelas',
                      hintText: 'Ex: 3',
                      prefixIcon: Icon(Icons.format_list_numbered_rounded),
                    ),
                    validator: (value) {
                      final installments = int.tryParse(value?.trim() ?? '');
                      if (installments == null || installments < 2) {
                        return 'Informe 2 parcelas ou mais.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Valor informado',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in _InstallmentAmountMode.values)
                        ChoiceChip(
                          selected: _installmentAmountMode == mode,
                          label: Text(mode.label),
                          avatar: Icon(mode.icon, size: 18),
                          onSelected: (_) {
                            setState(() => _installmentAmountMode = mode);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _installmentAmountMode.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _selectedCardId,
                  decoration: const InputDecoration(
                    labelText: 'Cartão',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                  items: [
                    for (final card in state.cards)
                      DropdownMenuItem(
                        value: card.id,
                        child: Text('${card.name} •••• ${card.lastDigits}'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCardId = value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<DateTime>(
                  initialValue: _invoiceMonth,
                  decoration: InputDecoration(
                    labelText: _expenseKind == _ExpenseKind.installment
                        ? 'Primeira parcela na fatura'
                        : 'Fatura',
                    prefixIcon: const Icon(Icons.calendar_month_rounded),
                  ),
                  items: [
                    for (final month in _invoiceMonthOptions())
                      DropdownMenuItem(
                        value: month,
                        child: Text(AppDateUtils.monthYearLabel(month)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _invoiceMonth = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: [
                          for (final category in state.categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                            _selectedSubcategoryId = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _createCategory,
                      tooltip: 'Criar categoria',
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SubcategoryField(
                  subcategories: subcategories,
                  selectedSubcategoryId: _selectedSubcategoryId,
                  onChanged: (value) {
                    setState(() => _selectedSubcategoryId = value);
                  },
                  onCreate: selectedCategory == null
                      ? null
                      : () => _createSubcategory(selectedCategory.id),
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Conta de pagamento',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  child: Text(
                    selectedCard?.defaultPaymentAccountName ??
                        'Conta padrão do cartão',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickPurchaseDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data da compra',
                      prefixIcon: Icon(Icons.today_rounded),
                    ),
                    child: Text(_formatDate(_purchaseDate)),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canSubmit(state) ? () => _save(false) : null,
                    child: Text(_isSubmitting ? 'Salvando...' : 'Salvar'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _canSubmit(state) ? () => _save(true) : null,
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Salvar e continuar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit(CardExpenseFormState state) {
    return !_isSubmitting &&
        state.cards.isNotEmpty &&
        state.categories.isNotEmpty;
  }

  void _syncSelections(CardExpenseFormState state) {
    final pendingCategoryId = _pendingCategoryId;
    if (pendingCategoryId != null &&
        state.categories.any((category) => category.id == pendingCategoryId)) {
      _selectedCategoryId = pendingCategoryId;
      _selectedSubcategoryId = null;
      _pendingCategoryId = null;
    }

    if (state.cards.isNotEmpty &&
        !state.cards.any((card) => card.id == _selectedCardId)) {
      CreditCardPreview? primaryCard;
      for (final card in state.cards) {
        if (card.isPrimary) {
          primaryCard = card;
          break;
        }
      }
      _selectedCardId = primaryCard?.id ?? state.cards.first.id;
    }

    if (state.categories.isNotEmpty &&
        !state.categories
            .any((category) => category.id == _selectedCategoryId)) {
      _selectedCategoryId = state.categories.first.id;
      _selectedSubcategoryId = null;
    }

    if (_selectedCategoryId != null) {
      final availableSubcategories =
          state.subcategoriesFor(_selectedCategoryId!);
      final pendingSubcategoryId = _pendingSubcategoryId;
      if (pendingSubcategoryId != null &&
          availableSubcategories
              .any((subcategory) => subcategory.id == pendingSubcategoryId)) {
        _selectedSubcategoryId = pendingSubcategoryId;
        _pendingSubcategoryId = null;
      }
      if (_selectedSubcategoryId != null &&
          !availableSubcategories
              .any((subcategory) => subcategory.id == _selectedSubcategoryId)) {
        _selectedSubcategoryId = null;
      }
    }
  }

  CreditCardPreview? _selectedCard(List<CreditCardPreview> cards) {
    for (final card in cards) {
      if (card.id == _selectedCardId) {
        return card;
      }
    }
    return null;
  }

  CategoryModel? _selectedCategory(List<CategoryModel> categories) {
    for (final category in categories) {
      if (category.id == _selectedCategoryId) {
        return category;
      }
    }
    return null;
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applySuggestion(TransactionNameSuggestion suggestion) {
    final state = ref.read(cardExpenseFormViewModelProvider);
    _nameController.text = suggestion.description;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );

    setState(() {
      final creditCardId = suggestion.creditCardId;
      if (creditCardId != null &&
          state.cards.any((card) => card.id == creditCardId)) {
        _selectedCardId = creditCardId;
      }

      if (state.categories.any(
        (category) => category.id == suggestion.categoryId,
      )) {
        _selectedCategoryId = suggestion.categoryId;
        final subcategoryId = suggestion.subcategoryId;
        _selectedSubcategoryId = subcategoryId != null &&
                state
                    .subcategoriesFor(suggestion.categoryId)
                    .any((subcategory) => subcategory.id == subcategoryId)
            ? subcategoryId
            : null;
      }
    });
  }

  String _suggestionDetail(
    CardExpenseFormState state,
    TransactionNameSuggestion suggestion,
  ) {
    final pieces = <String>[];
    for (final category in state.categories) {
      if (category.id == suggestion.categoryId) {
        pieces.add(category.name);
        break;
      }
    }
    for (final card in state.cards) {
      if (card.id == suggestion.creditCardId) {
        pieces.add(card.name);
        break;
      }
    }
    return pieces.join(' • ');
  }

  List<DateTime> _invoiceMonthOptions() {
    final now = DateTime.now();
    return [
      for (var index = -2; index <= 12; index++)
        DateTime(now.year, now.month + index),
    ];
  }

  Future<void> _pickPurchaseDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (pickedDate != null) {
      setState(() => _purchaseDate = pickedDate);
    }
  }

  Future<void> _createCategory() async {
    final name = await _askForName(
      title: 'Nova categoria',
      label: 'Nome da categoria',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    final id = await ref
        .read(cardExpenseFormViewModelProvider.notifier)
        .createExpenseCategory(name);
    if (mounted) {
      setState(() {
        _pendingCategoryId = id;
        _selectedSubcategoryId = null;
      });
    }
  }

  Future<void> _createSubcategory(int categoryId) async {
    final name = await _askForName(
      title: 'Nova subcategoria',
      label: 'Nome da subcategoria',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    final id = await ref
        .read(cardExpenseFormViewModelProvider.notifier)
        .createSubcategory(
          categoryId: categoryId,
          name: name,
        );
    if (mounted) {
      setState(() => _pendingSubcategoryId = id);
    }
  }

  Future<String?> _askForName({
    required String title,
    required String label,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => NamePromptDialog(
        title: title,
        label: label,
      ),
    );
  }

  Future<void> _save(bool keepOpen) async {
    if (!_formKey.currentState!.validate() ||
        _selectedCardId == null ||
        _selectedCategoryId == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(cardExpenseFormViewModelProvider.notifier).saveCardExpense(
            name: _nameController.text.trim(),
            amountCents: CurrencyUtils.parseToCents(_amountController.text),
            expenseKind: _expenseKind.value,
            cardId: _selectedCardId!,
            invoiceMonth: _invoiceMonth.month,
            invoiceYear: _invoiceMonth.year,
            categoryId: _selectedCategoryId!,
            subcategoryId: _selectedSubcategoryId,
            purchaseDate: _purchaseDate,
            totalInstallments: _expenseKind == _ExpenseKind.installment
                ? int.parse(_installmentsController.text)
                : null,
            installmentAmountIsTotal: _expenseKind ==
                    _ExpenseKind.installment &&
                _installmentAmountMode == _InstallmentAmountMode.totalPurchase,
          );

      if (!mounted) {
        return;
      }

      if (keepOpen) {
        _nameController.clear();
        _amountController.clear();
        setState(() {
          _purchaseDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Despesa salva.')),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String get _amountLabel {
    if (_expenseKind != _ExpenseKind.installment) {
      return 'Valor';
    }

    return _installmentAmountMode == _InstallmentAmountMode.totalPurchase
        ? 'Valor total da compra'
        : 'Valor da parcela';
  }
}

class _SubcategoryField extends StatelessWidget {
  const _SubcategoryField({
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.onChanged,
    required this.onCreate,
  });

  final List<SubcategoryModel> subcategories;
  final int? selectedSubcategoryId;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (subcategories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.accentSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.label_outline_rounded, color: colors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Nenhuma subcategoria para esta categoria.'),
            ),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Criar'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: selectedSubcategoryId,
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
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onCreate,
          tooltip: 'Criar subcategoria',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _MissingRequirement extends StatelessWidget {
  const _MissingRequirement({
    required this.hasCards,
    required this.hasCategories,
  });

  final bool hasCards;
  final bool hasCategories;

  @override
  Widget build(BuildContext context) {
    final message = !hasCards
        ? 'Cadastre um cartão antes de lançar despesas no cartão.'
        : !hasCategories
            ? 'Crie uma categoria de despesa antes de continuar.'
            : 'Ainda faltam dados para lançar a despesa.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 44,
            color: context.colors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

enum _ExpenseKind {
  single('single', 'Única', Icons.looks_one_rounded),
  installment('installment', 'Parcelada', Icons.view_week_rounded),
  fixedMonthly('fixed_monthly', 'Fixa mensal', Icons.event_repeat_rounded);

  const _ExpenseKind(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

enum _InstallmentAmountMode {
  totalPurchase(
    'total_purchase',
    'Total da compra',
    'O valor será dividido automaticamente entre as parcelas.',
    Icons.splitscreen_rounded,
  ),
  installmentValue(
    'installment_value',
    'Valor da parcela',
    'O mesmo valor será lançado em cada parcela.',
    Icons.payments_rounded,
  );

  const _InstallmentAmountMode(
    this.value,
    this.label,
    this.description,
    this.icon,
  );

  final String value;
  final String label;
  final String description;
  final IconData icon;
}
