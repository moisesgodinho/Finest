import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/exchange_rate_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/account_preview.dart';
import 'transfer_form_view_model.dart';

class TransferFormSheet extends ConsumerStatefulWidget {
  const TransferFormSheet({
    super.key,
    this.initialToAccountId,
  });

  final int? initialToAccountId;

  @override
  ConsumerState<TransferFormSheet> createState() => _TransferFormSheetState();
}

class _TransferFormSheetState extends ConsumerState<TransferFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '2');
  _TransferKind _transferKind = _TransferKind.single;
  int? _selectedFromAccountId;
  int? _selectedToAccountId;
  late DateTime _dueDate;
  late DateTime _date;
  bool _isPaid = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dueDate = now;
    _date = now;
    _selectedToAccountId = widget.initialToAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferFormViewModelProvider);
    _syncSelections(state.accounts);
    final sourceAccounts = _sourceAccounts(state.accounts);

    ref.listen(
      transferFormViewModelProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      },
    );

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
                      'Transferência',
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
              if (!_hasTransferRequirement(state.accounts)) ...[
                const SizedBox(height: 18),
                const _MissingRequirement(),
              ] else ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Ex: Reserva, poupança, carteira',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da transferência.';
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
                  decoration: InputDecoration(
                    labelText: _transferKind == _TransferKind.installment
                        ? 'Valor da parcela'
                        : 'Valor',
                    hintText: 'Ex: 250,00',
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
                    for (final kind in _TransferKind.values)
                      ChoiceChip(
                        selected: _transferKind == kind,
                        label: Text(kind.label),
                        avatar: Icon(kind.icon, size: 18),
                        onSelected: (_) {
                          setState(() => _transferKind = kind);
                        },
                      ),
                  ],
                ),
                if (_transferKind == _TransferKind.installment) ...[
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
                  title: const Text('Transferência efetivada'),
                  subtitle: Text(
                    _isPaid
                        ? 'Atualiza os saldos das duas contas ao salvar.'
                        : 'Fica prevista e não altera os saldos agora.',
                  ),
                  onChanged: (value) => setState(() => _isPaid = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  key: ValueKey('from-${_selectedFromAccountId ?? 0}'),
                  initialValue: _selectedFromAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Conta de origem',
                    prefixIcon: Icon(Icons.call_made_rounded),
                  ),
                  items: [
                    for (final account in sourceAccounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(_accountLabel(account)),
                      ),
                  ],
                  validator: (value) {
                    if (value == null) {
                      return 'Informe a conta de origem.';
                    }
                    if (value == _selectedToAccountId) {
                      return 'A origem deve ser diferente do destino.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedFromAccountId = value;
                      if (_selectedToAccountId == value) {
                        _selectedToAccountId = _firstOtherAccountId(
                          state.accounts,
                          value,
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  key: ValueKey('to-${_selectedToAccountId ?? 0}'),
                  initialValue: _selectedToAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Conta de destino',
                    prefixIcon: Icon(Icons.call_received_rounded),
                  ),
                  items: [
                    for (final account in state.accounts)
                      if (account.id != _selectedFromAccountId)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(_accountLabel(account)),
                        ),
                  ],
                  validator: (value) {
                    if (value == null) {
                      return 'Informe a conta de destino.';
                    }
                    if (value == _selectedFromAccountId) {
                      return 'O destino deve ser diferente da origem.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedToAccountId = value;
                      if (_selectedFromAccountId == value) {
                        _selectedFromAccountId = _firstOtherAccountId(
                          state.accounts,
                          value,
                        );
                      }
                    });
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
                    onPressed: _canSubmit(state) ? _save : null,
                    child: Text(_isSubmitting ? 'Salvando...' : 'Salvar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit(TransferFormState state) {
    return !_isSubmitting && _hasTransferRequirement(state.accounts);
  }

  void _syncSelections(List<AccountPreview> accounts) {
    final sourceAccounts = _sourceAccounts(accounts);

    if (!_hasTransferRequirement(accounts)) {
      _selectedFromAccountId = null;
      _selectedToAccountId = null;
      return;
    }

    if (!sourceAccounts
        .any((account) => account.id == _selectedFromAccountId)) {
      _selectedFromAccountId = sourceAccounts.first.id;
    }

    if (!accounts.any((account) => account.id == _selectedToAccountId) ||
        _selectedToAccountId == _selectedFromAccountId) {
      _selectedToAccountId = _firstOtherAccountId(
        accounts,
        _selectedFromAccountId,
      );
    }
  }

  int? _firstOtherAccountId(List<AccountPreview> accounts, int? selectedId) {
    for (final account in accounts) {
      if (account.id != selectedId) {
        return account.id;
      }
    }
    return null;
  }

  bool _hasTransferRequirement(List<AccountPreview> accounts) {
    final sourceAccounts = _sourceAccounts(accounts);
    return sourceAccounts.isNotEmpty &&
        accounts.any((account) => account.id != sourceAccounts.first.id);
  }

  List<AccountPreview> _sourceAccounts(List<AccountPreview> accounts) {
    return accounts.where((account) => !account.isGoal).toList();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _selectedFromAccountId == null ||
        _selectedToAccountId == null) {
      return;
    }

    final state = ref.read(transferFormViewModelProvider);
    final fromAccount = _accountById(state.accounts, _selectedFromAccountId!);
    final toAccount = _accountById(state.accounts, _selectedToAccountId!);
    if (fromAccount == null || toAccount == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final amountCents = CurrencyUtils.parseToCents(_amountController.text);
      final conversion = await _conversionForTransfer(
        fromAccount: fromAccount,
        toAccount: toAccount,
        amountCents: amountCents,
      );
      if (conversion == null) {
        return;
      }

      await ref.read(transferFormViewModelProvider.notifier).saveTransfer(
            name: _nameController.text.trim(),
            amountCents: amountCents,
            toAmountCents: conversion.toAmountCents,
            transferKind: _transferKind.value,
            fromAccountId: _selectedFromAccountId!,
            toAccountId: _selectedToAccountId!,
            dueDate: _dueDate,
            isPaid: _isPaid,
            date: _date,
            totalInstallments: _transferKind == _TransferKind.installment
                ? int.parse(_installmentsController.text)
                : null,
            exchangeRate: conversion.exchangeRate,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar transferencia: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _accountLabel(AccountPreview account) {
    final balance = CurrencyUtils.formatCents(
      account.balanceCents,
      currencyCode: account.currencyCode,
    );
    return '${account.name} - $balance';
  }

  AccountPreview? _accountById(List<AccountPreview> accounts, int accountId) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  Future<_ConversionResult?> _conversionForTransfer({
    required AccountPreview fromAccount,
    required AccountPreview toAccount,
    required int amountCents,
  }) async {
    if (fromAccount.currencyCode == toAccount.currencyCode) {
      return _ConversionResult(
        toAmountCents: amountCents,
        exchangeRate: 1,
      );
    }

    final quote = await ref.read(exchangeRateServiceProvider).quote(
          fromCurrency: fromAccount.currencyCode,
          toCurrency: toAccount.currencyCode,
        );
    if (!mounted) {
      return null;
    }

    return _confirmConvertedAmount(
      fromAccount: fromAccount,
      toAccount: toAccount,
      amountCents: amountCents,
      suggestedToAmountCents: quote.convertCents(amountCents),
      exchangeRate: quote.rate,
    );
  }

  Future<_ConversionResult?> _confirmConvertedAmount({
    required AccountPreview fromAccount,
    required AccountPreview toAccount,
    required int amountCents,
    required int suggestedToAmountCents,
    required double exchangeRate,
  }) async {
    final controller = TextEditingController(
      text: CurrencyUtils.formatCents(
        suggestedToAmountCents,
        currencyCode: toAccount.currencyCode,
      ),
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar conversao'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${CurrencyUtils.formatCents(amountCents, currencyCode: fromAccount.currencyCode)} saem de ${fromAccount.name}.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Cotacao sugerida: 1 ${fromAccount.currencyCode} = ${exchangeRate.toStringAsFixed(4)} ${toAccount.currencyCode}.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Valor que entra em ${toAccount.currencyCode}',
                    prefixIcon: const Icon(Icons.currency_exchange_rounded),
                  ),
                  validator: (value) {
                    if (value == null ||
                        CurrencyUtils.parseToCents(value) <= 0) {
                      return 'Informe o valor convertido.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(
                    CurrencyUtils.parseToCents(controller.text),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null) {
      return null;
    }
    return _ConversionResult(
      toAmountCents: result,
      exchangeRate: exchangeRate,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ConversionResult {
  const _ConversionResult({
    required this.toAmountCents,
    required this.exchangeRate,
  });

  final int toAmountCents;
  final double exchangeRate;
}

class _MissingRequirement extends StatelessWidget {
  const _MissingRequirement();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 44,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'Cadastre uma conta normal e uma conta de destino antes de criar transferências.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

enum _TransferKind {
  single('single', 'Única', Icons.looks_one_rounded),
  installment('installment', 'Parcelada', Icons.view_week_rounded),
  fixedMonthly('fixed_monthly', 'Fixa mensal', Icons.event_repeat_rounded);

  const _TransferKind(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}
