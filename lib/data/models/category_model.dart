import 'package:flutter/material.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.colorHex,
    this.iconName = 'category',
  });

  final int id;
  final String name;
  final String type;
  final IconData icon;
  final Color color;
  final String colorHex;
  final String iconName;
}
