class UpdateGoalRequest {
  const UpdateGoalRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.linkedAccountId,
    required this.targetAmountCents,
    required this.targetDate,
    required this.color,
  });

  final int id;
  final int userId;
  final String name;
  final int linkedAccountId;
  final int targetAmountCents;
  final DateTime targetDate;
  final String color;
}
