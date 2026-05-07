import 'package:flutter/material.dart';

class GoalPreview {
  const GoalPreview({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmountCents,
    required this.color,
    required this.colorHex,
    this.linkedAccountId,
    this.targetDate,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final String name;
  final int? linkedAccountId;
  final int targetAmountCents;
  final DateTime? targetDate;
  final Color color;
  final String colorHex;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
