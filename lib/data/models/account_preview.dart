import 'package:flutter/material.dart';

class AccountPreview {
  const AccountPreview({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceCents,
    required this.color,
    required this.colorHex,
    this.initialBalanceCents = 0,
    this.monthlyIncomeCents = 0,
    this.monthlyExpenseCents = 0,
    this.monthlyYieldCents = 0,
    this.currencyCode = 'BRL',
    this.displayBalanceCents,
    int? currentBalanceCents,
    this.includeInTotalBalance = true,
    this.emergencyReserveTargetCents,
    this.goalLinkedAccountId,
    this.goalTargetDate,
    this.createdAt,
    this.firstAvailableMonth,
    this.bankName,
    this.lastDigits,
  }) : currentBalanceCents = currentBalanceCents ?? balanceCents;

  final int id;
  final String name;
  final String type;
  final String? bankName;
  final String? lastDigits;
  final int initialBalanceCents;
  final int balanceCents;
  final int currentBalanceCents;
  final int monthlyIncomeCents;
  final int monthlyExpenseCents;
  final int monthlyYieldCents;
  final String currencyCode;
  final int? displayBalanceCents;
  final bool includeInTotalBalance;
  final int? emergencyReserveTargetCents;
  final int? goalLinkedAccountId;
  final DateTime? goalTargetDate;
  final DateTime? createdAt;
  final DateTime? firstAvailableMonth;
  final Color color;
  final String colorHex;

  bool get isGoal => type == 'goal';
  int get consolidatedBalanceCents => displayBalanceCents ?? balanceCents;

  bool get isEmergencyReserve {
    final normalizedName = name.toLowerCase();
    return emergencyReserveTargetCents != null ||
        normalizedName.contains('reserva') ||
        normalizedName.contains('emergência') ||
        normalizedName.contains('emergencia');
  }
}
