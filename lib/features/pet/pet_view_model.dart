import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/currency/exchange_rate_service.dart';
import '../../core/database/app_database.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/pet_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transfer_repository.dart';

class PetState {
  const PetState({
    this.petName = 'Finny',
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 500,
    this.currencyCode = 'BRL',
    this.totalInvestedCents = 0,
    this.monthlyContributionCents = 0,
    this.monthlyIncomeCents = 0,
    this.monthlyExpenseCents = 0,
    this.emergencyReserveCents = 0,
    this.trackedDays = 0,
    this.contributionStreakMonths = 0,
    this.highSavingsRateMonths = 0,
    this.savingsRate = 0,
    this.runwayMonths = 0,
    this.hasEarlyContributionBuff = false,
    this.lastEvolutionAt,
    this.evolutionEvents = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final String petName;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final String currencyCode;
  final int totalInvestedCents;
  final int monthlyContributionCents;
  final int monthlyIncomeCents;
  final int monthlyExpenseCents;
  final int emergencyReserveCents;
  final int trackedDays;
  final int contributionStreakMonths;
  final int highSavingsRateMonths;
  final double savingsRate;
  final double runwayMonths;
  final bool hasEarlyContributionBuff;
  final DateTime? lastEvolutionAt;
  final List<PetEvolutionEvent> evolutionEvents;
  final bool isLoading;
  final String? errorMessage;

  PetEvolutionLevel get currentLevel {
    return petEvolutionLevels.firstWhere(
      (stage) => stage.level == level,
      orElse: () => petEvolutionLevels.first,
    );
  }

  PetEvolutionLevel? get nextLevel {
    if (level >= petEvolutionLevels.length) {
      return null;
    }
    return petEvolutionLevels.firstWhere((stage) => stage.level == level + 1);
  }

  double get progressToNextLevel {
    if (xpToNextLevel <= 0) {
      return 0;
    }
    return (xp / xpToNextLevel).clamp(0.0, 1.0).toDouble();
  }

  int get remainingXp => (xpToNextLevel - xp).clamp(0, xpToNextLevel);

  double get trackingProgress => (trackedDays / 15).clamp(0.0, 1.0).toDouble();

  double get consistencyProgress {
    return (contributionStreakMonths / 3).clamp(0.0, 1.0).toDouble();
  }

  double get runwayProgress => (runwayMonths / 1).clamp(0.0, 1.0).toDouble();

  double get energyProgress => (savingsRate / 0.10).clamp(0.0, 1.0).toDouble();

  int get suggestedContributionTargetCents =>
      (monthlyIncomeCents * 0.10).round();

  double get contributionTargetProgress {
    if (suggestedContributionTargetCents <= 0) {
      return 0;
    }
    return (monthlyContributionCents / suggestedContributionTargetCents)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  PetState copyWith({
    String? petName,
    int? level,
    int? xp,
    int? xpToNextLevel,
    String? currencyCode,
    int? totalInvestedCents,
    int? monthlyContributionCents,
    int? monthlyIncomeCents,
    int? monthlyExpenseCents,
    int? emergencyReserveCents,
    int? trackedDays,
    int? contributionStreakMonths,
    int? highSavingsRateMonths,
    double? savingsRate,
    double? runwayMonths,
    bool? hasEarlyContributionBuff,
    DateTime? lastEvolutionAt,
    List<PetEvolutionEvent>? evolutionEvents,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PetState(
      petName: petName ?? this.petName,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      currencyCode: currencyCode ?? this.currencyCode,
      totalInvestedCents: totalInvestedCents ?? this.totalInvestedCents,
      monthlyContributionCents:
          monthlyContributionCents ?? this.monthlyContributionCents,
      monthlyIncomeCents: monthlyIncomeCents ?? this.monthlyIncomeCents,
      monthlyExpenseCents: monthlyExpenseCents ?? this.monthlyExpenseCents,
      emergencyReserveCents:
          emergencyReserveCents ?? this.emergencyReserveCents,
      trackedDays: trackedDays ?? this.trackedDays,
      contributionStreakMonths:
          contributionStreakMonths ?? this.contributionStreakMonths,
      highSavingsRateMonths:
          highSavingsRateMonths ?? this.highSavingsRateMonths,
      savingsRate: savingsRate ?? this.savingsRate,
      runwayMonths: runwayMonths ?? this.runwayMonths,
      hasEarlyContributionBuff:
          hasEarlyContributionBuff ?? this.hasEarlyContributionBuff,
      lastEvolutionAt: lastEvolutionAt ?? this.lastEvolutionAt,
      evolutionEvents: evolutionEvents ?? this.evolutionEvents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PetEvolutionLevel {
  const PetEvolutionLevel({
    required this.level,
    required this.title,
    required this.trigger,
    required this.visual,
    required this.concept,
  });

  final int level;
  final String title;
  final String trigger;
  final String visual;
  final String concept;
}

class PetMechanic {
  const PetMechanic({
    required this.title,
    required this.gameFunction,
    required this.financialMeaning,
  });

  final String title;
  final String gameFunction;
  final String financialMeaning;
}

class PetViewModel extends StateNotifier<PetState> {
  PetViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
    required TransferRepository transferRepository,
    required PetRepository petRepository,
    required ExchangeRateService exchangeRateService,
    required String currencyCode,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _transactionRepository = transactionRepository,
        _transferRepository = transferRepository,
        _petRepository = petRepository,
        _exchangeRateService = exchangeRateService,
        _currencyCode = currencyCode,
        super(PetState(currencyCode: currencyCode, isLoading: true)) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final TransferRepository _transferRepository;
  final PetRepository _petRepository;
  final ExchangeRateService _exchangeRateService;
  final String _currencyCode;

  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<FinanceTransaction>>? _transactionsSubscription;
  StreamSubscription<List<AccountTransfer>>? _transfersSubscription;
  StreamSubscription<List<Investment>>? _investmentsSubscription;
  StreamSubscription<PetProgressData?>? _progressSubscription;
  StreamSubscription<List<PetEvolutionEvent>>? _evolutionEventsSubscription;

  List<Account> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  List<AccountTransfer> _transfers = [];
  List<Investment> _investments = [];
  List<PetEvolutionEvent> _evolutionEvents = [];
  PetProgressData? _progress;
  bool _isSavingProgress = false;
  String? _lastSyncedProgressSignature;
  int? _lastSyncedLevel;
  int? _lastSyncedXp;
  int? _lastSyncedTotalInvestedCents;

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = PetState(currencyCode: _currencyCode);
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts;
        _publishState();
      },
      onError: _publishError,
    );
    _transactionsSubscription =
        _transactionRepository.watchTransactions(userId).listen(
      (transactions) {
        _transactions = transactions;
        _publishState();
      },
      onError: _publishError,
    );
    _transfersSubscription = _transferRepository.watchTransfers(userId).listen(
      (transfers) {
        _transfers = transfers;
        _publishState();
      },
      onError: _publishError,
    );
    _investmentsSubscription = _petRepository.watchInvestments(userId).listen(
      (investments) {
        _investments = investments;
        _publishState();
      },
      onError: _publishError,
    );
    _progressSubscription = _petRepository.watchProgress(userId).listen(
      (progress) {
        _progress = progress;
        _publishState();
      },
      onError: _publishError,
    );
    _evolutionEventsSubscription =
        _petRepository.watchEvolutionEvents(userId).listen(
      (events) {
        _evolutionEvents = events;
        _publishState();
      },
      onError: _publishError,
    );
  }

  Future<void> _publishState() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final ratesToBrl = await _exchangeRateService.ratesToBrlSnapshot();
    final metrics = _calculateMetrics(ratesToBrl);
    final level = _levelFor(metrics);
    final progressToNext = _progressToNextLevel(level, metrics);
    final xp = level >= 10
        ? 500
        : (progressToNext * 500).round().clamp(0, 500).toInt();
    final existingProgress = _progress;
    final evolvedAt = existingProgress != null && level > existingProgress.level
        ? DateTime.now()
        : existingProgress?.lastEvolutionAt;
    final petName = existingProgress?.petName ?? 'Finny';

    state = PetState(
      petName: petName,
      level: level,
      xp: xp,
      currencyCode: _currencyCode,
      totalInvestedCents: metrics.totalInvestedCents,
      monthlyContributionCents: metrics.monthlyContributionCents,
      monthlyIncomeCents: metrics.monthlyIncomeCents,
      monthlyExpenseCents: metrics.monthlyExpenseCents,
      emergencyReserveCents: metrics.emergencyReserveCents,
      trackedDays: metrics.trackedDays,
      contributionStreakMonths: metrics.contributionStreakMonths,
      highSavingsRateMonths: metrics.highSavingsRateMonths,
      savingsRate: metrics.savingsRate,
      runwayMonths: metrics.runwayMonths,
      hasEarlyContributionBuff: metrics.hasEarlyContributionBuff,
      lastEvolutionAt: evolvedAt,
      evolutionEvents: _evolutionEvents,
    );

    await _syncProgress(
      userId: userId,
      petName: petName,
      level: level,
      xp: xp,
      totalInvestedCents: metrics.totalInvestedCents,
      lastEvolutionAt: evolvedAt,
      metrics: metrics,
    );
  }

  _PetFinancialMetrics _calculateMetrics(Map<String, double> ratesToBrl) {
    final now = DateTime.now();
    final selectedMonth = DateTime(now.year, now.month);
    final investmentAccountIds = {
      for (final account in _accounts)
        if (_isInvestmentAccount(account)) account.id,
    };

    final investmentRowsTotal = _investments.fold<int>(
      0,
      (total, investment) =>
          total + _convertInvestmentAmount(investment, ratesToBrl),
    );
    final investmentAccountsTotal = _accounts.fold<int>(
      0,
      (total, account) => investmentAccountIds.contains(account.id)
          ? total + _convertAccountBalance(account, ratesToBrl)
          : total,
    );
    final monthlyContributionCents = _monthlyContributionFor(
      selectedMonth,
      investmentAccountIds,
      ratesToBrl,
    );
    final monthlyIncomeCents = _monthlyIncomeFor(selectedMonth, ratesToBrl);
    final monthlyExpenseCents = _monthlyExpenseFor(selectedMonth, ratesToBrl);
    final monthlySavingsCents = math.max(
        monthlyContributionCents, monthlyIncomeCents - monthlyExpenseCents);
    final savingsRate = monthlyIncomeCents <= 0
        ? 0.0
        : (monthlySavingsCents / monthlyIncomeCents).clamp(0.0, 1.0).toDouble();
    final averageExpenseCents = _averageMonthlyExpense(ratesToBrl);
    final emergencyReserveCents = _emergencyReserveBalance(ratesToBrl);
    final runwayMonths = averageExpenseCents <= 0
        ? 0.0
        : emergencyReserveCents / averageExpenseCents;

    return _PetFinancialMetrics(
      totalInvestedCents:
          math.max(investmentRowsTotal, investmentAccountsTotal),
      monthlyContributionCents: monthlyContributionCents,
      monthlyIncomeCents: monthlyIncomeCents,
      monthlyExpenseCents: monthlyExpenseCents,
      emergencyReserveCents: emergencyReserveCents,
      trackedDays: _expenseTrackingStreakDays(),
      contributionStreakMonths:
          _contributionStreakMonths(investmentAccountIds, ratesToBrl),
      highSavingsRateMonths: _highSavingsRateMonths(ratesToBrl),
      savingsRate: savingsRate,
      runwayMonths: runwayMonths,
      hasEarlyContributionBuff: _hasEarlyContributionBuff(
        selectedMonth,
        investmentAccountIds,
      ),
    );
  }

  int _levelFor(_PetFinancialMetrics metrics) {
    var level = 1;
    if (metrics.monthlyContributionCents > 0 || metrics.savingsRate > 0) {
      level = 2;
    }
    if (metrics.runwayMonths >= 1) {
      level = 3;
    }
    if (metrics.contributionStreakMonths >= 3) {
      level = 4;
    }
    if (metrics.savingsRate >= 0.10) {
      level = 5;
    }
    if (metrics.runwayMonths >= 3) {
      level = 6;
    }
    if (metrics.contributionStreakMonths >= 6) {
      level = 7;
    }
    if (metrics.highSavingsRateMonths >= 2) {
      level = 8;
    }
    if (metrics.runwayMonths >= 6) {
      level = 9;
    }
    if (metrics.contributionStreakMonths >= 12 && metrics.savingsRate >= 0.15) {
      level = 10;
    }
    return level;
  }

  double _progressToNextLevel(int level, _PetFinancialMetrics metrics) {
    return switch (level + 1) {
      2 => math.max(
          metrics.monthlyContributionCents > 0 ? 1.0 : 0.0,
          metrics.savingsRate.clamp(0.0, 0.05) / 0.05,
        ),
      3 => (metrics.runwayMonths / 1).clamp(0.0, 1.0).toDouble(),
      4 => (metrics.contributionStreakMonths / 3).clamp(0.0, 1.0).toDouble(),
      5 => (metrics.savingsRate / 0.10).clamp(0.0, 1.0).toDouble(),
      6 => (metrics.runwayMonths / 3).clamp(0.0, 1.0).toDouble(),
      7 => (metrics.contributionStreakMonths / 6).clamp(0.0, 1.0).toDouble(),
      8 => (metrics.highSavingsRateMonths / 2).clamp(0.0, 1.0).toDouble(),
      9 => (metrics.runwayMonths / 6).clamp(0.0, 1.0).toDouble(),
      10 => math.min(
          (metrics.contributionStreakMonths / 12).clamp(0.0, 1.0).toDouble(),
          (metrics.savingsRate / 0.15).clamp(0.0, 1.0).toDouble(),
        ),
      _ => 1.0,
    };
  }

  Future<void> _syncProgress({
    required int userId,
    required String petName,
    required int level,
    required int xp,
    required int totalInvestedCents,
    required DateTime? lastEvolutionAt,
    required _PetFinancialMetrics metrics,
  }) async {
    if (_isSavingProgress) {
      return;
    }
    final existing = _progress;
    final currentStage = _stageKeyFor(level);
    if (_lastSyncedLevel == level &&
        _lastSyncedXp == xp &&
        _lastSyncedTotalInvestedCents == totalInvestedCents &&
        (existing == null || existing.level != level)) {
      return;
    }
    final progressSignature = [
      userId,
      petName,
      level,
      xp,
      currentStage,
      totalInvestedCents,
      lastEvolutionAt?.toIso8601String(),
    ].join('|');
    if (_lastSyncedProgressSignature == progressSignature) {
      return;
    }
    if (existing != null &&
        existing.petName == petName &&
        existing.level == level &&
        existing.xp == xp &&
        existing.currentStage == currentStage &&
        existing.totalInvested == totalInvestedCents &&
        existing.lastEvolutionAt == lastEvolutionAt) {
      _lastSyncedProgressSignature = progressSignature;
      _lastSyncedLevel = level;
      _lastSyncedXp = xp;
      _lastSyncedTotalInvestedCents = totalInvestedCents;
      return;
    }

    _isSavingProgress = true;
    try {
      final shouldLogEvolution =
          existing == null ? level > 1 : level > existing.level;
      await _petRepository.saveProgress(
        PetProgressUpdate(
          userId: userId,
          petName: petName,
          level: level,
          xp: xp,
          currentStage: currentStage,
          totalInvestedCents: totalInvestedCents,
          lastEvolutionAt: lastEvolutionAt,
        ),
      );
      if (shouldLogEvolution) {
        await _petRepository.saveEvolutionEvent(
          PetEvolutionEventInput(
            userId: userId,
            fromLevel: existing?.level,
            toLevel: level,
            xp: xp,
            stage: currentStage,
            reason: _reasonForLevel(level),
            totalInvestedCents: metrics.totalInvestedCents,
            monthlyContributionCents: metrics.monthlyContributionCents,
            savingsRate: metrics.savingsRate,
            runwayMonths: metrics.runwayMonths,
            contributionStreakMonths: metrics.contributionStreakMonths,
          ),
        );
      }
      _lastSyncedProgressSignature = progressSignature;
      _lastSyncedLevel = level;
      _lastSyncedXp = xp;
      _lastSyncedTotalInvestedCents = totalInvestedCents;
    } finally {
      _isSavingProgress = false;
    }
  }

  int _monthlyContributionFor(
    DateTime month,
    Set<int> investmentAccountIds,
    Map<String, double> ratesToBrl,
  ) {
    final investmentsTotal = _investments
        .where((investment) => _sameMonth(investment.date, month))
        .fold<int>(
          0,
          (total, investment) =>
              total + _convertInvestmentAmount(investment, ratesToBrl),
        );

    final transfersTotal = _transfers
        .where((transfer) =>
            transfer.isPaid &&
            investmentAccountIds.contains(transfer.toAccountId) &&
            !investmentAccountIds.contains(transfer.fromAccountId) &&
            _sameMonth(transfer.date, month))
        .fold<int>(
          0,
          (total, transfer) =>
              total + _convertTransferDestinationAmount(transfer, ratesToBrl),
        );

    return investmentsTotal + transfersTotal;
  }

  int _monthlyIncomeFor(DateTime month, Map<String, double> ratesToBrl) {
    return _transactions
        .where((transaction) =>
            transaction.isPaid &&
            transaction.type == 'income' &&
            _sameMonth(_referenceDate(transaction), month))
        .fold<int>(
          0,
          (total, transaction) =>
              total + _convertTransactionAmount(transaction, ratesToBrl),
        );
  }

  int _monthlyExpenseFor(DateTime month, Map<String, double> ratesToBrl) {
    return _transactions
        .where((transaction) =>
            transaction.isPaid &&
            transaction.type == 'expense' &&
            _sameMonth(_referenceDate(transaction), month))
        .fold<int>(
          0,
          (total, transaction) =>
              total + _convertTransactionAmount(transaction, ratesToBrl),
        );
  }

  int _averageMonthlyExpense(Map<String, double> ratesToBrl) {
    final now = DateTime.now();
    final totalsByMonth = <int, int>{};
    final start = DateTime(now.year, now.month - 2);
    final end = DateTime(now.year, now.month + 1);

    for (final transaction in _transactions) {
      if (!transaction.isPaid || transaction.type != 'expense') {
        continue;
      }
      final date = _referenceDate(transaction);
      if (date.isBefore(start) || !date.isBefore(end)) {
        continue;
      }
      final key = date.year * 12 + date.month;
      totalsByMonth.update(
        key,
        (value) => value + _convertTransactionAmount(transaction, ratesToBrl),
        ifAbsent: () => _convertTransactionAmount(transaction, ratesToBrl),
      );
    }

    if (totalsByMonth.isEmpty) {
      return 0;
    }
    final total =
        totalsByMonth.values.fold<int>(0, (sum, value) => sum + value);
    return (total / totalsByMonth.length).round();
  }

  int _emergencyReserveBalance(Map<String, double> ratesToBrl) {
    return _accounts.fold<int>(0, (total, account) {
      if (!_isEmergencyReserveAccount(account)) {
        return total;
      }
      return total + _convertAccountBalance(account, ratesToBrl);
    });
  }

  int _expenseTrackingStreakDays() {
    final expenseDays = {
      for (final transaction in _transactions)
        if (transaction.type == 'expense') _dayKey(transaction.date),
    };
    final today = _dateOnly(DateTime.now());
    var cursor = expenseDays.contains(_dayKey(today))
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;

    while (expenseDays.contains(_dayKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
      if (streak >= 365) {
        break;
      }
    }
    return streak;
  }

  int _contributionStreakMonths(
    Set<int> investmentAccountIds,
    Map<String, double> ratesToBrl,
  ) {
    final now = DateTime.now();
    var streak = 0;

    for (var offset = 0; offset < 24; offset++) {
      final month = DateTime(now.year, now.month - offset);
      final contribution = _monthlyContributionFor(
        month,
        investmentAccountIds,
        ratesToBrl,
      );
      final savings = _monthlyIncomeFor(month, ratesToBrl) -
          _monthlyExpenseFor(month, ratesToBrl);
      if (contribution <= 0 && savings <= 0) {
        break;
      }
      streak += 1;
    }
    return streak;
  }

  int _highSavingsRateMonths(Map<String, double> ratesToBrl) {
    final now = DateTime.now();
    var count = 0;

    for (var offset = 0; offset < 2; offset++) {
      final month = DateTime(now.year, now.month - offset);
      final income = _monthlyIncomeFor(month, ratesToBrl);
      final expense = _monthlyExpenseFor(month, ratesToBrl);
      if (income <= 0) {
        continue;
      }
      final rate = ((income - expense) / income).clamp(0.0, 1.0);
      if (rate >= 0.20) {
        count += 1;
      }
    }
    return count;
  }

  bool _hasEarlyContributionBuff(
    DateTime month,
    Set<int> investmentAccountIds,
  ) {
    final investmentDates = [
      for (final investment in _investments)
        if (_sameMonth(investment.date, month)) investment.date,
      for (final transfer in _transfers)
        if (transfer.isPaid &&
            investmentAccountIds.contains(transfer.toAccountId) &&
            !investmentAccountIds.contains(transfer.fromAccountId) &&
            _sameMonth(transfer.date, month))
          transfer.date,
    ];

    if (investmentDates.isEmpty) {
      return false;
    }
    investmentDates.sort();
    return investmentDates.first.day <= 10;
  }

  bool _isInvestmentAccount(Account account) {
    final value = '${account.name} ${account.type}'.toLowerCase();
    return value.contains('invest') || value.contains('corretora');
  }

  bool _isEmergencyReserveAccount(Account account) {
    final value = '${account.name} ${account.type}'.toLowerCase();
    return account.emergencyReserveTarget != null ||
        value.contains('reserva') ||
        value.contains('emerg');
  }

  DateTime _referenceDate(FinanceTransaction transaction) {
    if (transaction.paymentMethod == 'credit_card' &&
        transaction.invoiceMonth != null &&
        transaction.invoiceYear != null) {
      return DateTime(transaction.invoiceYear!, transaction.invoiceMonth!);
    }
    return transaction.dueDate ?? transaction.date;
  }

  int _convertInvestmentAmount(
    Investment investment,
    Map<String, double> ratesToBrl,
  ) {
    final account = _accounts
        .where((account) => account.id == investment.accountId)
        .firstOrNull;
    return _exchangeRateService.convertCentsWithRates(
      amountCents: investment.amount,
      fromCurrency: account?.currencyCode ?? 'BRL',
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  int _convertAccountBalance(Account account, Map<String, double> ratesToBrl) {
    return _exchangeRateService.convertCentsWithRates(
      amountCents: account.currentBalance,
      fromCurrency: account.currencyCode,
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  int _convertTransactionAmount(
    FinanceTransaction transaction,
    Map<String, double> ratesToBrl,
  ) {
    return _exchangeRateService.convertCentsWithRates(
      amountCents: transaction.amount,
      fromCurrency: transaction.currencyCode,
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  int _convertTransferDestinationAmount(
    AccountTransfer transfer,
    Map<String, double> ratesToBrl,
  ) {
    return _exchangeRateService.convertCentsWithRates(
      amountCents: transfer.convertedAmount ?? transfer.amount,
      fromCurrency: transfer.toCurrencyCode,
      toCurrency: _currencyCode,
      ratesToBrl: ratesToBrl,
    );
  }

  bool _sameMonth(DateTime left, DateTime right) {
    return left.month == right.month && left.year == right.year;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dayKey(DateTime date) {
    final normalized = _dateOnly(date);
    return '${normalized.year}-${normalized.month}-${normalized.day}';
  }

  String _stageKeyFor(int level) {
    return switch (level) {
      1 => 'awakened',
      2 => 'saver',
      3 => 'survivor',
      4 => 'guardian',
      5 => 'athlete',
      6 => 'builder',
      7 => 'strategist',
      8 => 'optimizer',
      9 => 'security_baron',
      _ => 'eternal',
    };
  }

  String _reasonForLevel(int level) {
    return petEvolutionLevels
        .firstWhere(
          (stage) => stage.level == level,
          orElse: () => petEvolutionLevels.first,
        )
        .trigger;
  }

  void _publishError(Object error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: error.toString().replaceFirst('Exception: ', ''),
    );
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _transfersSubscription?.cancel();
    _investmentsSubscription?.cancel();
    _progressSubscription?.cancel();
    _evolutionEventsSubscription?.cancel();
    super.dispose();
  }
}

class _PetFinancialMetrics {
  const _PetFinancialMetrics({
    required this.totalInvestedCents,
    required this.monthlyContributionCents,
    required this.monthlyIncomeCents,
    required this.monthlyExpenseCents,
    required this.emergencyReserveCents,
    required this.trackedDays,
    required this.contributionStreakMonths,
    required this.highSavingsRateMonths,
    required this.savingsRate,
    required this.runwayMonths,
    required this.hasEarlyContributionBuff,
  });

  final int totalInvestedCents;
  final int monthlyContributionCents;
  final int monthlyIncomeCents;
  final int monthlyExpenseCents;
  final int emergencyReserveCents;
  final int trackedDays;
  final int contributionStreakMonths;
  final int highSavingsRateMonths;
  final double savingsRate;
  final double runwayMonths;
  final bool hasEarlyContributionBuff;
}

final petViewModelProvider = StateNotifierProvider<PetViewModel, PetState>((
  ref,
) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return PetViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
    petRepository: ref.watch(petRepositoryProvider),
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    currencyCode: ref.watch(currencyControllerProvider),
  );
});

const petEvolutionLevels = [
  PetEvolutionLevel(
    level: 1,
    title: 'O Desperto',
    trigger: 'Registrar despesas por 15 dias seguidos.',
    visual: 'O ovo começa a rachar e ganha olhinhos.',
    concept: 'O primeiro passo é saber para onde o dinheiro vai.',
  ),
  PetEvolutionLevel(
    level: 2,
    title: 'O Poupador Iniciante',
    trigger: 'Fechar o mês economizando qualquer valor ou fazer um aporte.',
    visual: 'O bichinho nasce pequeno e desajeitado.',
    concept: 'Romper a inércia e começar o hábito.',
  ),
  PetEvolutionLevel(
    level: 3,
    title: 'O Sobrevivente',
    trigger: 'Acumular 1 mês de custo de vida em reserva.',
    visual: 'Ele ganha uma mochila de provisões.',
    concept: 'Garantir os primeiros 30 dias de segurança.',
  ),
  PetEvolutionLevel(
    level: 4,
    title: 'O Guardião da Rotina',
    trigger: 'Poupar ou investir por 3 meses consecutivos.',
    visual: 'Ele ganha um escudo ou aura de proteção.',
    concept: 'Premiar repetição do hábito, não valor alto.',
  ),
  PetEvolutionLevel(
    level: 5,
    title: 'O Atleta Financeiro',
    trigger: 'Economizar 10% ou mais da renda mensal.',
    visual: 'Ele fica mais atlético e ativo.',
    concept: 'Subir o nível de esforço e otimização.',
  ),
  PetEvolutionLevel(
    level: 6,
    title: 'O Construtor',
    trigger: 'Acumular 3 meses de custo de vida.',
    visual: 'O cenário evolui para uma pequena cabana.',
    concept: 'Construir segurança intermediária.',
  ),
  PetEvolutionLevel(
    level: 7,
    title: 'O Estrategista',
    trigger: 'Manter 6 meses seguidos de aportes.',
    visual: 'Ele ganha acessórios de mestre.',
    concept: 'Transformar investimento em processo automático.',
  ),
  PetEvolutionLevel(
    level: 8,
    title: 'O Caçador de Eficiência',
    trigger: 'Economizar 20% ou mais da renda por 2 meses.',
    visual: 'Ele ganha itens de alta performance.',
    concept: 'Viver bem usando menos do que ganha.',
  ),
  PetEvolutionLevel(
    level: 9,
    title: 'O Barão da Segurança',
    trigger: 'Acumular 6 meses de custo de vida.',
    visual: 'A cabana vira um castelo.',
    concept: 'Paz de espírito para enfrentar crises.',
  ),
  PetEvolutionLevel(
    level: 10,
    title: 'O Eterno',
    trigger: 'Manter 12 meses de consistência e taxa acima de 15%.',
    visual: 'Ele se torna guardião do ecossistema.',
    concept: 'O hábito está enraizado no dia a dia.',
  ),
];

const petMechanics = [
  PetMechanic(
    title: 'Comida',
    gameFunction: 'Aporte mensal',
    financialMeaning: 'Colocar dinheiro em qualquer investimento.',
  ),
  PetMechanic(
    title: 'Higiene',
    gameFunction: 'Registro de gastos',
    financialMeaning: 'Limpar gastos esquecidos e manter clareza.',
  ),
  PetMechanic(
    title: 'Energia',
    gameFunction: 'Taxa de poupança',
    financialMeaning: 'Quanto maior a taxa, mais rápido ele evolui.',
  ),
  PetMechanic(
    title: 'Saúde',
    gameFunction: 'Uso da reserva',
    financialMeaning: 'Saques de emergência reduzem acessórios futuros.',
  ),
];
