class SubcategoryModel {
  const SubcategoryModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.name,
  });

  final int id;
  final int userId;
  final int categoryId;
  final String name;
}
