import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/credit_card_preview.dart';

class CardsState {
  const CardsState({required this.cards});

  final List<CreditCardPreview> cards;

  int get totalInvoicesCents {
    return cards.fold<int>(0, (total, card) => total + card.invoiceCents);
  }

  int get availableLimitCents {
    return cards.fold<int>(
      0,
      (total, card) => total + (card.limitCents - card.invoiceCents),
    );
  }
}

class CardsViewModel extends StateNotifier<CardsState> {
  CardsViewModel()
      : super(
          const CardsState(
            cards: [
              CreditCardPreview(
                name: 'Nubank',
                lastDigits: '1234',
                invoiceCents: 125840,
                limitCents: 500000,
                usedPercent: 0.42,
                color: AppColors.purple,
                dueDay: 15,
              ),
              CreditCardPreview(
                name: 'Inter',
                lastDigits: '5678',
                invoiceCents: 72090,
                limitCents: 300000,
                usedPercent: 0.48,
                color: Colors.deepOrange,
                dueDay: 12,
              ),
              CreditCardPreview(
                name: 'Santander',
                lastDigits: '8899',
                invoiceCents: 45085,
                limitCents: 250000,
                usedPercent: 0.37,
                color: AppColors.danger,
                dueDay: 18,
              ),
            ],
          ),
        );
}

final cardsViewModelProvider =
    StateNotifierProvider<CardsViewModel, CardsState>((ref) {
  return CardsViewModel();
});
