import 'package:finance_pet/core/theme/app_theme.dart';
import 'package:finance_pet/data/models/account_preview.dart';
import 'package:finance_pet/data/models/category_model.dart';
import 'package:finance_pet/data/models/credit_card_invoice_preview.dart';
import 'package:finance_pet/data/models/credit_card_preview.dart';
import 'package:finance_pet/data/repositories/account_repository.dart';
import 'package:finance_pet/data/repositories/category_repository.dart';
import 'package:finance_pet/data/repositories/credit_card_repository.dart';
import 'package:finance_pet/data/repositories/transaction_repository.dart';
import 'package:finance_pet/features/cards/cards_page.dart';
import 'package:finance_pet/features/cards/cards_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza a pagina de cartoes com conteudo no mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsViewModelProvider.overrideWith((ref) {
            return _FakeCardsViewModel(_cardsState);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CardsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cartões'), findsWidgets);
    expect(find.text('Gastos por categoria'), findsOneWidget);
    expect(find.text('Registros da fatura'), findsOneWidget);
    // Layout exceptions fail the test automatically.
  });
}

const _card = CreditCardPreview(
  id: 1,
  name: 'Cartao Principal Muito Longo',
  lastDigits: '1234',
  brand: 'visa',
  brandLabel: 'Visa',
  invoiceCents: 185700,
  limitCents: 500000,
  usedPercent: 0.3714,
  color: Color(0xFF006B4F),
  colorHex: '#006B4F',
  closingDay: 8,
  dueDay: 15,
  isPrimary: true,
  defaultPaymentAccountId: 1,
  defaultPaymentAccountName: 'Conta Corrente Principal Muito Longa',
);

final _cardsState = CardsState(
  cards: const [_card],
  accounts: const [
    AccountPreview(
      id: 1,
      name: 'Conta Corrente Principal Muito Longa',
      type: 'checking',
      balanceCents: 1000000,
      color: Color(0xFF006B4F),
      colorHex: '#006B4F',
    ),
  ],
  invoices: [
    CreditCardInvoicePreview(
      id: 1,
      cardId: 1,
      cardName: _card.name,
      cardLastDigits: _card.lastDigits,
      month: DateTime.now().month,
      year: DateTime.now().year,
      amountCents: 185700,
      status: 'open',
      statusLabel: 'Aberta',
      dueDate: DateTime(DateTime.now().year, DateTime.now().month, 15),
      paymentAccountId: 1,
      paymentAccountName: 'Conta Corrente Principal Muito Longa',
      cardColor: Color(0xFF006B4F),
      transactions: [
        CreditCardInvoiceTransactionPreview(
          id: 1,
          description: 'Compra de teste',
          amountCents: 185700,
          date: _fixedDate,
          categoryId: 1,
          categoryName: 'Alimentação',
          type: 'expense',
        ),
      ],
    ),
  ],
  categories: const [
    CategoryModel(
      id: 1,
      name: 'Alimentação',
      type: 'expense',
      icon: Icons.restaurant_rounded,
      color: Color(0xFF006B4F),
      colorHex: '#006B4F',
    ),
  ],
  subcategories: const [],
);

final _fixedDate = DateTime(2026, 5);

class _FakeCardsViewModel extends CardsViewModel {
  _FakeCardsViewModel(CardsState initialState)
      : super(
          userId: null,
          accountRepository: _FakeAccountRepository(),
          categoryRepository: _FakeCategoryRepository(),
          creditCardRepository: _FakeCreditCardRepository(),
          transactionRepository: _FakeTransactionRepository(),
        ) {
    state = initialState;
  }
}

class _FakeAccountRepository implements AccountRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCreditCardRepository implements CreditCardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionRepository implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
