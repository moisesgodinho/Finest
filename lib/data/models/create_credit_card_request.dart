class CreateCreditCardRequest {
  const CreateCreditCardRequest({
    required this.userId,
    required this.name,
    required this.lastDigits,
    required this.brand,
    required this.limitCents,
    required this.currentInvoiceCents,
    required this.defaultPaymentAccountId,
    required this.closingDay,
    required this.dueDay,
    required this.isPrimary,
    this.bankName,
    this.color = '#006B4F',
  });

  final int userId;
  final String name;
  final String? bankName;
  final String lastDigits;
  final String brand;
  final int limitCents;
  final int currentInvoiceCents;
  final int defaultPaymentAccountId;
  final int closingDay;
  final int dueDay;
  final bool isPrimary;
  final String color;
}
