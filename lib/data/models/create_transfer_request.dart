class CreateTransferRequest {
  const CreateTransferRequest({
    required this.userId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.name,
    required this.amountCents,
    required this.transferKind,
    required this.dueDate,
    required this.isPaid,
    required this.date,
    this.installmentNumber,
    this.totalInstallments,
  });

  final int userId;
  final int fromAccountId;
  final int toAccountId;
  final String name;
  final int amountCents;
  final String transferKind;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime date;
  final int? installmentNumber;
  final int? totalInstallments;
}
