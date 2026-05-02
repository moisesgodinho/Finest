import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../models/category_model.dart';
import '../models/subcategory_model.dart';

abstract class CategoryRepository {
  Stream<List<CategoryModel>> watchCategories(int userId);

  Future<List<CategoryModel>> findCategories(int userId);

  Future<List<CategoryModel>> findCategoriesByType({
    required int userId,
    required String type,
  });

  Stream<List<SubcategoryModel>> watchSubcategories(int userId);

  Future<int> createExpenseCategory({
    required int userId,
    required String name,
  });

  Future<int> createIncomeCategory({
    required int userId,
    required String name,
  });

  Future<int> createCategory({
    required int userId,
    required String name,
    required String type,
    required String icon,
    required String color,
  });

  Future<void> updateCategory({
    required int userId,
    required int categoryId,
    required String name,
    required String icon,
    required String color,
  });

  Future<void> deleteCategory({
    required int userId,
    required int categoryId,
  });

  Future<int> createSubcategory({
    required int userId,
    required int categoryId,
    required String name,
  });

  Future<void> updateSubcategory({
    required int userId,
    required int subcategoryId,
    required String name,
  });

  Future<void> deleteSubcategory({
    required int userId,
    required int subcategoryId,
  });

  Future<void> ensureDefaultCategories(int userId);
}

class DriftCategoryRepository implements CategoryRepository {
  const DriftCategoryRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<CategoryModel>> watchCategories(int userId) {
    return _database.categoriesDao.watchByUser(userId).map(
          (categories) => categories.map(_mapCategory).toList(),
        );
  }

  @override
  Future<List<CategoryModel>> findCategories(int userId) async {
    final categories = await _database.categoriesDao.findByUser(userId);
    return categories.map(_mapCategory).toList();
  }

  @override
  Future<List<CategoryModel>> findCategoriesByType({
    required int userId,
    required String type,
  }) async {
    final categories = await _database.categoriesDao.findByUserAndType(
      userId: userId,
      type: type,
    );
    return categories.map(_mapCategory).toList();
  }

  @override
  Stream<List<SubcategoryModel>> watchSubcategories(int userId) {
    return _database.categoriesDao.watchSubcategoriesByUser(userId).map(
          (subcategories) => subcategories.map(_mapSubcategory).toList(),
        );
  }

  @override
  Future<int> createExpenseCategory({
    required int userId,
    required String name,
  }) {
    return _createCategory(
      userId: userId,
      name: name,
      type: 'expense',
      icon: 'category',
      color: '#006B4F',
    );
  }

  @override
  Future<int> createIncomeCategory({
    required int userId,
    required String name,
  }) {
    return _createCategory(
      userId: userId,
      name: name,
      type: 'income',
      icon: 'income',
      color: '#0A8F4D',
    );
  }

  @override
  Future<int> createCategory({
    required int userId,
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Informe o nome da categoria.');
    }
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Tipo de categoria inválido.');
    }
    await _ensureCategoryNameIsAvailable(
      userId: userId,
      type: type,
      name: trimmedName,
    );

    final now = DateTime.now();
    return _database.categoriesDao.insertCategory(
      CategoriesCompanion.insert(
        userId: userId,
        name: trimmedName,
        type: type,
        icon: Value(icon),
        color: Value(color),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> _createCategory({
    required int userId,
    required String name,
    required String type,
    required String icon,
    required String color,
  }) {
    return createCategory(
      userId: userId,
      name: name,
      type: type,
      icon: icon,
      color: color,
    );
  }

  @override
  Future<void> updateCategory({
    required int userId,
    required int categoryId,
    required String name,
    required String icon,
    required String color,
  }) async {
    final category = await _database.categoriesDao.findByIdForUser(
      id: categoryId,
      userId: userId,
    );
    if (category == null) {
      throw StateError('Categoria não encontrada.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Informe o nome da categoria.');
    }
    await _ensureCategoryNameIsAvailable(
      userId: userId,
      type: category.type,
      name: trimmedName,
      exceptCategoryId: categoryId,
    );

    final affectedRows = await _database.categoriesDao.updateCategory(
      id: categoryId,
      userId: userId,
      category: CategoriesCompanion(
        name: Value(trimmedName),
        icon: Value(icon),
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (affectedRows == 0) {
      throw StateError('Categoria não atualizada.');
    }
  }

  @override
  Future<void> deleteCategory({
    required int userId,
    required int categoryId,
  }) async {
    final affectedRows = await _database.categoriesDao.deleteCategory(
      id: categoryId,
      userId: userId,
    );
    if (affectedRows == 0) {
      throw StateError('Categoria não encontrada.');
    }
  }

  @override
  Future<int> createSubcategory({
    required int userId,
    required int categoryId,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Informe o nome da subcategoria.');
    }

    final category = await _database.categoriesDao.findByIdForUser(
      id: categoryId,
      userId: userId,
    );
    if (category == null) {
      throw StateError('Categoria não encontrada.');
    }
    await _ensureSubcategoryNameIsAvailable(
      userId: userId,
      categoryId: categoryId,
      name: trimmedName,
    );

    final now = DateTime.now();
    return _database.categoriesDao.insertSubcategory(
      SubcategoriesCompanion.insert(
        userId: userId,
        categoryId: categoryId,
        name: trimmedName,
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> updateSubcategory({
    required int userId,
    required int subcategoryId,
    required String name,
  }) async {
    final subcategory =
        await _database.categoriesDao.findSubcategoryByIdForUser(
      id: subcategoryId,
      userId: userId,
    );
    if (subcategory == null) {
      throw StateError('Subcategoria não encontrada.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Informe o nome da subcategoria.');
    }
    await _ensureSubcategoryNameIsAvailable(
      userId: userId,
      categoryId: subcategory.categoryId,
      name: trimmedName,
      exceptSubcategoryId: subcategoryId,
    );

    final affectedRows = await _database.categoriesDao.updateSubcategory(
      id: subcategoryId,
      userId: userId,
      subcategory: SubcategoriesCompanion(
        name: Value(trimmedName),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (affectedRows == 0) {
      throw StateError('Subcategoria não atualizada.');
    }
  }

  @override
  Future<void> deleteSubcategory({
    required int userId,
    required int subcategoryId,
  }) async {
    final affectedRows = await _database.categoriesDao.deleteSubcategory(
      id: subcategoryId,
      userId: userId,
    );
    if (affectedRows == 0) {
      throw StateError('Subcategoria não encontrada.');
    }
  }

  @override
  Future<void> ensureDefaultCategories(int userId) async {
    final existingCount = await _database.categoriesDao.countByUser(userId);
    if (existingCount > 0) {
      return;
    }

    final now = DateTime.now();
    await _database.categoriesDao.insertAllCategories([
      for (final category in _defaultCategories)
        CategoriesCompanion.insert(
          userId: userId,
          name: category.name,
          type: category.type,
          icon: Value(category.icon),
          color: Value(category.color),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
    ]);
  }

  CategoryModel _mapCategory(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      type: category.type,
      icon: _iconFromName(category.icon),
      color: _colorFromHex(category.color),
      colorHex: category.color,
      iconName: category.icon ?? 'category',
    );
  }

  SubcategoryModel _mapSubcategory(Subcategory subcategory) {
    return SubcategoryModel(
      id: subcategory.id,
      userId: subcategory.userId,
      categoryId: subcategory.categoryId,
      name: subcategory.name,
    );
  }

  IconData _iconFromName(String? icon) {
    return switch (icon) {
      'salary' => Icons.payments_rounded,
      'income' => Icons.trending_up_rounded,
      'food' => Icons.restaurant_rounded,
      'transport' => Icons.directions_bus_rounded,
      'home' => Icons.home_work_rounded,
      'health' => Icons.favorite_rounded,
      'leisure' => Icons.local_activity_rounded,
      'investment' => Icons.savings_rounded,
      'education' => Icons.school_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'travel' => Icons.flight_takeoff_rounded,
      'pets' => Icons.pets_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'business' => Icons.work_rounded,
      'bonus' => Icons.stars_rounded,
      _ => Icons.category_rounded,
    };
  }

  Color _colorFromHex(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  Future<void> _ensureCategoryNameIsAvailable({
    required int userId,
    required String type,
    required String name,
    int? exceptCategoryId,
  }) async {
    final categories = await _database.categoriesDao.findByUserAndType(
      userId: userId,
      type: type,
    );
    final normalizedName = _normalize(name);
    final alreadyExists = categories.any(
      (category) =>
          category.id != exceptCategoryId &&
          _normalize(category.name) == normalizedName,
    );
    if (alreadyExists) {
      throw StateError('Já existe uma categoria com esse nome.');
    }
  }

  Future<void> _ensureSubcategoryNameIsAvailable({
    required int userId,
    required int categoryId,
    required String name,
    int? exceptSubcategoryId,
  }) async {
    final subcategories =
        await _database.categoriesDao.findSubcategoriesByCategory(
      userId: userId,
      categoryId: categoryId,
    );
    final normalizedName = _normalize(name);
    final alreadyExists = subcategories.any(
      (subcategory) =>
          subcategory.id != exceptSubcategoryId &&
          _normalize(subcategory.name) == normalizedName,
    );
    if (alreadyExists) {
      throw StateError('Já existe uma subcategoria com esse nome.');
    }
  }
}

String _normalize(String value) => value.trim().toLowerCase();

class _DefaultCategory {
  const _DefaultCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  final String name;
  final String type;
  final String icon;
  final String color;
}

const _defaultCategories = [
  _DefaultCategory(
    name: 'Salário',
    type: 'income',
    icon: 'salary',
    color: '#0A8F4D',
  ),
  _DefaultCategory(
    name: 'Receita extra',
    type: 'income',
    icon: 'income',
    color: '#19A974',
  ),
  _DefaultCategory(
    name: 'Alimentação',
    type: 'expense',
    icon: 'food',
    color: '#0A8F4D',
  ),
  _DefaultCategory(
    name: 'Transporte',
    type: 'expense',
    icon: 'transport',
    color: '#2F80ED',
  ),
  _DefaultCategory(
    name: 'Moradia',
    type: 'expense',
    icon: 'home',
    color: '#7C3AED',
  ),
  _DefaultCategory(
    name: 'Saúde',
    type: 'expense',
    icon: 'health',
    color: '#EC4899',
  ),
  _DefaultCategory(
    name: 'Lazer',
    type: 'expense',
    icon: 'leisure',
    color: '#F59E0B',
  ),
  _DefaultCategory(
    name: 'Investimentos',
    type: 'expense',
    icon: 'investment',
    color: '#006B4F',
  ),
];

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(ref.watch(appDatabaseProvider));
});
