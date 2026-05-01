import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/credit_cards_table.dart';

part 'credit_cards_dao.g.dart';

@DriftAccessor(tables: [CreditCards])
class CreditCardsDao extends DatabaseAccessor<AppDatabase>
    with _$CreditCardsDaoMixin {
  CreditCardsDao(super.db);

  Stream<List<CreditCard>> watchByUser(int userId) {
    final query = select(creditCards)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm(
              expression: table.isPrimary,
              mode: OrderingMode.desc,
            ),
        (table) => OrderingTerm(expression: table.name),
      ]);

    return query.watch();
  }

  Future<List<CreditCard>> findByUser(int userId) {
    final query = select(creditCards)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm(
              expression: table.isPrimary,
              mode: OrderingMode.desc,
            ),
        (table) => OrderingTerm(expression: table.name),
      ]);

    return query.get();
  }

  Future<CreditCard?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(creditCards)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> countByUser(int userId) {
    final countExpression = creditCards.id.count();
    final query = selectOnly(creditCards)
      ..addColumns([countExpression])
      ..where(creditCards.userId.equals(userId));

    return query.map((row) => row.read(countExpression) ?? 0).getSingle();
  }

  Future<int> insertCard(CreditCardsCompanion card) {
    return into(creditCards).insert(card);
  }

  Future<int> updateCard({
    required int id,
    required int userId,
    required CreditCardsCompanion card,
  }) {
    return (update(creditCards)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(card);
  }

  Future<int> updateCurrentInvoice({
    required int id,
    required int userId,
    required int currentInvoice,
  }) {
    return (update(creditCards)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(
      CreditCardsCompanion(
        currentInvoice: Value(currentInvoice),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> clearPrimaryCards(int userId) {
    return (update(creditCards)..where((table) => table.userId.equals(userId)))
        .write(
      CreditCardsCompanion(
        isPrimary: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteCard({
    required int id,
    required int userId,
  }) {
    return (delete(creditCards)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .go();
  }
}
