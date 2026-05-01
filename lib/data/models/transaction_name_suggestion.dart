class TransactionNameSuggestion {
  const TransactionNameSuggestion({
    required this.id,
    required this.description,
    required this.categoryId,
    this.subcategoryId,
    this.accountId,
    this.creditCardId,
  });

  final int id;
  final String description;
  final int categoryId;
  final int? subcategoryId;
  final int? accountId;
  final int? creditCardId;
}
