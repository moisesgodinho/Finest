class CreateAccountRequest {
  const CreateAccountRequest({
    required this.userId,
    required this.name,
    required this.type,
    required this.initialBalance,
    this.bankName,
    this.emergencyReserveTarget,
    this.includeInTotalBalance = true,
    this.currencyCode = 'BRL',
    this.color = '#006B4F',
    this.icon,
  });

  final int userId;
  final String name;
  final String type;
  final String? bankName;
  final int initialBalance;
  final int? emergencyReserveTarget;
  final bool includeInTotalBalance;
  final String currencyCode;
  final String color;
  final String? icon;
}
