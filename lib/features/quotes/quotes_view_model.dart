import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/app_currency.dart';
import '../../core/currency/currency_controller.dart';
import '../../core/currency/exchange_rate_service.dart';
import '../../core/database/app_database.dart';

class QuoteItem {
  const QuoteItem({
    required this.currency,
    required this.rateToBrl,
    required this.rateToSelectedCurrency,
    required this.fetchedAt,
    required this.source,
  });

  final AppCurrency currency;
  final double rateToBrl;
  final double rateToSelectedCurrency;
  final DateTime fetchedAt;
  final String source;
}

class QuotesState {
  const QuotesState({
    required this.selectedCurrencyCode,
    this.quotes = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final String selectedCurrencyCode;
  final List<QuoteItem> quotes;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  DateTime? get lastFetchedAt {
    if (quotes.isEmpty) {
      return null;
    }

    return quotes
        .map((quote) => quote.fetchedAt)
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }

  QuotesState copyWith({
    String? selectedCurrencyCode,
    List<QuoteItem>? quotes,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return QuotesState(
      selectedCurrencyCode: selectedCurrencyCode ?? this.selectedCurrencyCode,
      quotes: quotes ?? this.quotes,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class QuotesViewModel extends StateNotifier<QuotesState> {
  QuotesViewModel({
    required ExchangeRateService exchangeRateService,
    required String selectedCurrencyCode,
  })  : _exchangeRateService = exchangeRateService,
        super(
          QuotesState(
            selectedCurrencyCode: selectedCurrencyCode,
            isLoading: true,
          ),
        ) {
    load();
  }

  final ExchangeRateService _exchangeRateService;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _exchangeRateService.refreshIfStale();
      await _loadLocalRates();
    } catch (error) {
      await _loadLocalRates(errorMessage: error.toString());
    }
  }

  Future<void> refreshNow() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      await _exchangeRateService.forceRefresh();
      await _loadLocalRates();
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _loadLocalRates({String? errorMessage}) async {
    final rates = await _exchangeRateService.latestStoredRatesToBrl();
    final selectedRateToBrl = _rateToBrl(
      state.selectedCurrencyCode,
      rates,
    );

    state = state.copyWith(
      quotes: [
        for (final currency in AppCurrencies.supported)
          if (currency.code != AppCurrencies.defaultCode)
            _mapQuote(
              currency: currency,
              rates: rates,
              selectedRateToBrl: selectedRateToBrl,
            ),
      ],
      isLoading: false,
      isRefreshing: false,
      errorMessage: errorMessage,
      clearError: errorMessage == null,
    );
  }

  QuoteItem _mapQuote({
    required AppCurrency currency,
    required List<ExchangeRate> rates,
    required double selectedRateToBrl,
  }) {
    final rate =
        rates.where((rate) => rate.baseCurrency == currency.code).firstOrNull;
    final rateToBrl = rate?.rate ?? 0.0;
    final rateToSelectedCurrency =
        selectedRateToBrl <= 0 ? 0.0 : rateToBrl / selectedRateToBrl;

    return QuoteItem(
      currency: currency,
      rateToBrl: rateToBrl,
      rateToSelectedCurrency: rateToSelectedCurrency,
      fetchedAt: rate?.fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: rate?.source ?? 'awesomeapi',
    );
  }

  double _rateToBrl(String currencyCode, List<ExchangeRate> rates) {
    final normalized = currencyCode.toUpperCase();
    if (normalized == AppCurrencies.defaultCode) {
      return 1;
    }

    return rates
            .where((rate) => rate.baseCurrency == normalized)
            .firstOrNull
            ?.rate ??
        0;
  }
}

final quotesViewModelProvider =
    StateNotifierProvider.autoDispose<QuotesViewModel, QuotesState>((ref) {
  return QuotesViewModel(
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
    selectedCurrencyCode: ref.watch(currencyControllerProvider),
  );
});
