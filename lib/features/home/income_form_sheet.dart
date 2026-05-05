import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/transaction_name_suggestion.dart';
import '../../shared/widgets/name_prompt_dialog.dart';
import 'income_form_view_model.dart';
import 'transaction_suggestion_strip.dart';

class IncomeFormSheet extends ConsumerStatefulWidget {
  const IncomeFormSheet({super.key});

  @override
  ConsumerState<IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends ConsumerState<IncomeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '2');
  _IncomeKind _incomeKind = _IncomeKind.single;
  int? _selectedAccountId;
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _pendingCategoryId;
  int? _pendingSubcategoryId;
  late DateTime _dueDate;
  late DateTime _date;
  bool _isPaid = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    final now = DateTime.now();
    _dueDate = now;
    _date = now;
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
    final state = ref.watch(incomeFormViewModelProvider);
    _syncSelections(state);

    ref.listen(
      incomeFormViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

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
                      'Receita',
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
              if (state.accounts.isEmpty || state.categories.isEmpty) ...[
                const SizedBox(height: 18),
                _MissingRequirement(
                  hasAccounts: state.accounts.isNotEmpty,
                  hasCategories: state.categories.isNotEmpty,
                ),
              ] else ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Ex: Salário, freelance, aluguel recebido',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da receita.';
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
                        _categoryName(state, suggestion.categoryId),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _incomeKind == _IncomeKind.installment
                        ? 'Valor da parcela'
                        : 'Valor',
                    hintText: 'Ex: 4850,00',
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
                Text('Tipo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in _IncomeKind.values)
                      ChoiceChip(
                        selected: _incomeKind == kind,
                        label: Text(kind.label),
                        avatar: Icon(kind.icon, size: 18),
                        onSelected: (_) {
                          setState(() => _incomeKind = kind);
                        },
                      ),
                  ],
                ),
                if (_incomeKind == _IncomeKind.installment) ...[
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
                ],
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _pickDate(isDueDate: true),
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de vencimento',
                      prefixIcon: Icon(Icons.event_available_rounded),
                    ),
                    child: Text(_formatDate(_dueDate)),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isPaid,
                  title: const Text('Pagamento efetivado'),
                  subtitle: Text(
                    _isPaid
                        ? 'A receita entra no saldo da conta ao salvar.'
                        : 'A receita fica prevista e não altera o saldo agora.',
                  ),
                  onChanged: (value) => setState(() => _isPaid = value),
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
                      tooltip: 'Criar categoria de receita',
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
                DropdownButtonFormField<int>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Conta de destino',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: [
                    for (final account in state.accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} - ${CurrencyUtils.formatCents(
                            account.balanceCents,
                            currencyCode: account.currencyCode,
                          )}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAccountId = value);
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _pickDate(isDueDate: false),
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.today_rounded),
                    ),
                    child: Text(_formatDate(_date)),
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

  bool _canSubmit(IncomeFormState state) {
    return !_isSubmitting &&
        state.accounts.isNotEmpty &&
        state.categories.isNotEmpty;
  }

  void _syncSelections(IncomeFormState state) {
    final pendingCategoryId = _pendingCategoryId;
    if (pendingCategoryId != null &&
        state.categories.any((category) => category.id == pendingCategoryId)) {
      _selectedCategoryId = pendingCategoryId;
      _selectedSubcategoryId = null;
      _pendingCategoryId = null;
    }

    if (state.accounts.isNotEmpty &&
        !state.accounts.any((account) => account.id == _selectedAccountId)) {
      _selectedAccountId = state.accounts.first.id;
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
    final state = ref.read(incomeFormViewModelProvider);
    _nameController.text = suggestion.description;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );

    setState(() {
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

  String _categoryName(IncomeFormState state, int categoryId) {
    for (final category in state.categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return '';
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final currentDate = isDueDate ? _dueDate : _date;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (pickedDate != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = pickedDate;
        } else {
          _date = pickedDate;
        }
      });
    }
  }

  Future<void> _createCategory() async {
    final name = await _askForName(
      title: 'Nova categoria de receita',
      label: 'Nome da categoria',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    final id = await ref
        .read(incomeFormViewModelProvider.notifier)
        .createIncomeCategory(name);
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

    final id =
        await ref.read(incomeFormViewModelProvider.notifier).createSubcategory(
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
        _selectedAccountId == null ||
        _selectedCategoryId == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(incomeFormViewModelProvider.notifier).saveIncome(
            name: _nameController.text.trim(),
            amountCents: CurrencyUtils.parseToCents(_amountController.text),
            incomeKind: _incomeKind.value,
            accountId: _selectedAccountId!,
            categoryId: _selectedCategoryId!,
            subcategoryId: _selectedSubcategoryId,
            dueDate: _dueDate,
            date: _date,
            isPaid: _isPaid,
            totalInstallments: _incomeKind == _IncomeKind.installment
                ? int.parse(_installmentsController.text)
                : null,
          );

      if (!mounted) {
        return;
      }

      if (keepOpen) {
        _nameController.clear();
        _amountController.clear();
        setState(() {
          final now = DateTime.now();
          _date = now;
          _dueDate = now;
          _isPaid = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receita salva.')),
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
    required this.hasAccounts,
    required this.hasCategories,
  });

  final bool hasAccounts;
  final bool hasCategories;

  @override
  Widget build(BuildContext context) {
    final message = !hasAccounts
        ? 'Cadastre uma conta antes de lançar receitas.'
        : !hasCategories
            ? 'Crie uma categoria de receita antes de continuar.'
            : 'Ainda faltam dados para lançar a receita.';

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

enum _IncomeKind {
  single('single', 'Única', Icons.looks_one_rounded),
  fixedMonthly('fixed_monthly', 'Fixa mensal', Icons.event_repeat_rounded),
  installment('installment', 'Parcelada', Icons.view_week_rounded);

  const _IncomeKind(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}
