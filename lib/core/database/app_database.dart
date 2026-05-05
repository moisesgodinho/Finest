import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/accounts_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/credit_card_invoices_dao.dart';
import 'daos/credit_cards_dao.dart';
import 'daos/exchange_rates_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/transfers_dao.dart';
import 'daos/users_dao.dart';
import 'tables/accounts_table.dart';
import 'tables/backup_logs_table.dart';
import 'tables/categories_table.dart';
import 'tables/credit_card_invoices_table.dart';
import 'tables/credit_cards_table.dart';
import 'tables/exchange_rates_table.dart';
import 'tables/investments_table.dart';
import 'tables/monthly_plans_table.dart';
import 'tables/pet_progress_table.dart';
import 'tables/subcategories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/transfers_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Accounts,
    CreditCards,
    CreditCardInvoices,
    Categories,
    Subcategories,
    FinancialTransactions,
    MonthlyPlans,
    Investments,
    PetProgress,
    BackupLogs,
    Transfers,
    ExchangeRates,
  ],
  daos: [
    UsersDao,
    AccountsDao,
    CategoriesDao,
    CreditCardInvoicesDao,
    CreditCardsDao,
    TransactionsDao,
    TransfersDao,
    ExchangeRatesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await _addColumnIfMissing(
              migrator,
              tableName: 'credit_cards',
              columnName: 'brand',
              addColumn: () =>
                  migrator.addColumn(creditCards, creditCards.brand),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'credit_cards',
              columnName: 'current_invoice',
              addColumn: () => migrator.addColumn(
                creditCards,
                creditCards.currentInvoice,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'credit_cards',
              columnName: 'default_payment_account_id',
              addColumn: () => migrator.addColumn(
                creditCards,
                creditCards.defaultPaymentAccountId,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'credit_cards',
              columnName: 'is_primary',
              addColumn: () =>
                  migrator.addColumn(creditCards, creditCards.isPrimary),
            );
          }
          if (from < 3) {
            await _createTableIfMissing(
              migrator,
              tableName: 'subcategories',
              createTable: () => migrator.createTable(subcategories),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'subcategory_id',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.subcategoryId,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'invoice_month',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.invoiceMonth,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'invoice_year',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.invoiceYear,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'expense_kind',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.expenseKind,
              ),
            );
          }
          if (from < 4) {
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'due_date',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.dueDate,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'is_paid',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.isPaid,
              ),
            );
          }
          if (from < 5) {
            await _createTableIfMissing(
              migrator,
              tableName: 'transfers',
              createTable: () => migrator.createTable(transfers),
            );
          }
          if (from < 6) {
            await _createTableIfMissing(
              migrator,
              tableName: 'credit_card_invoices',
              createTable: () => migrator.createTable(creditCardInvoices),
            );
          }
          if (from < 7) {
            await _addColumnIfMissing(
              migrator,
              tableName: 'accounts',
              columnName: 'emergency_reserve_target',
              addColumn: () => migrator.addColumn(
                accounts,
                accounts.emergencyReserveTarget,
              ),
            );
          }
          if (from < 8) {
            await _addColumnIfMissing(
              migrator,
              tableName: 'accounts',
              columnName: 'include_in_total_balance',
              addColumn: () => migrator.addColumn(
                accounts,
                accounts.includeInTotalBalance,
              ),
            );
          }
          if (from < 9) {
            await _addColumnIfMissing(
              migrator,
              tableName: 'accounts',
              columnName: 'currency_code',
              addColumn: () => migrator.addColumn(
                accounts,
                accounts.currencyCode,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transactions',
              columnName: 'currency_code',
              addColumn: () => migrator.addColumn(
                financialTransactions,
                financialTransactions.currencyCode,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transfers',
              columnName: 'converted_amount',
              addColumn: () => migrator.addColumn(
                transfers,
                transfers.convertedAmount,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transfers',
              columnName: 'from_currency_code',
              addColumn: () => migrator.addColumn(
                transfers,
                transfers.fromCurrencyCode,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transfers',
              columnName: 'to_currency_code',
              addColumn: () => migrator.addColumn(
                transfers,
                transfers.toCurrencyCode,
              ),
            );
            await _addColumnIfMissing(
              migrator,
              tableName: 'transfers',
              columnName: 'exchange_rate',
              addColumn: () => migrator.addColumn(
                transfers,
                transfers.exchangeRate,
              ),
            );
            await _createTableIfMissing(
              migrator,
              tableName: 'exchange_rates',
              createTable: () => migrator.createTable(exchangeRates),
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _addColumnIfMissing(
    Migrator migrator, {
    required String tableName,
    required String columnName,
    required Future<void> Function() addColumn,
  }) async {
    final exists = await _columnExists(tableName, columnName);
    if (!exists) {
      await addColumn();
    }
  }

  Future<void> _createTableIfMissing(
    Migrator migrator, {
    required String tableName,
    required Future<void> Function() createTable,
  }) async {
    final exists = await _tableExists(tableName);
    if (!exists) {
      await createTable();
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      variables: [
        Variable.withString('table'),
        Variable.withString(tableName),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final escapedTableName = tableName.replaceAll('"', '""');
    final rows = await customSelect(
      'PRAGMA table_info("$escapedTableName")',
    ).get();
    return rows.any((row) => row.data['name'] == columnName);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'finest.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
