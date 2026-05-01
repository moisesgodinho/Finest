class CreateTransactionRequest {
  const CreateTransactionRequest({
    required this.userId,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.date,
    this.dueDate,
    this.paymentMethod = 'account',
    this.creditCardId,
    this.subcategoryId,
    this.invoiceMonth,
    this.invoiceYear,
    this.expenseKind,
    this.installmentNumber,
    this.totalInstallments,
    this.isPaid = true,
    this.isRecurring = false,
  });

  final int userId;
  final int accountId;
  final int? creditCardId;
  final int categoryId;
  final int? subcategoryId;
  final String type;
  final String description;
  final int amountCents;
  final DateTime date;
  final DateTime? dueDate;
  final String paymentMethod;
  final int? invoiceMonth;
  final int? invoiceYear;
  final String? expenseKind;
  final int? installmentNumber;
  final int? totalInstallments;
  final bool isPaid;
  final bool isRecurring;
}
