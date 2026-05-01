// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credit_card_invoices_dao.dart';

// ignore_for_file: type=lint
mixin _$CreditCardInvoicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CreditCardsTable get creditCards => attachedDatabase.creditCards;
  $CreditCardInvoicesTable get creditCardInvoices =>
      attachedDatabase.creditCardInvoices;
  CreditCardInvoicesDaoManager get managers =>
      CreditCardInvoicesDaoManager(this);
}

class CreditCardInvoicesDaoManager {
  final _$CreditCardInvoicesDaoMixin _db;
  CreditCardInvoicesDaoManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CreditCardsTableTableManager get creditCards =>
      $$CreditCardsTableTableManager(_db.attachedDatabase, _db.creditCards);
  $$CreditCardInvoicesTableTableManager get creditCardInvoices =>
      $$CreditCardInvoicesTableTableManager(
          _db.attachedDatabase, _db.creditCardInvoices);
}
