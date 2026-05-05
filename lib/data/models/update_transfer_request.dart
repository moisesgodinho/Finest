class UpdateTransferRequest {
  const UpdateTransferRequest({
    required this.userId,
    required this.transferId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.name,
    required this.amountCents,
    required this.toAmountCents,
    required this.transferKind,
    required this.dueDate,
    required this.isPaid,
    required this.date,
    this.installmentNumber,
    this.totalInstallments,
    this.exchangeRate,
  });

  final int userId;
  final int transferId;
  final int fromAccountId;
  final int toAccountId;
  final String name;
  final int amountCents;
  final int toAmountCents;
  final String transferKind;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime date;
  final int? installmentNumber;
  final int? totalInstallments;
  final double? exchangeRate;
}
