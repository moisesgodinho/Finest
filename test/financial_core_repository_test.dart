import 'dart:async';

import 'package:drift/native.dart';
import 'package:finest/core/database/app_database.dart';
import 'package:finest/core/currency/exchange_rate_service.dart';
import 'package:finest/data/models/create_account_request.dart';
import 'package:finest/data/models/create_credit_card_request.dart';
import 'package:finest/data/models/create_goal_request.dart';
import 'package:finest/data/models/create_transaction_request.dart';
import 'package:finest/data/models/create_transfer_request.dart';
import 'package:finest/data/models/transaction_series_scope.dart';
import 'package:finest/data/models/update_transaction_request.dart';
import 'package:finest/data/models/update_transfer_request.dart';
import 'package:finest/data/repositories/account_repository.dart';
import 'package:finest/data/repositories/category_repository.dart';
import 'package:finest/data/repositories/credit_card_repository.dart';
import 'package:finest/data/repositories/goal_repository.dart';
import 'package:finest/data/repositories/transaction_repository.dart';
import 'package:finest/data/repositories/transfer_repository.dart';
import 'package:finest/data/repositories/user_repository.dart';
import 'package:finest/features/accounts/accounts_view_model.dart';
import 'package:finest/features/home/expense_form_view_model.dart';
import 'package:finest/features/home/home_view_model.dart';
import 'package:finest/features/home/income_form_view_model.dart';
import 'package:finest/features/transactions/transactions_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftAccountRepository accounts;
  late DriftCategoryRepository categories;
  late DriftCreditCardRepository cards;
  late DriftGoalRepository goals;
  late DriftTransactionRepository transactions;
  late DriftTransferRepository transfers;
  late DriftUserRepository users;
  late int userId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = DriftAccountRepository(database);
    categories = DriftCategoryRepository(database);
    cards = DriftCreditCardRepository(database);
    goals = DriftGoalRepository(database);
    transactions = DriftTransactionRepository(database);
    transfers = DriftTransferRepository(database);
    users = DriftUserRepository(database);

    final user = await users.findOrCreate(
      name: 'Camila Souza',
      email: 'camila@example.com',
    );
    userId = user.id;
  });

  tearDown(() async {
    await database.close();
  });

  test('mantem saldo da conta consistente em criar, efetivar, editar e excluir',
      () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final incomeCategoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Salario',
    );
    final expenseCategoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Mercado',
    );

    final incomeId = await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: incomeCategoryId,
        type: 'income',
        description: 'Salario',
        amountCents: 25000,
        date: DateTime(2026, 5, 5),
      ),
    );
    expect(await _accountBalance(database, userId, accountId), 125000);

    final expenseId = await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Mercado',
        amountCents: 10000,
        date: DateTime(2026, 5, 6),
        dueDate: DateTime(2026, 5, 10),
        isPaid: false,
      ),
    );
    expect(await _accountBalance(database, userId, accountId), 125000);

    await transactions.markTransactionAsPaid(
      userId: userId,
      transactionId: expenseId,
    );
    expect(await _accountBalance(database, userId, accountId), 115000);

    await transactions.updateTransaction(
      UpdateTransactionRequest(
        userId: userId,
        transactionId: expenseId,
        accountId: accountId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Mercado atualizado',
        amountCents: 15000,
        date: DateTime(2026, 5, 6),
        dueDate: DateTime(2026, 5, 10),
        transactionKind: 'single',
        isPaid: true,
      ),
    );
    expect(await _accountBalance(database, userId, accountId), 110000);

    await transactions.deleteTransaction(
      userId: userId,
      transactionId: incomeId,
    );
    expect(await _accountBalance(database, userId, accountId), 85000);
  });

  test('mantem transferencia entre moedas consistente ao editar e excluir',
      () async {
    final brlAccountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
      currencyCode: 'BRL',
    );
    final usdAccountId = await _createAccount(
      accounts,
      userId: userId,
      name: 'Conta USD',
      initialBalance: 50000,
      currencyCode: 'USD',
    );

    final transferId = await transfers.createTransfer(
      CreateTransferRequest(
        userId: userId,
        fromAccountId: brlAccountId,
        toAccountId: usdAccountId,
        name: 'Cambio',
        amountCents: 20000,
        toAmountCents: 4000,
        exchangeRate: 0.2,
        transferKind: 'single',
        dueDate: DateTime(2026, 5, 7),
        isPaid: true,
        date: DateTime(2026, 5, 7),
      ),
    );

    expect(await _accountBalance(database, userId, brlAccountId), 80000);
    expect(await _accountBalance(database, userId, usdAccountId), 54000);

    await transfers.updateTransfer(
      UpdateTransferRequest(
        userId: userId,
        transferId: transferId,
        fromAccountId: brlAccountId,
        toAccountId: usdAccountId,
        name: 'Cambio ajustado',
        amountCents: 30000,
        toAmountCents: 6000,
        exchangeRate: 0.2,
        transferKind: 'single',
        dueDate: DateTime(2026, 5, 7),
        isPaid: true,
        date: DateTime(2026, 5, 7),
      ),
    );

    expect(await _accountBalance(database, userId, brlAccountId), 70000);
    expect(await _accountBalance(database, userId, usdAccountId), 56000);

    await transfers.deleteTransfer(userId: userId, transferId: transferId);

    expect(await _accountBalance(database, userId, brlAccountId), 100000);
    expect(await _accountBalance(database, userId, usdAccountId), 50000);
  });

  test('mantem fatura e conta consistentes com gasto, cashback e pagamento',
      () async {
    final now = DateTime.now();
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final expenseCategoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Compras',
    );
    final incomeCategoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Cashback',
    );
    final cardId = await cards.createCard(
      CreateCreditCardRequest(
        userId: userId,
        name: 'Nubank',
        lastDigits: '1234',
        brand: 'mastercard',
        limitCents: 500000,
        currentInvoiceCents: 0,
        defaultPaymentAccountId: accountId,
        closingDay: 8,
        dueDay: 15,
        isPrimary: true,
      ),
    );

    final expenseId = await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        creditCardId: cardId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Compra no cartao',
        amountCents: 20000,
        date: DateTime(now.year, now.month, 2),
        paymentMethod: 'credit_card',
        invoiceMonth: now.month,
        invoiceYear: now.year,
      ),
    );
    expect(await _accountBalance(database, userId, accountId), 100000);
    expect(await _cardCurrentInvoice(database, userId, cardId), 20000);
    expect(await _invoiceAmount(database, userId, cardId, now), 20000);

    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        creditCardId: cardId,
        categoryId: incomeCategoryId,
        type: 'income',
        description: 'Cashback',
        amountCents: 5000,
        date: DateTime(now.year, now.month, 3),
        paymentMethod: 'credit_card',
        invoiceMonth: now.month,
        invoiceYear: now.year,
      ),
    );
    expect(await _cardCurrentInvoice(database, userId, cardId), 15000);
    expect(await _invoiceAmount(database, userId, cardId, now), 15000);

    final invoice = await database.creditCardInvoicesDao.findByCardMonth(
      userId: userId,
      creditCardId: cardId,
      month: now.month,
      year: now.year,
    );
    await cards.payInvoice(userId: userId, invoiceId: invoice!.id);

    expect(await _accountBalance(database, userId, accountId), 85000);
    expect(await _cardCurrentInvoice(database, userId, cardId), 0);
    final paidInvoice = await database.creditCardInvoicesDao.findByIdForUser(
      id: invoice.id,
      userId: userId,
    );
    expect(paidInvoice?.status, 'paid');
    expect(paidInvoice?.amount, 15000);

    await expectLater(
      transactions.deleteTransaction(userId: userId, transactionId: expenseId),
      throwsStateError,
    );
    expect(await _accountBalance(database, userId, accountId), 85000);
  });

  test('metas usam conta vinculada sem criar uma segunda conta de meta',
      () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      name: 'Nubank',
      initialBalance: 2274590,
    );
    final categoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Aporte',
    );

    final goalId = await goals.createGoal(
      CreateGoalRequest(
        userId: userId,
        name: 'Casa propria',
        linkedAccountId: accountId,
        targetAmountCents: 10000000,
        targetDate: DateTime(2028, 12, 31),
      ),
    );

    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: categoryId,
        type: 'income',
        description: 'Aporte meta',
        amountCents: 50000,
        date: DateTime(2026, 5, 8),
      ),
    );

    final savedGoals = await goals.findGoals(userId);
    final savedGoal = savedGoals.singleWhere((goal) => goal.id == goalId);
    final savedAccounts = await accounts.findAccounts(userId);

    expect(savedGoal.linkedAccountId, accountId);
    expect(savedAccounts, hasLength(1));
    expect(await _accountBalance(database, userId, accountId), 2324590);
  });

  test('rollback em lote preserva saldos quando uma atualizacao falha',
      () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final expenseCategoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Compras',
    );
    final incomeCategoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Receitas',
    );

    final firstId = await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Parcela 1',
        amountCents: 10000,
        date: DateTime(2026, 5, 1),
      ),
    );
    final secondId = await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Parcela 2',
        amountCents: 10000,
        date: DateTime(2026, 6, 1),
      ),
    );
    expect(await _accountBalance(database, userId, accountId), 80000);

    await expectLater(
      transactions.updateTransactions([
        UpdateTransactionRequest(
          userId: userId,
          transactionId: firstId,
          accountId: accountId,
          categoryId: expenseCategoryId,
          type: 'expense',
          description: 'Parcela 1 atualizada',
          amountCents: 20000,
          date: DateTime(2026, 5, 1),
          transactionKind: 'single',
          isPaid: true,
        ),
        UpdateTransactionRequest(
          userId: userId,
          transactionId: secondId,
          accountId: accountId,
          categoryId: incomeCategoryId,
          type: 'expense',
          description: 'Parcela 2 invalida',
          amountCents: 20000,
          date: DateTime(2026, 6, 1),
          transactionKind: 'single',
          isPaid: true,
        ),
      ]),
      throwsStateError,
    );

    final savedTransactions = await transactions.findTransactions(userId);
    final first = savedTransactions.singleWhere(
      (transaction) => transaction.id == firstId,
    );
    final second = savedTransactions.singleWhere(
      (transaction) => transaction.id == secondId,
    );
    expect(first.amount, 10000);
    expect(second.amount, 10000);
    expect(await _accountBalance(database, userId, accountId), 80000);
  });

  test('reconciliacao recalcula saldo a partir do historico', () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final categoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Mercado',
    );
    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: categoryId,
        type: 'expense',
        description: 'Mercado',
        amountCents: 12500,
        date: DateTime(2026, 5, 9),
      ),
    );
    await database.accountsDao.updateCurrentBalance(
      id: accountId,
      userId: userId,
      currentBalance: 1,
    );

    await accounts.reconcileBalances(userId);

    expect(await _accountBalance(database, userId, accountId), 87500);
  });

  test('home mostra saldo atual consolidado pelo historico real', () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final outsideTotalAccountId = await _createAccount(
      accounts,
      userId: userId,
      name: 'Meta fora do total',
      initialBalance: 0,
      includeInTotalBalance: false,
    );
    final incomeCategoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Salario',
    );
    final expenseCategoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Contas',
    );

    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: incomeCategoryId,
        type: 'income',
        description: 'Salario',
        amountCents: 50000,
        date: DateTime(2026, 5, 5),
      ),
    );
    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Conta prevista',
        amountCents: 20000,
        date: DateTime(2026, 5, 10),
        dueDate: DateTime(2026, 5, 10),
        isPaid: false,
      ),
    );
    await transfers.createTransfer(
      CreateTransferRequest(
        userId: userId,
        fromAccountId: accountId,
        toAccountId: outsideTotalAccountId,
        name: 'Aporte fora do total',
        amountCents: 30000,
        toAmountCents: 30000,
        transferKind: 'single',
        dueDate: DateTime(2026, 5, 7),
        isPaid: true,
        date: DateTime(2026, 5, 7),
      ),
    );
    await database.accountsDao.updateCurrentBalance(
      id: accountId,
      userId: userId,
      currentBalance: 1,
    );

    final viewModel = HomeViewModel(
      userName: 'Camila Souza',
      userId: userId,
      accountRepository: accounts,
      categoryRepository: categories,
      creditCardRepository: cards,
      transactionRepository: transactions,
      transferRepository: transfers,
      exchangeRateService: ExchangeRateService(database),
      currencyCode: 'BRL',
    );
    addTearDown(viewModel.dispose);

    await _waitUntil(() => viewModel.state.currentBalanceCents == 120000);

    expect(viewModel.state.currentBalanceCents, 120000);
  });

  test('despesa fixa mensal gera horizonte de 12 meses com futuros pendentes',
      () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final categoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Assinaturas',
    );
    final viewModel = ExpenseFormViewModel(
      userId: userId,
      accountRepository: accounts,
      categoryRepository: categories,
      transactionRepository: transactions,
    );
    addTearDown(viewModel.dispose);

    await viewModel.saveExpense(
      name: 'Streaming',
      amountCents: 1990,
      expenseKind: 'fixed_monthly',
      accountId: accountId,
      categoryId: categoryId,
      dueDate: DateTime(2026, 5, 10),
      date: DateTime(2026, 5, 10),
      isPaid: true,
    );

    final savedTransactions = await transactions.findTransactions(userId);
    final streamingTransactions = savedTransactions
        .where((transaction) => transaction.description == 'Streaming')
        .toList()
      ..sort((left, right) => left.date.compareTo(right.date));

    expect(streamingTransactions, hasLength(12));
    expect(streamingTransactions.first.isPaid, isTrue);
    expect(streamingTransactions.skip(1).every((item) => !item.isPaid), isTrue);
    expect(streamingTransactions.every((item) => item.isRecurring), isTrue);
    expect(streamingTransactions.last.date, DateTime(2027, 4, 10));
    expect(await _accountBalance(database, userId, accountId), 98010);
  });

  test(
      'home mostra apenas ocorrencia atual de receita fixa mensal nos recentes',
      () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextMonth = DateTime(now.year, now.month + 1, now.day);
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final categoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Salario',
    );
    final formViewModel = IncomeFormViewModel(
      userId: userId,
      accountRepository: accounts,
      categoryRepository: categories,
      transactionRepository: transactions,
    );
    addTearDown(formViewModel.dispose);

    await formViewModel.saveIncome(
      name: 'Salario',
      amountCents: 500000,
      incomeKind: 'fixed_monthly',
      accountId: accountId,
      categoryId: categoryId,
      dueDate: today,
      date: today,
      isPaid: true,
    );

    final savedTransactions = await transactions.findTransactions(userId);
    final salaries = savedTransactions
        .where((transaction) => transaction.description == 'Salario')
        .toList()
      ..sort((left, right) => left.dueDate!.compareTo(right.dueDate!));
    expect(salaries, hasLength(12));
    expect(salaries.first.dueDate, today);
    expect(salaries[1].dueDate, nextMonth);

    final homeViewModel = HomeViewModel(
      userName: 'Camila Souza',
      userId: userId,
      accountRepository: accounts,
      categoryRepository: categories,
      creditCardRepository: cards,
      transactionRepository: transactions,
      transferRepository: transfers,
      exchangeRateService: ExchangeRateService(database),
      currencyCode: 'BRL',
    );
    addTearDown(homeViewModel.dispose);
    await _waitUntil(() => homeViewModel.state.recentTransactions.isNotEmpty);

    final recentSalaries = homeViewModel.state.recentTransactions
        .where((transaction) => transaction.title == 'Salario')
        .toList();
    expect(recentSalaries, hasLength(1));
    expect(recentSalaries.single.dateLabel, 'Hoje');
  });

  test('contas projetam saldo futuro com pendencias e faturas abertas',
      () async {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final incomeCategoryId = await categories.createIncomeCategory(
      userId: userId,
      name: 'Receitas previstas',
    );
    final expenseCategoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Despesas previstas',
    );

    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: incomeCategoryId,
        type: 'income',
        description: 'Salario previsto',
        amountCents: 50000,
        date: DateTime(nextMonth.year, nextMonth.month, 5),
        dueDate: DateTime(nextMonth.year, nextMonth.month, 5),
        isPaid: false,
      ),
    );
    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Aluguel previsto',
        amountCents: 20000,
        date: DateTime(nextMonth.year, nextMonth.month, 10),
        dueDate: DateTime(nextMonth.year, nextMonth.month, 10),
        isPaid: false,
      ),
    );

    final cardId = await cards.createCard(
      CreateCreditCardRequest(
        userId: userId,
        name: 'Nubank',
        lastDigits: '1234',
        brand: 'mastercard',
        limitCents: 500000,
        currentInvoiceCents: 0,
        defaultPaymentAccountId: accountId,
        closingDay: 8,
        dueDay: 15,
        isPrimary: true,
      ),
    );
    await transactions.createTransaction(
      CreateTransactionRequest(
        userId: userId,
        accountId: accountId,
        creditCardId: cardId,
        categoryId: expenseCategoryId,
        type: 'expense',
        description: 'Compra prevista no cartao',
        amountCents: 10000,
        date: DateTime(nextMonth.year, nextMonth.month, 3),
        paymentMethod: 'credit_card',
        invoiceMonth: nextMonth.month,
        invoiceYear: nextMonth.year,
      ),
    );

    final viewModel = AccountsViewModel(
      userId: userId,
      accountRepository: accounts,
      categoryRepository: categories,
      creditCardRepository: cards,
      transactionRepository: transactions,
      transferRepository: transfers,
      exchangeRateService: ExchangeRateService(database),
      currencyCode: 'BRL',
    );
    addTearDown(viewModel.dispose);
    await _waitUntil(() => viewModel.state.accounts.length == 1);

    viewModel.selectMonth(nextMonth);
    await _waitUntil(
      () =>
          viewModel.state.selectedMonth ==
              DateTime(nextMonth.year, nextMonth.month) &&
          viewModel.state.totalBalanceCents == 120000,
    );

    final projectedAccount = viewModel.state.accounts.single;
    expect(projectedAccount.balanceCents, 120000);
    expect(projectedAccount.monthlyIncomeCents, 50000);
    expect(projectedAccount.monthlyExpenseCents, 30000);
    expect(viewModel.state.totalIncomeCents, 50000);
    expect(viewModel.state.totalExpenseCents, 30000);
  });

  test('view model edita serie parcelada atual e futuras em lote', () async {
    final accountId = await _createAccount(
      accounts,
      userId: userId,
      initialBalance: 100000,
    );
    final categoryId = await categories.createExpenseCategory(
      userId: userId,
      name: 'Tecnologia',
    );
    for (var index = 0; index < 3; index++) {
      await transactions.createTransaction(
        CreateTransactionRequest(
          userId: userId,
          accountId: accountId,
          categoryId: categoryId,
          type: 'expense',
          description: 'Notebook (${index + 1}/3)',
          amountCents: 10000,
          date: DateTime(2026, 5 + index, 1),
          dueDate: DateTime(2026, 5 + index, 1),
          paymentMethod: 'account',
          expenseKind: 'installment',
          installmentNumber: index + 1,
          totalInstallments: 3,
        ),
      );
    }
    final viewModel = TransactionsViewModel(
      userId: userId,
      accountRepository: accounts,
      categoryRepository: categories,
      creditCardRepository: cards,
      transactionRepository: transactions,
      transferRepository: transfers,
      exchangeRateService: ExchangeRateService(database),
      currencyCode: 'BRL',
    );
    addTearDown(viewModel.dispose);
    await _waitUntil(() => viewModel.state.transactions.length == 3);

    final secondInstallment = viewModel.state.transactions.singleWhere(
      (transaction) => transaction.installmentNumber == 2,
    );
    await viewModel.updateTransaction(
      transaction: secondInstallment,
      accountId: accountId,
      categoryId: categoryId,
      type: 'expense',
      description: 'Notebook Pro',
      amountCents: 20000,
      dueDate: DateTime(2026, 6, 1),
      date: DateTime(2026, 6, 1),
      isPaid: true,
      transactionKind: 'installment',
      totalInstallments: 3,
      scope: TransactionSeriesScope.currentAndFuture,
    );

    final savedTransactions = await transactions.findTransactions(userId);
    final amountsByInstallment = {
      for (final transaction in savedTransactions)
        transaction.installmentNumber: transaction.amount,
    };
    expect(amountsByInstallment[1], 10000);
    expect(amountsByInstallment[2], 20000);
    expect(amountsByInstallment[3], 20000);
    expect(await _accountBalance(database, userId, accountId), 50000);
  });
}

Future<int> _createAccount(
  DriftAccountRepository repository, {
  required int userId,
  required int initialBalance,
  String name = 'Conta corrente',
  String type = 'checking',
  String currencyCode = 'BRL',
  bool includeInTotalBalance = true,
}) {
  return repository.createAccount(
    CreateAccountRequest(
      userId: userId,
      name: name,
      type: type,
      initialBalance: initialBalance,
      currencyCode: currencyCode,
      includeInTotalBalance: includeInTotalBalance,
    ),
  );
}

Future<int> _accountBalance(
  AppDatabase database,
  int userId,
  int accountId,
) async {
  final account = await database.accountsDao.findByIdForUser(
    id: accountId,
    userId: userId,
  );
  return account!.currentBalance;
}

Future<int> _cardCurrentInvoice(
  AppDatabase database,
  int userId,
  int cardId,
) async {
  final card = await database.creditCardsDao.findByIdForUser(
    id: cardId,
    userId: userId,
  );
  return card!.currentInvoice;
}

Future<int> _invoiceAmount(
  AppDatabase database,
  int userId,
  int cardId,
  DateTime month,
) async {
  final invoice = await database.creditCardInvoicesDao.findByCardMonth(
    userId: userId,
    creditCardId: cardId,
    month: month.month,
    year: month.year,
  );
  return invoice!.amount;
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('A condiÃ§Ã£o esperada nÃ£o aconteceu a tempo.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
