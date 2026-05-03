import 'package:flutter/material.dart';

class CreditCardInvoicePreview {
  const CreditCardInvoicePreview({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.cardLastDigits,
    required this.month,
    required this.year,
    required this.amountCents,
    required this.status,
    required this.statusLabel,
    required this.dueDate,
    required this.cardColor,
    required this.transactions,
    this.paymentAccountId,
    this.paymentAccountName,
    this.paidAt,
  });

  final int id;
  final int cardId;
  final String cardName;
  final String cardLastDigits;
  final int month;
  final int year;
  final int amountCents;
  final String status;
  final String statusLabel;
  final DateTime dueDate;
  final int? paymentAccountId;
  final String? paymentAccountName;
  final DateTime? paidAt;
  final Color cardColor;
  final List<CreditCardInvoiceTransactionPreview> transactions;

  bool get isPaid => status == 'paid';
  bool get canPay => !isPaid && amountCents > 0;
}

class CreditCardInvoiceTransactionPreview {
  const CreditCardInvoiceTransactionPreview({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    this.subcategoryId,
    this.subcategoryName,
    this.entryKind,
    this.installmentNumber,
    this.totalInstallments,
  });

  final int id;
  final String description;
  final int amountCents;
  final DateTime date;
  final int categoryId;
  final String categoryName;
  final String type;
  final int? subcategoryId;
  final String? subcategoryName;
  final String? entryKind;
  final int? installmentNumber;
  final int? totalInstallments;

  bool get isExpense => type == 'expense';
  bool get isCredit => type == 'income';
  bool get isRefund => entryKind == 'refund';
  bool get isCashback => entryKind == 'cashback';

  int get signedAmountCents => isCredit ? -amountCents : amountCents;

  String get entryKindLabel {
    if (isRefund) {
      return 'Estorno';
    }
    if (isCashback) {
      return 'Cashback';
    }
    return 'Gasto';
  }
}
