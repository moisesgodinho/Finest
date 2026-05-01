import 'package:flutter/material.dart';

class CategoryExpensePreview {
  const CategoryExpensePreview({
    required this.name,
    required this.amountCents,
    required this.percent,
    required this.color,
    required this.icon,
  });

  final String name;
  final int amountCents;
  final double percent;
  final Color color;
  final IconData icon;
}
