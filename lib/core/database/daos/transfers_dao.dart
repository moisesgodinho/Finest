import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transfers_table.dart';

part 'transfers_dao.g.dart';

@DriftAccessor(tables: [Transfers])
class TransfersDao extends DatabaseAccessor<AppDatabase>
    with _$TransfersDaoMixin {
  TransfersDao(super.db);

  Stream<List<AccountTransfer>> watchByUser(int userId) {
    final query = select(transfers)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.date)]);

    return query.watch();
  }

  Future<List<AccountTransfer>> findByUser(int userId) {
    final query = select(transfers)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.date)]);

    return query.get();
  }

  Future<AccountTransfer?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(transfers)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> insertTransfer(TransfersCompanion transfer) {
    return into(transfers).insert(transfer);
  }

  Future<int> updatePaymentStatus({
    required int id,
    required int userId,
    required bool isPaid,
  }) {
    return (update(transfers)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(
      TransfersCompanion(
        isPaid: Value(isPaid),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> updateTransfer({
    required int id,
    required int userId,
    required TransfersCompanion transfer,
  }) {
    return (update(transfers)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(transfer);
  }

  Future<int> deleteTransfer({
    required int id,
    required int userId,
  }) {
    return (delete(transfers)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .go();
  }
}
