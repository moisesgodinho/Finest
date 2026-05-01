class UpdateCreditCardExpenseRequest {
  const UpdateCreditCardExpenseRequest({
    required this.userId,
    required this.transactionId,
    required this.description,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    this.subcategoryId,
  });

  final int userId;
  final int transactionId;
  final String description;
  final int amountCents;
  final int categoryId;
  final int? subcategoryId;
  final DateTime date;
}
