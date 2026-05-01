import 'package:flutter/material.dart';

class CreditCardPreview {
  const CreditCardPreview({
    required this.name,
    required this.lastDigits,
    required this.invoiceCents,
    required this.limitCents,
    required this.usedPercent,
    required this.color,
    required this.dueDay,
  });

  final String name;
  final String lastDigits;
  final int invoiceCents;
  final int limitCents;
  final double usedPercent;
  final Color color;
  final int dueDay;
}
