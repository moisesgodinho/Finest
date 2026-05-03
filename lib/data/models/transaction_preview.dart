import 'package:flutter/material.dart';

class TransactionPreview {
  const TransactionPreview({
    required this.title,
    required this.subtitle,
    required this.amountCents,
    required this.icon,
    required this.iconColor,
    this.dateLabel,
    this.isIncome = false,
    this.isPaid = true,
  });

  final String title;
  final String subtitle;
  final int amountCents;
  final IconData icon;
  final Color iconColor;
  final String? dateLabel;
  final bool isIncome;
  final bool isPaid;
}
