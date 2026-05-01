import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/credit_card_invoices_table.dart';

part 'credit_card_invoices_dao.g.dart';

@DriftAccessor(tables: [CreditCardInvoices])
class CreditCardInvoicesDao extends DatabaseAccessor<AppDatabase>
    with _$CreditCardInvoicesDaoMixin {
  CreditCardInvoicesDao(super.db);

  Stream<List<CreditCardInvoice>> watchByUser(int userId) {
    final query = select(creditCardInvoices)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm.desc(table.year),
        (table) => OrderingTerm.desc(table.month),
        (table) => OrderingTerm(expression: table.dueDate),
      ]);

    return query.watch();
  }

  Future<List<CreditCardInvoice>> findByUser(int userId) {
    final query = select(creditCardInvoices)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm.desc(table.year),
        (table) => OrderingTerm.desc(table.month),
        (table) => OrderingTerm(expression: table.dueDate),
      ]);

    return query.get();
  }

  Future<CreditCardInvoice?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(creditCardInvoices)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<CreditCardInvoice?> findByCardMonth({
    required int userId,
    required int creditCardId,
    required int month,
    required int year,
  }) {
    return (select(creditCardInvoices)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.creditCardId.equals(creditCardId) &
                table.month.equals(month) &
                table.year.equals(year),
          ))
        .getSingleOrNull();
  }

  Future<int> insertInvoice(CreditCardInvoicesCompanion invoice) {
    return into(creditCardInvoices).insert(invoice);
  }

  Future<int> updateInvoice({
    required int id,
    required int userId,
    required CreditCardInvoicesCompanion invoice,
  }) {
    return (update(creditCardInvoices)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(invoice);
  }

  Future<int> addToAmount({
    required int id,
    required int userId,
    required int amount,
  }) {
    return (update(creditCardInvoices)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(
      CreditCardInvoicesCompanion(
        amount: Value(amount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
