class UpdateTransactionRequest {
  const UpdateTransactionRequest({
    required this.userId,
    required this.transactionId,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.date,
    required this.isPaid,
    this.dueDate,
    this.subcategoryId,
    this.transactionKind,
    this.installmentNumber,
    this.totalInstallments,
  });

  final int userId;
  final int transactionId;
  final int accountId;
  final int categoryId;
  final int? subcategoryId;
  final String type;
  final String description;
  final int amountCents;
  final DateTime date;
  final DateTime? dueDate;
  final String? transactionKind;
  final int? installmentNumber;
  final int? totalInstallments;
  final bool isPaid;
}
