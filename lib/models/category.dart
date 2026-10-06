import 'package:flutter/material.dart';

class DocCategory {
  final String id;
  final String name;
  final IconData icon;

  const DocCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        // IconData isn't directly JSON-able — store what's needed to rebuild it.
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
      };

  factory DocCategory.fromJson(Map<String, dynamic> json) => DocCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: IconData(
          json['iconCodePoint'] as int,
          fontFamily: json['iconFontFamily'] as String?,
        ),
      );
}

// Starter categories — used to seed storage the very first time the app runs.
const List<DocCategory> defaultCategories = [
  DocCategory(id: 'identity', name: 'Passport & visa', icon: Icons.badge_outlined),
  DocCategory(id: 'property', name: 'Property', icon: Icons.home_outlined),
  DocCategory(id: 'education', name: 'Education', icon: Icons.school_outlined),
  DocCategory(id: 'legal', name: 'Will & legal', icon: Icons.description_outlined),
  DocCategory(id: 'insurance', name: 'Insurance', icon: Icons.shield_outlined),
  DocCategory(id: 'finance', name: 'Finance', icon: Icons.account_balance_outlined),
];
