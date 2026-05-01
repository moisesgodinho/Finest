import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../models/category_model.dart';

abstract class CategoryRepository {
  Stream<List<CategoryModel>> watchCategories(int userId);

  Future<List<CategoryModel>> findCategories(int userId);

  Future<List<CategoryModel>> findCategoriesByType({
    required int userId,
    required String type,
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
      _ => Icons.category_rounded,
    };
  }

  Color _colorFromHex(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primary : Color(parsed);
  }
}

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
