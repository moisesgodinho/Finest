import 'package:flutter/material.dart';

class TransactionPreview {
  const TransactionPreview({
    required this.title,
    required this.subtitle,
    required this.amountCents,
    required this.icon,
    required this.iconColor,
    this.isIncome = false,
  });

  final String title;
  final String subtitle;
  final int amountCents;
  final IconData icon;
  final Color iconColor;
  final bool isIncome;
}
