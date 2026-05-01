class UpdateAccountRequest {
  const UpdateAccountRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.currentBalance,
    required this.color,
    this.bankName,
    this.emergencyReserveTarget,
    this.icon,
  });

  final int id;
  final int userId;
  final String name;
  final String type;
  final String? bankName;
  final int initialBalance;
  final int currentBalance;
  final String color;
  final int? emergencyReserveTarget;
  final String? icon;
}
