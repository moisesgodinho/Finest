import 'package:flutter/material.dart';

class CreditCardPreview {
  const CreditCardPreview({
    required this.id,
    required this.name,
    required this.lastDigits,
    required this.brand,
    required this.brandLabel,
    required this.invoiceCents,
    required this.limitCents,
    required this.usedPercent,
    required this.color,
    required this.colorHex,
    required this.closingDay,
    required this.dueDay,
    required this.isPrimary,
    this.currencyCode = 'BRL',
    int? displayInvoiceCents,
    int? displayLimitCents,
    this.bankName,
    this.defaultPaymentAccountId,
    this.defaultPaymentAccountName,
  })  : displayInvoiceCents = displayInvoiceCents ?? invoiceCents,
        displayLimitCents = displayLimitCents ?? limitCents;

  final int id;
  final String name;
  final String lastDigits;
  final String brand;
  final String brandLabel;
  final int invoiceCents;
  final int limitCents;
  final String currencyCode;
  final int displayInvoiceCents;
  final int displayLimitCents;
  final double usedPercent;
  final Color color;
  final String colorHex;
  final int closingDay;
  final int dueDay;
  final bool isPrimary;
  final String? bankName;
  final int? defaultPaymentAccountId;
  final String? defaultPaymentAccountName;

  int get consolidatedInvoiceCents => displayInvoiceCents;
  int get consolidatedLimitCents => displayLimitCents;
}
