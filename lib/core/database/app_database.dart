import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/accounts_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/credit_cards_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/users_dao.dart';
import 'tables/accounts_table.dart';
import 'tables/backup_logs_table.dart';
import 'tables/categories_table.dart';
import 'tables/credit_cards_table.dart';
import 'tables/investments_table.dart';
import 'tables/monthly_plans_table.dart';
import 'tables/pet_progress_table.dart';
import 'tables/transactions_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Accounts,
    CreditCards,
    Categories,
    FinancialTransactions,
    MonthlyPlans,
    Investments,
    PetProgress,
    BackupLogs,
  ],
  daos: [
    UsersDao,
    AccountsDao,
    CategoriesDao,
    CreditCardsDao,
    TransactionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(creditCards, creditCards.brand);
            await migrator.addColumn(
              creditCards,
              creditCards.currentInvoice,
            );
            await migrator.addColumn(
              creditCards,
              creditCards.defaultPaymentAccountId,
            );
            await migrator.addColumn(creditCards, creditCards.isPrimary);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'finance_pet.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
