import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';
import '../tables/subcategories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, Subcategories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Stream<List<Category>> watchByUser(int userId) {
    final query = select(categories)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm(expression: table.type),
        (table) => OrderingTerm(expression: table.name),
      ]);

    return query.watch();
  }

  Future<List<Category>> findByUser(int userId) {
    final query = select(categories)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm(expression: table.type),
        (table) => OrderingTerm(expression: table.name),
      ]);

    return query.get();
  }

  Future<List<Category>> findByUserAndType({
    required int userId,
    required String type,
  }) {
    final query = select(categories)
      ..where((table) => table.userId.equals(userId) & table.type.equals(type))
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);

    return query.get();
  }

  Future<Category?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(categories)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> countByUser(int userId) async {
    final countExpression = categories.id.count();
    final query = selectOnly(categories)
      ..addColumns([countExpression])
      ..where(categories.userId.equals(userId));

    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> insertAllCategories(List<CategoriesCompanion> rows) async {
    await batch((batch) {
      batch.insertAll(categories, rows);
    });
  }

  Future<int> insertCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  Stream<List<Subcategory>> watchSubcategoriesByUser(int userId) {
    final query = select(subcategories)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);

    return query.watch();
  }

  Future<List<Subcategory>> findSubcategoriesByCategory({
    required int userId,
    required int categoryId,
  }) {
    final query = select(subcategories)
      ..where(
        (table) =>
            table.userId.equals(userId) & table.categoryId.equals(categoryId),
      )
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);

    return query.get();
  }

  Future<Subcategory?> findSubcategoryByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(subcategories)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> insertSubcategory(SubcategoriesCompanion subcategory) {
    return into(subcategories).insert(subcategory);
  }
}
