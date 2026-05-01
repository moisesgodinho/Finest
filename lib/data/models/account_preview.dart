import 'package:flutter/material.dart';

class AccountPreview {
  const AccountPreview({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceCents,
    required this.color,
    required this.colorHex,
    this.emergencyReserveTargetCents,
    this.bankName,
    this.lastDigits,
  });

  final int id;
  final String name;
  final String type;
  final String? bankName;
  final String? lastDigits;
  final int balanceCents;
  final int? emergencyReserveTargetCents;
  final Color color;
  final String colorHex;

  bool get isEmergencyReserve {
    final normalizedName = name.toLowerCase();
    return emergencyReserveTargetCents != null ||
        normalizedName.contains('reserva') ||
        normalizedName.contains('emergência') ||
        normalizedName.contains('emergencia');
  }
}
