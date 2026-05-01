import 'package:flutter/material.dart';

class AccountPreview {
  const AccountPreview({
    required this.name,
    required this.type,
    required this.balanceCents,
    required this.color,
    this.bankName,
    this.lastDigits,
  });

  final String name;
  final String type;
  final String? bankName;
  final String? lastDigits;
  final int balanceCents;
  final Color color;
}
