class CreateGoalRequest {
  const CreateGoalRequest({
    required this.userId,
    required this.name,
    required this.linkedAccountId,
    required this.targetAmountCents,
    required this.targetDate,
    this.color = '#006B4F',
  });

  final int userId;
  final String name;
  final int linkedAccountId;
  final int targetAmountCents;
  final DateTime targetDate;
  final String color;
}
