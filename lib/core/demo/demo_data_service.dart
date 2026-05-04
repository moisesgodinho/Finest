import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_user.dart';
import '../auth/auth_service.dart';
import '../database/app_database.dart';

class DemoDataService {
  const DemoDataService(this._database);

  final AppDatabase _database;

  Future<AppUser> resetAndSeedDemoData() async {
    final now = DateTime.now();
    final createdAt = DateTime(now.year, now.month, now.day, 9);
    late final int userId;

    await _database.transaction(() async {
      await _clearDatabase();

      userId = await _database.into(_database.users).insert(
            UsersCompanion.insert(
              name: 'Camila Souza',
              email: 'camila@finest.local',
              createdAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );

      final categories = await _seedCategories(
        userId: userId,
        createdAt: createdAt,
      );
      final accounts = await _seedAccounts(userId: userId, now: now);
      final cards = await _seedCards(
        userId: userId,
        accounts: accounts,
        now: now,
      );

      await _seedMonthlyPlans(
        userId: userId,
        now: now,
        accounts: accounts,
      );
      await _seedTransactions(
        userId: userId,
        now: now,
        accounts: accounts,
        cards: cards,
        categories: categories,
      );
      await _seedTransfers(
        userId: userId,
        now: now,
        accounts: accounts,
      );
      await _seedInvestments(
        userId: userId,
        now: now,
        accounts: accounts,
      );
      await _seedPetProgress(userId: userId, now: now);
      await _seedBackupLog(userId: userId, now: now);
      await _rebuildCreditCardInvoices(
        userId: userId,
        cards: cards,
        accounts: accounts,
        now: now,
      );
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(LocalAuthService.sessionUserIdKey, userId);

    return AppUser(
      id: userId,
      name: 'Camila Souza',
      email: 'camila@finest.local',
    );
  }

  Future<void> _clearDatabase() async {
    const tables = [
      'backup_logs',
      'pet_progress',
      'investments',
      'transfers',
      'transactions',
      'credit_card_invoices',
      'subcategories',
      'categories',
      'credit_cards',
      'monthly_plans',
      'accounts',
      'users',
    ];

    for (final table in tables) {
      await _database.customStatement('DELETE FROM $table');
    }

    await _database.customStatement(
      "DELETE FROM sqlite_sequence WHERE name IN (${tables.map((table) => "'$table'").join(',')})",
    );
  }

  Future<_DemoCategories> _seedCategories({
    required int userId,
    required DateTime createdAt,
  }) async {
    final categories = _DemoCategories();

    Future<int> addCategory({
      required String key,
      required String name,
      required String type,
      required String icon,
      required String color,
      required List<String> subcategories,
    }) async {
      final id = await _database.into(_database.categories).insert(
            CategoriesCompanion.insert(
              userId: userId,
              name: name,
              type: type,
              icon: Value(icon),
              color: Value(color),
              createdAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );
      categories.categoryIds[key] = id;

      for (final subcategory in subcategories) {
        final subcategoryId =
            await _database.into(_database.subcategories).insert(
                  SubcategoriesCompanion.insert(
                    userId: userId,
                    categoryId: id,
                    name: subcategory,
                    createdAt: Value(createdAt),
                    updatedAt: Value(createdAt),
                  ),
                );
        categories.subcategoryIds['$key:$subcategory'] = subcategoryId;
      }

      return id;
    }

    await addCategory(
      key: 'salary',
      name: 'Salário',
      type: 'income',
      icon: 'salary',
      color: '#0A8F4D',
      subcategories: const ['CLT', 'Adiantamento'],
    );
    await addCategory(
      key: 'freelance',
      name: 'Freelance',
      type: 'income',
      icon: 'business',
      color: '#19A974',
      subcategories: const ['Projeto', 'Consultoria'],
    );
    await addCategory(
      key: 'yield',
      name: 'Rendimentos',
      type: 'income',
      icon: 'income',
      color: '#2F80ED',
      subcategories: const ['Juros', 'Cashback'],
    );
    await addCategory(
      key: 'food',
      name: 'Alimentação',
      type: 'expense',
      icon: 'food',
      color: '#0A8F4D',
      subcategories: const ['Mercado', 'Restaurante', 'Delivery'],
    );
    await addCategory(
      key: 'transport',
      name: 'Transporte',
      type: 'expense',
      icon: 'transport',
      color: '#2F80ED',
      subcategories: const ['Aplicativo', 'Combustível', 'Ônibus'],
    );
    await addCategory(
      key: 'housing',
      name: 'Moradia',
      type: 'expense',
      icon: 'home',
      color: '#7C3AED',
      subcategories: const ['Aluguel', 'Condomínio', 'Internet', 'Casa'],
    );
    await addCategory(
      key: 'health',
      name: 'Saúde',
      type: 'expense',
      icon: 'health',
      color: '#EC4899',
      subcategories: const ['Farmácia', 'Consulta', 'Academia'],
    );
    await addCategory(
      key: 'leisure',
      name: 'Lazer',
      type: 'expense',
      icon: 'leisure',
      color: '#F59E0B',
      subcategories: const ['Streaming', 'Passeios', 'Viagem'],
    );
    await addCategory(
      key: 'shopping',
      name: 'Compras',
      type: 'expense',
      icon: 'shopping',
      color: '#D93025',
      subcategories: const ['Roupas', 'Eletrônicos', 'Casa'],
    );
    await addCategory(
      key: 'education',
      name: 'Educação',
      type: 'expense',
      icon: 'education',
      color: '#0F766E',
      subcategories: const ['Cursos', 'Livros'],
    );
    await addCategory(
      key: 'investment',
      name: 'Investimentos',
      type: 'expense',
      icon: 'investment',
      color: '#006B4F',
      subcategories: const ['Reserva', 'Aporte mensal'],
    );

    return categories;
  }

  Future<_DemoAccounts> _seedAccounts({
    required int userId,
    required DateTime now,
  }) async {
    Future<int> addAccount({
      required String name,
      required String type,
      required String bankName,
      required int initialBalance,
      required int currentBalance,
      required String color,
      required String icon,
      int? emergencyReserveTarget,
    }) {
      return _database.into(_database.accounts).insert(
            AccountsCompanion.insert(
              userId: userId,
              name: name,
              type: type,
              bankName: Value(bankName),
              initialBalance: Value(initialBalance),
              currentBalance: Value(currentBalance),
              emergencyReserveTarget: Value(emergencyReserveTarget),
              color: Value(color),
              icon: Value(icon),
              createdAt: Value(_monthDate(now, -3, 1)),
              updatedAt: Value(now),
            ),
          );
    }

    final nubank = await addAccount(
      name: 'Nubank',
      type: 'checking',
      bankName: 'Nubank',
      initialBalance: 570000,
      currentBalance: 842075,
      color: '#7C3AED',
      icon: 'wallet',
    );
    final inter = await addAccount(
      name: 'Inter',
      type: 'checking',
      bankName: 'Banco Inter',
      initialBalance: 220000,
      currentBalance: 318050,
      color: '#F97316',
      icon: 'wallet',
    );
    final reserve = await addAccount(
      name: 'Reserva de emergência',
      type: 'savings',
      bankName: 'Caixa',
      initialBalance: 280000,
      currentBalance: 560035,
      emergencyReserveTarget: 1000000,
      color: '#006B4F',
      icon: 'savings',
    );
    final investments = await addAccount(
      name: 'Investimentos',
      type: 'investment',
      bankName: 'XP Investimentos',
      initialBalance: 180000,
      currentBalance: 640000,
      color: '#0F766E',
      icon: 'trending',
    );

    return _DemoAccounts(
      nubank: nubank,
      inter: inter,
      reserve: reserve,
      investments: investments,
    );
  }

  Future<_DemoCards> _seedCards({
    required int userId,
    required _DemoAccounts accounts,
    required DateTime now,
  }) async {
    Future<int> addCard({
      required String name,
      required String bankName,
      required String lastDigits,
      required String brand,
      required int limit,
      required int accountId,
      required int closingDay,
      required int dueDay,
      required bool isPrimary,
      required String color,
    }) {
      return _database.into(_database.creditCards).insert(
            CreditCardsCompanion.insert(
              userId: userId,
              name: name,
              bankName: Value(bankName),
              lastDigits: lastDigits,
              brand: Value(brand),
              limit: Value(limit),
              currentInvoice: const Value(0),
              defaultPaymentAccountId: Value(accountId),
              closingDay: closingDay,
              dueDay: dueDay,
              isPrimary: Value(isPrimary),
              color: Value(color),
              createdAt: Value(_monthDate(now, -3, 1)),
              updatedAt: Value(now),
            ),
          );
    }

    final nubank = await addCard(
      name: 'Nubank',
      bankName: 'Nubank',
      lastDigits: '1234',
      brand: 'mastercard',
      limit: 500000,
      accountId: accounts.nubank,
      closingDay: 8,
      dueDay: 15,
      isPrimary: true,
      color: '#5B16D0',
    );
    final inter = await addCard(
      name: 'Inter',
      bankName: 'Banco Inter',
      lastDigits: '5678',
      brand: 'visa',
      limit: 350000,
      accountId: accounts.inter,
      closingDay: 12,
      dueDay: 20,
      isPrimary: false,
      color: '#F97316',
    );
    final santander = await addCard(
      name: 'Santander',
      bankName: 'Santander',
      lastDigits: '8899',
      brand: 'mastercard',
      limit: 280000,
      accountId: accounts.nubank,
      closingDay: 18,
      dueDay: 25,
      isPrimary: false,
      color: '#D71920',
    );

    return _DemoCards(
      nubankCard: _DemoCard(
        id: nubank,
        dueDay: 15,
        defaultPaymentAccountId: accounts.nubank,
      ),
      interCard: _DemoCard(
        id: inter,
        dueDay: 20,
        defaultPaymentAccountId: accounts.inter,
      ),
      santanderCard: _DemoCard(
        id: santander,
        dueDay: 25,
        defaultPaymentAccountId: accounts.nubank,
      ),
    );
  }

  Future<void> _seedMonthlyPlans({
    required int userId,
    required DateTime now,
    required _DemoAccounts accounts,
  }) async {
    for (var offset = -3; offset <= 0; offset++) {
      final month = _monthDate(now, offset, 1);
      await _database.into(_database.monthlyPlans).insert(
            MonthlyPlansCompanion.insert(
              userId: userId,
              month: month.month,
              year: month.year,
              plannedIncome: Value(965000 + (offset + 3) * 25000),
              plannedExpense: Value(720000 + (offset + 3) * 18000),
              initialMonthBalance: Value(950000 + (offset + 3) * 180000),
              createdAt: Value(month),
              updatedAt: Value(now),
            ),
          );
    }
  }

  Future<void> _seedTransactions({
    required int userId,
    required DateTime now,
    required _DemoAccounts accounts,
    required _DemoCards cards,
    required _DemoCategories categories,
  }) async {
    Future<void> addTransaction({
      required int accountId,
      required String categoryKey,
      required String description,
      required int amount,
      required DateTime date,
      required String type,
      String? subcategory,
      String? paymentMethod,
      int? creditCardId,
      DateTime? dueDate,
      int? invoiceMonth,
      int? invoiceYear,
      String? expenseKind,
      int? installmentNumber,
      int? totalInstallments,
      bool? isPaid,
      bool? isRecurring,
    }) async {
      await _database.into(_database.financialTransactions).insert(
            FinancialTransactionsCompanion.insert(
              userId: userId,
              accountId: accountId,
              creditCardId: Value(creditCardId),
              categoryId: categories.categoryId(categoryKey),
              subcategoryId: Value(
                subcategory == null
                    ? null
                    : categories.subcategoryId(categoryKey, subcategory),
              ),
              type: type,
              description: description,
              amount: amount,
              date: date,
              dueDate: Value(dueDate),
              paymentMethod: paymentMethod ?? 'account',
              invoiceMonth: Value(invoiceMonth),
              invoiceYear: Value(invoiceYear),
              expenseKind: Value(expenseKind ?? 'single'),
              installmentNumber: Value(installmentNumber),
              totalInstallments: Value(totalInstallments),
              isPaid: Value(isPaid ?? true),
              isRecurring: Value(isRecurring ?? false),
              createdAt: Value(date),
              updatedAt: Value(date),
            ),
          );
    }

    for (var offset = -3; offset <= 0; offset++) {
      final month = _monthDate(now, offset, 1);
      final isCurrentMonth = month.month == now.month && month.year == now.year;
      final salaryDate = _safeDate(month, 5);
      final salaryPaid = !isCurrentMonth || !salaryDate.isAfter(now);
      final freelanceDate = _safeDate(month, 15);
      final freelancePaid = !isCurrentMonth || !freelanceDate.isAfter(now);

      await addTransaction(
        accountId: accounts.nubank,
        categoryKey: 'salary',
        subcategory: 'CLT',
        description: 'Salário Tech Studio',
        amount: 785000,
        date: salaryDate,
        dueDate: salaryDate,
        type: 'income',
        isPaid: salaryPaid,
        isRecurring: true,
      );
      await addTransaction(
        accountId: accounts.inter,
        categoryKey: 'freelance',
        subcategory: 'Projeto',
        description: 'Freelance dashboard',
        amount: 145000 + (offset + 3) * 18000,
        date: freelanceDate,
        dueDate: freelanceDate,
        type: 'income',
        isPaid: freelancePaid,
      );
      await addTransaction(
        accountId: accounts.reserve,
        categoryKey: 'yield',
        subcategory: 'Juros',
        description: 'Rendimento reserva',
        amount: 1800 + (offset + 3) * 420,
        date: _safeDate(month, 28),
        type: 'income',
      );

      await addTransaction(
        accountId: accounts.nubank,
        categoryKey: 'housing',
        subcategory: 'Aluguel',
        description: 'Aluguel',
        amount: 165000,
        date: _safeDate(month, 1),
        dueDate: _safeDate(month, 1),
        type: 'expense',
        isRecurring: true,
      );
      await addTransaction(
        accountId: accounts.nubank,
        categoryKey: 'housing',
        subcategory: 'Condomínio',
        description: 'Condomínio',
        amount: 42000,
        date: _safeDate(month, 10),
        dueDate: _safeDate(month, 10),
        type: 'expense',
        isPaid: !isCurrentMonth || now.day >= 10,
        isRecurring: true,
      );
      await addTransaction(
        accountId: accounts.inter,
        categoryKey: 'housing',
        subcategory: 'Internet',
        description: 'Internet fibra',
        amount: 9990,
        date: _safeDate(month, 12),
        dueDate: _safeDate(month, 12),
        type: 'expense',
        isPaid: !isCurrentMonth || now.day >= 12,
        isRecurring: true,
      );
      await addTransaction(
        accountId: accounts.nubank,
        categoryKey: 'health',
        subcategory: 'Academia',
        description: 'Academia',
        amount: 8990,
        date: _safeDate(month, 7),
        dueDate: _safeDate(month, 7),
        type: 'expense',
        isPaid: !isCurrentMonth || now.day >= 7,
        isRecurring: true,
      );

      await addTransaction(
        accountId: accounts.nubank,
        categoryKey: 'food',
        subcategory: 'Mercado',
        description: 'Supermercado Pão de Açúcar',
        amount: 15680 + (offset + 3) * 940,
        date: isCurrentMonth ? _safeDate(month, 1) : _safeDate(month, 6),
        type: 'expense',
      );
      await addTransaction(
        accountId: accounts.inter,
        categoryKey: 'transport',
        subcategory: 'Combustível',
        description: 'Posto Ipiranga',
        amount: 12000 + (offset + 3) * 1100,
        date: isCurrentMonth ? _safeDate(month, 2) : _safeDate(month, 14),
        type: 'expense',
      );

      await _seedMonthlyCardPurchases(
        userId: userId,
        now: now,
        month: month,
        accounts: accounts,
        cards: cards,
        categories: categories,
        addTransaction: addTransaction,
      );
    }

    await _seedInstallments(
      now: now,
      userId: userId,
      accounts: accounts,
      cards: cards,
      categories: categories,
      addTransaction: addTransaction,
    );
  }

  Future<void> _seedMonthlyCardPurchases({
    required int userId,
    required DateTime now,
    required DateTime month,
    required _DemoAccounts accounts,
    required _DemoCards cards,
    required _DemoCategories categories,
    required Future<void> Function({
      required int accountId,
      required String categoryKey,
      required String description,
      required int amount,
      required DateTime date,
      required String type,
      String? subcategory,
      String? paymentMethod,
      int? creditCardId,
      DateTime? dueDate,
      int? invoiceMonth,
      int? invoiceYear,
      String? expenseKind,
      int? installmentNumber,
      int? totalInstallments,
      bool? isPaid,
      bool? isRecurring,
    }) addTransaction,
  }) async {
    final isCurrentMonth = month.month == now.month && month.year == now.year;
    final visibleDay = isCurrentMonth ? now.day.clamp(1, 2) : 18;

    Future<void> cardExpense({
      required int cardId,
      required int accountId,
      required String categoryKey,
      required String subcategory,
      required String description,
      required int amount,
      required int day,
      String expenseKind = 'single',
      bool isRecurring = false,
    }) {
      final date = _safeDate(
        month,
        isCurrentMonth ? day.clamp(1, visibleDay).toInt() : day,
      );
      return addTransaction(
        accountId: accountId,
        creditCardId: cardId,
        categoryKey: categoryKey,
        subcategory: subcategory,
        description: description,
        amount: amount,
        date: date,
        type: 'expense',
        paymentMethod: 'credit_card',
        invoiceMonth: month.month,
        invoiceYear: month.year,
        expenseKind: expenseKind,
        isRecurring: isRecurring,
      );
    }

    await cardExpense(
      cardId: cards.nubank,
      accountId: accounts.nubank,
      categoryKey: 'leisure',
      subcategory: 'Streaming',
      description: 'Netflix',
      amount: 5590,
      day: 3,
      expenseKind: 'fixed_monthly',
      isRecurring: true,
    );
    await cardExpense(
      cardId: cards.nubank,
      accountId: accounts.nubank,
      categoryKey: 'food',
      subcategory: 'Delivery',
      description: 'iFood',
      amount: 4890 + (month.month % 3) * 600,
      day: 11,
    );
    await cardExpense(
      cardId: cards.nubank,
      accountId: accounts.nubank,
      categoryKey: 'transport',
      subcategory: 'Aplicativo',
      description: 'Uber',
      amount: 3240 + (month.month % 2) * 450,
      day: 16,
    );
    await cardExpense(
      cardId: cards.inter,
      accountId: accounts.inter,
      categoryKey: 'shopping',
      subcategory: 'Casa',
      description: 'Amazon',
      amount: 12990 + (month.month % 4) * 800,
      day: 19,
    );
    await cardExpense(
      cardId: cards.santander,
      accountId: accounts.nubank,
      categoryKey: 'health',
      subcategory: 'Farmácia',
      description: 'Droga Raia',
      amount: 8990 + (month.month % 2) * 700,
      day: 21,
    );

    if (isCurrentMonth) {
      await cardExpense(
        cardId: cards.nubank,
        accountId: accounts.nubank,
        categoryKey: 'food',
        subcategory: 'Mercado',
        description: 'Mercado',
        amount: 15000,
        day: 1,
      );
      await cardExpense(
        cardId: cards.nubank,
        accountId: accounts.nubank,
        categoryKey: 'food',
        subcategory: 'Mercado',
        description: 'Arroz',
        amount: 3500,
        day: 2,
      );
    }
  }

  Future<void> _seedInstallments({
    required DateTime now,
    required int userId,
    required _DemoAccounts accounts,
    required _DemoCards cards,
    required _DemoCategories categories,
    required Future<void> Function({
      required int accountId,
      required String categoryKey,
      required String description,
      required int amount,
      required DateTime date,
      required String type,
      String? subcategory,
      String? paymentMethod,
      int? creditCardId,
      DateTime? dueDate,
      int? invoiceMonth,
      int? invoiceYear,
      String? expenseKind,
      int? installmentNumber,
      int? totalInstallments,
      bool? isPaid,
      bool? isRecurring,
    }) addTransaction,
  }) async {
    Future<void> installmentPurchase({
      required String description,
      required int cardId,
      required int accountId,
      required String categoryKey,
      required String subcategory,
      required int installmentAmount,
      required DateTime firstInvoiceMonth,
      required DateTime purchaseDate,
      required int totalInstallments,
    }) async {
      for (var index = 0; index < totalInstallments; index++) {
        final invoiceDate = DateTime(
          firstInvoiceMonth.year,
          firstInvoiceMonth.month + index,
        );
        await addTransaction(
          accountId: accountId,
          creditCardId: cardId,
          categoryKey: categoryKey,
          subcategory: subcategory,
          description: '$description (${index + 1}/$totalInstallments)',
          amount: installmentAmount,
          date: purchaseDate,
          type: 'expense',
          paymentMethod: 'credit_card',
          invoiceMonth: invoiceDate.month,
          invoiceYear: invoiceDate.year,
          expenseKind: 'installment',
          installmentNumber: index + 1,
          totalInstallments: totalInstallments,
        );
      }
    }

    await installmentPurchase(
      description: 'Notebook Dell',
      cardId: cards.nubank,
      accountId: accounts.nubank,
      categoryKey: 'shopping',
      subcategory: 'Eletrônicos',
      installmentAmount: 60000,
      firstInvoiceMonth: _monthDate(now, -3, 1),
      purchaseDate: _monthDate(now, -3, 6),
      totalInstallments: 6,
    );
    await installmentPurchase(
      description: 'Curso Flutter Pro',
      cardId: cards.inter,
      accountId: accounts.inter,
      categoryKey: 'education',
      subcategory: 'Cursos',
      installmentAmount: 30000,
      firstInvoiceMonth: _monthDate(now, -2, 1),
      purchaseDate: _monthDate(now, -2, 9),
      totalInstallments: 4,
    );
    await installmentPurchase(
      description: 'Geladeira',
      cardId: cards.santander,
      accountId: accounts.nubank,
      categoryKey: 'housing',
      subcategory: 'Casa',
      installmentAmount: 48000,
      firstInvoiceMonth: _monthDate(now, -1, 1),
      purchaseDate: _monthDate(now, -1, 20),
      totalInstallments: 5,
    );
  }

  Future<void> _seedTransfers({
    required int userId,
    required DateTime now,
    required _DemoAccounts accounts,
  }) async {
    for (var offset = -3; offset <= 0; offset++) {
      final month = _monthDate(now, offset, 1);
      final dueDate = _safeDate(month, 8);
      final isCurrentMonth = month.month == now.month && month.year == now.year;
      final isPaid = !isCurrentMonth || !dueDate.isAfter(now);

      await _database.into(_database.transfers).insert(
            TransfersCompanion.insert(
              userId: userId,
              fromAccountId: accounts.nubank,
              toAccountId: accounts.reserve,
              name: 'Reserva de emergência',
              amount: 80000 + (offset + 3) * 5000,
              transferKind: 'fixed_monthly',
              dueDate: dueDate,
              isPaid: Value(isPaid),
              installmentNumber: const Value(null),
              totalInstallments: const Value(null),
              date: dueDate,
              createdAt: Value(dueDate),
              updatedAt: Value(dueDate),
            ),
          );
    }

    for (var index = 0; index < 3; index++) {
      final date = _monthDate(now, -2 + index, 22);
      await _database.into(_database.transfers).insert(
            TransfersCompanion.insert(
              userId: userId,
              fromAccountId: accounts.inter,
              toAccountId: accounts.investments,
              name: 'Aporte corretora (${index + 1}/3)',
              amount: 120000,
              transferKind: 'installment',
              dueDate: date,
              isPaid: const Value(true),
              installmentNumber: Value(index + 1),
              totalInstallments: const Value(3),
              date: date,
              createdAt: Value(date),
              updatedAt: Value(date),
            ),
          );
    }
  }

  Future<void> _seedInvestments({
    required int userId,
    required DateTime now,
    required _DemoAccounts accounts,
  }) async {
    final investments = [
      ('Tesouro Selic', 'Renda fixa', 90000, _monthDate(now, -3, 10)),
      ('CDB liquidez diária', 'Renda fixa', 110000, _monthDate(now, -2, 10)),
      ('ETF Brasil', 'Renda variável', 85000, _monthDate(now, -1, 10)),
      (
        'Reserva remunerada',
        'Reserva',
        70000,
        _safeDate(_monthDate(now, 0, 1), 2)
      ),
    ];

    for (final investment in investments) {
      await _database.into(_database.investments).insert(
            InvestmentsCompanion.insert(
              userId: userId,
              accountId: accounts.investments,
              name: investment.$1,
              type: investment.$2,
              amount: investment.$3,
              date: investment.$4,
              createdAt: Value(investment.$4),
              updatedAt: Value(investment.$4),
            ),
          );
    }
  }

  Future<void> _seedPetProgress({
    required int userId,
    required DateTime now,
  }) {
    return _database.into(_database.petProgress).insert(
          PetProgressCompanion.insert(
            userId: userId,
            petName: 'Finny',
            level: const Value(4),
            xp: const Value(380),
            currentStage: const Value('guardian'),
            totalInvested: const Value(355000),
            lastEvolutionAt: Value(_monthDate(now, -1, 12)),
            createdAt: Value(_monthDate(now, -3, 1)),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> _seedBackupLog({
    required int userId,
    required DateTime now,
  }) {
    return _database.into(_database.backupLogs).insert(
          BackupLogsCompanion.insert(
            userId: userId,
            backupType: 'manual',
            provider: 'local',
            status: 'success',
            filePath: const Value('finest_demo_backup.sqlite'),
            createdAt: Value(_monthDate(now, -1, 28)),
          ),
        );
  }

  Future<void> _rebuildCreditCardInvoices({
    required int userId,
    required _DemoCards cards,
    required _DemoAccounts accounts,
    required DateTime now,
  }) async {
    final transactions =
        await (_database.select(_database.financialTransactions)
              ..where((table) =>
                  table.userId.equals(userId) &
                  table.paymentMethod.equals('credit_card') &
                  table.creditCardId.isNotNull()))
            .get();
    final totals = <_InvoiceKey, int>{};

    for (final transaction in transactions) {
      final cardId = transaction.creditCardId;
      final month = transaction.invoiceMonth;
      final year = transaction.invoiceYear;
      if (cardId == null || month == null || year == null) {
        continue;
      }

      final key = _InvoiceKey(cardId: cardId, month: month, year: year);
      totals[key] = (totals[key] ?? 0) + transaction.amount;
    }

    for (final entry in totals.entries) {
      final card = cards.byId(entry.key.cardId);
      final dueDate = _safeDate(
        DateTime(entry.key.year, entry.key.month),
        card.dueDay,
      );
      final isPastInvoice = DateTime(entry.key.year, entry.key.month)
          .isBefore(DateTime(now.year, now.month));
      await _database.into(_database.creditCardInvoices).insert(
            CreditCardInvoicesCompanion.insert(
              userId: userId,
              creditCardId: entry.key.cardId,
              month: entry.key.month,
              year: entry.key.year,
              amount: Value(entry.value),
              status: Value(isPastInvoice ? 'paid' : 'open'),
              dueDate: dueDate,
              paymentAccountId: Value(card.defaultPaymentAccountId),
              paidAt: Value(
                  isPastInvoice ? dueDate.add(const Duration(days: 1)) : null),
              createdAt: Value(dueDate),
              updatedAt: Value(now),
            ),
          );
    }

    for (final card in cards.all) {
      final currentInvoice = totals[_InvoiceKey(
            cardId: card.id,
            month: now.month,
            year: now.year,
          )] ??
          0;
      await (_database.update(_database.creditCards)
            ..where((table) => table.id.equals(card.id)))
          .write(
        CreditCardsCompanion(
          currentInvoice: Value(currentInvoice),
          updatedAt: Value(now),
        ),
      );
    }
  }

  DateTime _monthDate(DateTime now, int offset, int day) {
    return _safeDate(DateTime(now.year, now.month + offset), day);
  }

  DateTime _safeDate(DateTime month, int day) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, day.clamp(1, lastDay));
  }
}

final demoDataServiceProvider = Provider<DemoDataService>((ref) {
  return DemoDataService(ref.watch(appDatabaseProvider));
});

class _DemoCategories {
  final categoryIds = <String, int>{};
  final subcategoryIds = <String, int>{};

  int categoryId(String key) => categoryIds[key]!;

  int subcategoryId(String categoryKey, String subcategory) {
    return subcategoryIds['$categoryKey:$subcategory']!;
  }
}

class _DemoAccounts {
  const _DemoAccounts({
    required this.nubank,
    required this.inter,
    required this.reserve,
    required this.investments,
  });

  final int nubank;
  final int inter;
  final int reserve;
  final int investments;
}

class _DemoCard {
  const _DemoCard({
    required this.id,
    required this.dueDay,
    required this.defaultPaymentAccountId,
  });

  final int id;
  final int dueDay;
  final int defaultPaymentAccountId;
}

class _DemoCards {
  const _DemoCards({
    required this.nubankCard,
    required this.interCard,
    required this.santanderCard,
  });

  final _DemoCard nubankCard;
  final _DemoCard interCard;
  final _DemoCard santanderCard;

  int get nubank => nubankCard.id;
  int get inter => interCard.id;
  int get santander => santanderCard.id;

  List<_DemoCard> get all => [nubankCard, interCard, santanderCard];

  _DemoCard byId(int id) {
    return all.firstWhere(
      (card) => card.id == id,
      orElse: () => nubankCard,
    );
  }
}

class _InvoiceKey {
  const _InvoiceKey({
    required this.cardId,
    required this.month,
    required this.year,
  });

  final int cardId;
  final int month;
  final int year;

  @override
  bool operator ==(Object other) {
    return other is _InvoiceKey &&
        other.cardId == cardId &&
        other.month == month &&
        other.year == year;
  }

  @override
  int get hashCode => Object.hash(cardId, month, year);
}
