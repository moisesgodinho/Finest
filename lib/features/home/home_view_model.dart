import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/category_expense_preview.dart';
import '../../data/models/category_model.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/transaction_preview.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class HomeState {
  const HomeState({
    required this.userName,
    required this.monthLabel,
    required this.currentBalanceCents,
    required this.projectedBalanceCents,
    required this.initialMonthBalanceCents,
    required this.incomeCents,
    required this.expenseCents,
    required this.pendingIncomeCents,
    required this.pendingExpenseCents,
    required this.creditCardInvoiceCents,
    required this.creditCard,
    required this.categories,
    required this.recentTransactions,
    this.isBalanceVisible = true,
  });

  factory HomeState.initial({required String userName}) {
    return HomeState(
      userName: userName,
      monthLabel: AppDateUtils.monthYearLabel(DateTime.now()),
      currentBalanceCents: 0,
      projectedBalanceCents: 0,
      initialMonthBalanceCents: 0,
      incomeCents: 0,
      expenseCents: 0,
      pendingIncomeCents: 0,
      pendingExpenseCents: 0,
      creditCardInvoiceCents: 0,
      creditCard: const CreditCardPreview(
        id: 0,
        name: 'Nenhum cartão',
        lastDigits: '0000',
        brand: 'other',
        brandLabel: 'Outra',
        invoiceCents: 0,
        limitCents: 0,
        usedPercent: 0,
        color: AppColors.primaryDark,
        colorHex: '#004D3A',
        closingDay: 5,
        dueDay: 15,
        isPrimary: false,
      ),
      categories: const [],
      recentTransactions: const [],
    );
  }

  final String userName;
  final String monthLabel;
  final int currentBalanceCents;
  final int projectedBalanceCents;
  final int initialMonthBalanceCents;
  final int incomeCents;
  final int expenseCents;
  final int pendingIncomeCents;
  final int pendingExpenseCents;
  final int creditCardInvoiceCents;
  final CreditCardPreview creditCard;
  final List<CategoryExpensePreview> categories;
  final List<TransactionPreview> recentTransactions;
  final bool isBalanceVisible;

  double get availableBudgetPercent {
    if (incomeCents == 0) {
      return 0;
    }
    return ((incomeCents - expenseCents) / incomeCents)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int get monthlyFlowBaseCents {
    return incomeCents > expenseCents ? incomeCents : expenseCents;
  }

  double get incomeProgressPercent {
    if (monthlyFlowBaseCents == 0) {
      return 0;
    }
    return (incomeCents / monthlyFlowBaseCents).clamp(0.0, 1.0).toDouble();
  }

  double get expenseProgressPercent {
    if (monthlyFlowBaseCents == 0) {
      return 0;
    }
    return (expenseCents / monthlyFlowBaseCents).clamp(0.0, 1.0).toDouble();
  }

  int get totalPendingOutflowCents {
    return pendingExpenseCents + creditCardInvoiceCents;
  }

  String get balanceVariationLabel {
    if (currentBalanceCents == 0 && initialMonthBalanceCents == 0) {
      return 'Sem saldo cadastrado';
    }
    if (initialMonthBalanceCents == 0) {
      return 'Saldo atualizado pelas contas';
    }

    final difference = currentBalanceCents - initialMonthBalanceCents;
    if (difference == 0) {
      return 'Sem variação vs. início do mês';
    }

    final percent = (difference / initialMonthBalanceCents.abs()) * 100;
    final formattedPercent =
        percent.abs().toStringAsFixed(1).replaceAll('.', ',');
    final direction = difference > 0 ? 'acima' : 'abaixo';
    return '$formattedPercent% $direction do início do mês';
  }

  HomeState copyWith({
    int? currentBalanceCents,
    int? projectedBalanceCents,
    int? initialMonthBalanceCents,
    int? incomeCents,
    int? expenseCents,
    int? pendingIncomeCents,
    int? pendingExpenseCents,
    int? creditCardInvoiceCents,
    CreditCardPreview? creditCard,
    List<CategoryExpensePreview>? categories,
    List<TransactionPreview>? recentTransactions,
    bool? isBalanceVisible,
  }) {
    return HomeState(
      userName: userName,
      monthLabel: monthLabel,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      projectedBalanceCents:
          projectedBalanceCents ?? this.projectedBalanceCents,
      initialMonthBalanceCents:
          initialMonthBalanceCents ?? this.initialMonthBalanceCents,
      incomeCents: incomeCents ?? this.incomeCents,
      expenseCents: expenseCents ?? this.expenseCents,
      pendingIncomeCents: pendingIncomeCents ?? this.pendingIncomeCents,
      pendingExpenseCents: pendingExpenseCents ?? this.pendingExpenseCents,
      creditCardInvoiceCents:
          creditCardInvoiceCents ?? this.creditCardInvoiceCents,
      creditCard: creditCard ?? this.creditCard,
      categories: categories ?? this.categories,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel({
    required String userName,
    required int? userId,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required TransactionRepository transactionRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _creditCardRepository = creditCardRepository,
        _transactionRepository = transactionRepository,
        super(HomeState.initial(userName: userName)) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final TransactionRepository _transactionRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<List<CreditCard>>? _creditCardsSubscription;
  StreamSubscription<List<CreditCardInvoice>>? _creditCardInvoicesSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  List<Account> _accounts = [];
  List<CategoryModel> _categories = [];
  List<CreditCard> _creditCards = [];
  List<CreditCardInvoice> _creditCardInvoices = [];
  List<FinanceTransaction> _transactions = [];

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts;
        _publishState();
      },
    );

    _categoriesSubscription =
        _categoryRepository.watchCategories(userId).listen(
      (categories) {
        _categories = categories;
        _publishState();
      },
    );

    _creditCardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (cards) {
        _creditCards = cards;
        _publishState();
      },
    );

    _creditCardInvoicesSubscription =
        _creditCardRepository.watchInvoices(userId).listen(
      (invoices) {
        _creditCardInvoices = invoices;
        _publishState();
      },
    );

    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState();
      },
    );
  }

  void _publishState() {
    final now = DateTime.now();
    final firstDay = AppDateUtils.firstDayOfMonth(now);
    final lastDay = AppDateUtils.lastDayOfMonth(now);
    final monthTransactions = _transactions.where((transaction) {
      final referenceDate = _referenceDate(transaction);
      return !referenceDate.isBefore(firstDay) &&
          !referenceDate.isAfter(lastDay);
    }).toList();

    final incomeCents = monthTransactions
        .where(
          (transaction) =>
              transaction.type == 'income' &&
              transaction.paymentMethod != 'credit_card',
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final expenseCents = monthTransactions
        .where((transaction) => transaction.type == 'expense')
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final paidAccountIncomeCents = monthTransactions
        .where(
          (transaction) =>
              transaction.isPaid &&
              transaction.paymentMethod != 'credit_card' &&
              transaction.type == 'income',
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final paidAccountExpenseCents = monthTransactions
        .where(
          (transaction) =>
              transaction.isPaid &&
              transaction.paymentMethod != 'credit_card' &&
              transaction.type == 'expense',
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final pendingIncomeCents = monthTransactions
        .where(
          (transaction) =>
              !transaction.isPaid &&
              transaction.paymentMethod != 'credit_card' &&
              transaction.type == 'income',
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final pendingExpenseCents = monthTransactions
        .where(
          (transaction) =>
              !transaction.isPaid &&
              transaction.paymentMethod != 'credit_card' &&
              transaction.type == 'expense',
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);
    final creditCardInvoiceTotalsByCard =
        _openCurrentCreditCardInvoiceTotalsByCard(now);
    final creditCardInvoiceCents = creditCardInvoiceTotalsByCard.values
        .fold<int>(0, (total, amount) => total + amount);
    final paidCreditCardInvoiceCents =
        _paidCreditCardInvoicesInMonth(firstDay, lastDay);
    final currentBalanceCents = _accounts.fold<int>(
      0,
      (total, account) => account.includeInTotalBalance
          ? total + account.currentBalance
          : total,
    );
    final initialMonthBalanceCents = currentBalanceCents -
        paidAccountIncomeCents +
        paidAccountExpenseCents +
        paidCreditCardInvoiceCents;
    final projectedBalanceCents = currentBalanceCents +
        pendingIncomeCents -
        pendingExpenseCents -
        creditCardInvoiceCents;
    final categoryMap = {
      for (final category in _categories) category.id: category,
    };
    final accountsById = {for (final account in _accounts) account.id: account};

    state = state.copyWith(
      currentBalanceCents: currentBalanceCents,
      projectedBalanceCents: projectedBalanceCents,
      initialMonthBalanceCents: initialMonthBalanceCents,
      incomeCents: incomeCents,
      expenseCents: expenseCents,
      pendingIncomeCents: pendingIncomeCents,
      pendingExpenseCents: pendingExpenseCents,
      creditCardInvoiceCents: creditCardInvoiceCents,
      creditCard: _buildPrimaryCard(
        accountsById,
        creditCardInvoiceTotalsByCard,
      ),
      categories: _buildCategoryPreviews(
        monthTransactions: monthTransactions,
        categoryMap: categoryMap,
        expenseCents: expenseCents,
      ),
      recentTransactions: _buildRecentTransactions(categoryMap),
    );
  }

  CreditCardPreview _buildPrimaryCard(
    Map<int, Account> accountsById,
    Map<int, int> creditCardInvoiceTotalsByCard,
  ) {
    CreditCard? selectedCard;
    for (final card in _creditCards) {
      if (card.isPrimary) {
        selectedCard = card;
        break;
      }
    }
    selectedCard ??= _creditCards.isEmpty ? null : _creditCards.first;

    if (selectedCard == null) {
      return state.creditCard;
    }

    final defaultAccount = accountsById[selectedCard.defaultPaymentAccountId];
    final invoiceCents = creditCardInvoiceTotalsByCard[selectedCard.id] ??
        selectedCard.currentInvoice;
    final usedPercent =
        selectedCard.limit == 0 ? 0.0 : invoiceCents / selectedCard.limit;

    return CreditCardPreview(
      id: selectedCard.id,
      name: selectedCard.name,
      bankName: selectedCard.bankName,
      lastDigits: selectedCard.lastDigits,
      brand: selectedCard.brand,
      brandLabel: _brandLabel(selectedCard.brand),
      invoiceCents: invoiceCents,
      limitCents: selectedCard.limit,
      usedPercent: usedPercent.clamp(0.0, 1.0).toDouble(),
      color: _parseColor(selectedCard.color),
      colorHex: selectedCard.color,
      closingDay: selectedCard.closingDay,
      dueDay: selectedCard.dueDay,
      isPrimary: selectedCard.isPrimary,
      defaultPaymentAccountId: selectedCard.defaultPaymentAccountId,
      defaultPaymentAccountName: defaultAccount?.name,
    );
  }

  Map<int, int> _openCurrentCreditCardInvoiceTotalsByCard(DateTime month) {
    final totals = <int, int>{};

    for (final card in _creditCards) {
      final invoice = _invoiceForCardMonth(
        cardId: card.id,
        month: month.month,
        year: month.year,
      );
      if (invoice?.status == 'paid') {
        totals[card.id] = 0;
        continue;
      }

      final invoiceTransactions = _transactions
          .where(
            (transaction) =>
                transaction.paymentMethod == 'credit_card' &&
                transaction.creditCardId == card.id &&
                (transaction.invoiceMonth ?? transaction.date.month) ==
                    month.month &&
                (transaction.invoiceYear ?? transaction.date.year) ==
                    month.year,
          )
          .toList();
      final transactionTotal = invoiceTransactions.fold<int>(
        0,
        (total, transaction) => total + _invoiceAmountDelta(transaction),
      );

      totals[card.id] = invoiceTransactions.isNotEmpty
          ? transactionTotal.clamp(0, 1 << 31).toInt()
          : invoice?.amount ?? card.currentInvoice;
    }

    return totals;
  }

  CreditCardInvoice? _invoiceForCardMonth({
    required int cardId,
    required int month,
    required int year,
  }) {
    for (final invoice in _creditCardInvoices) {
      if (invoice.creditCardId == cardId &&
          invoice.month == month &&
          invoice.year == year) {
        return invoice;
      }
    }
    return null;
  }

  int _paidCreditCardInvoicesInMonth(DateTime firstDay, DateTime lastDay) {
    return _creditCardInvoices.where((invoice) {
      final paidAt = invoice.paidAt;
      if (invoice.status != 'paid' || paidAt == null) {
        return false;
      }
      return !paidAt.isBefore(firstDay) && !paidAt.isAfter(lastDay);
    }).fold<int>(0, (total, invoice) => total + invoice.amount);
  }

  int _invoiceAmountDelta(FinanceTransaction transaction) {
    return transaction.type == 'income'
        ? -transaction.amount
        : transaction.amount;
  }

  DateTime _referenceDate(FinanceTransaction transaction) {
    if (transaction.paymentMethod == 'credit_card' &&
        transaction.invoiceMonth != null &&
        transaction.invoiceYear != null) {
      return DateTime(
        transaction.invoiceYear!,
        transaction.invoiceMonth!,
        1,
      );
    }

    return transaction.dueDate ?? transaction.date;
  }

  List<CategoryExpensePreview> _buildCategoryPreviews({
    required List<FinanceTransaction> monthTransactions,
    required Map<int, CategoryModel> categoryMap,
    required int expenseCents,
  }) {
    final totalsByCategory = <int, int>{};
    for (final transaction in monthTransactions) {
      if (transaction.type != 'expense') {
        continue;
      }
      totalsByCategory.update(
        transaction.categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final entries = totalsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (final entry in entries.take(5))
        CategoryExpensePreview(
          name: categoryMap[entry.key]?.name ?? 'Sem categoria',
          amountCents: entry.value,
          percent: expenseCents == 0 ? 0 : entry.value / expenseCents,
          color: categoryMap[entry.key]?.color ?? AppColors.primary,
          icon: categoryMap[entry.key]?.icon ?? Icons.category_rounded,
        ),
    ];
  }

  List<TransactionPreview> _buildRecentTransactions(
    Map<int, CategoryModel> categoryMap,
  ) {
    final sortedTransactions = [..._transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return [
      for (final transaction in sortedTransactions.take(4))
        TransactionPreview(
          title: transaction.description,
          subtitle:
              categoryMap[transaction.categoryId]?.name ?? 'Sem categoria',
          amountCents: transaction.amount,
          icon: categoryMap[transaction.categoryId]?.icon ??
              Icons.category_rounded,
          iconColor:
              categoryMap[transaction.categoryId]?.color ?? AppColors.primary,
          dateLabel: _dateLabel(transaction.date),
          isIncome: transaction.type == 'income',
          isPaid: transaction.isPaid,
        ),
    ];
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) {
      return 'Hoje';
    }
    if (target == today.subtract(const Duration(days: 1))) {
      return 'Ontem';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _brandLabel(String brand) {
    return switch (brand) {
      'visa' => 'Visa',
      'mastercard' => 'Mastercard',
      'elo' => 'Elo',
      'amex' => 'American Express',
      'hipercard' => 'Hipercard',
      _ => 'Outra',
    };
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primaryDark : Color(parsed);
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _creditCardsSubscription?.cancel();
    _creditCardInvoicesSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final user = ref.watch(authStateProvider.select((state) => state.user));
  return HomeViewModel(
    userName: user?.name ?? 'Camila Souza',
    userId: user?.id,
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
