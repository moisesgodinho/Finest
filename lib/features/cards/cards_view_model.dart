import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_credit_card_request.dart';
import '../../data/models/credit_card_preview.dart';
import '../../data/models/update_credit_card_request.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/credit_card_repository.dart';

class CardsState {
  const CardsState({
    required this.cards,
    required this.accounts,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<CreditCardPreview> cards;
  final List<AccountPreview> accounts;
  final bool isLoading;
  final String? errorMessage;

  CreditCardPreview? get primaryCard {
    for (final card in cards) {
      if (card.isPrimary) {
        return card;
      }
    }
    return cards.isEmpty ? null : cards.first;
  }

  int get totalInvoicesCents {
    return cards.fold<int>(0, (total, card) => total + card.invoiceCents);
  }

  int get availableLimitCents {
    return cards.fold<int>(
      0,
      (total, card) => total + (card.limitCents - card.invoiceCents),
    );
  }

  CardsState copyWith({
    List<CreditCardPreview>? cards,
    List<AccountPreview>? accounts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CardsState(
      cards: cards ?? this.cards,
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CardsViewModel extends StateNotifier<CardsState> {
  CardsViewModel({
    required int? userId,
    required AccountRepository accountRepository,
    required CreditCardRepository creditCardRepository,
  })  : _userId = userId,
        _accountRepository = accountRepository,
        _creditCardRepository = creditCardRepository,
        super(
          const CardsState(
            cards: [],
            accounts: [],
            isLoading: true,
          ),
        ) {
    _watchData();
  }

  final int? _userId;
  final AccountRepository _accountRepository;
  final CreditCardRepository _creditCardRepository;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<List<CreditCard>>? _cardsSubscription;
  List<Account> _accounts = [];
  List<CreditCard> _cards = [];

  Future<void> createCard({
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
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.createCard(
        CreateCreditCardRequest(
          userId: userId,
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
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateCard({
    required CreditCardPreview card,
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
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.updateCard(
        UpdateCreditCardRequest(
          id: card.id,
          userId: userId,
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
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> deleteCard(CreditCardPreview card) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.deleteCard(
        userId: userId,
        cardId: card.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> payCurrentInvoice(CreditCardPreview card) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _creditCardRepository.payCurrentInvoice(
        userId: userId,
        cardId: card.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  void _watchData() {
    final userId = _userId;
    if (userId == null) {
      state = const CardsState(cards: [], accounts: []);
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(userId).listen(
      (accounts) {
        _accounts = accounts;
        _publishState();
      },
      onError: _handleStreamError,
    );

    _cardsSubscription = _creditCardRepository.watchCards(userId).listen(
      (cards) {
        _cards = cards;
        _publishState();
      },
      onError: _handleStreamError,
    );
  }

  void _publishState() {
    final accountsById = {for (final account in _accounts) account.id: account};

    state = state.copyWith(
      accounts: _accounts.map(_mapAccount).toList(),
      cards: [
        for (final card in _cards) _mapCard(card, accountsById),
      ],
      isLoading: false,
      clearError: true,
    );
  }

  void _handleStreamError(Object error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: error.toString(),
    );
  }

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      balanceCents: account.currentBalance,
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  CreditCardPreview _mapCard(
    CreditCard card,
    Map<int, Account> accountsById,
  ) {
    final defaultAccount = accountsById[card.defaultPaymentAccountId];
    final usedPercent =
        card.limit == 0 ? 0.0 : card.currentInvoice / card.limit;

    return CreditCardPreview(
      id: card.id,
      name: card.name,
      bankName: card.bankName,
      lastDigits: card.lastDigits,
      brand: card.brand,
      brandLabel: _brandLabel(card.brand),
      invoiceCents: card.currentInvoice,
      limitCents: card.limit,
      usedPercent: usedPercent.clamp(0.0, 1.0).toDouble(),
      color: _parseColor(card.color),
      colorHex: card.color,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
      isPrimary: card.isPrimary,
      defaultPaymentAccountId: card.defaultPaymentAccountId,
      defaultPaymentAccountName: defaultAccount?.name,
    );
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
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _cardsSubscription?.cancel();
    super.dispose();
  }
}

final cardsViewModelProvider =
    StateNotifierProvider<CardsViewModel, CardsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return CardsViewModel(
    userId: userId,
    accountRepository: ref.watch(accountRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
  );
});
