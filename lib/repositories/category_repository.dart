import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';

/// Same persistence pattern as DocumentRepository.
class CategoryRepository {
  static const _storageKey = 'pitara_categories';

  List<DocCategory> _categories = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      _categories = List.of(defaultCategories);
      await _save();
    } else {
      final decoded = jsonDecode(raw) as List;
      _categories =
          decoded.map((e) => DocCategory.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_categories.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<DocCategory> getAll() => List.unmodifiable(_categories);

  Future<void> add(DocCategory category) async {
    _categories.add(category);
    await _save();
  }

  Future<void> update(DocCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) _categories[index] = category;
    await _save();
  }

  Future<void> delete(String id) async {
    _categories.removeWhere((c) => c.id == id);
    await _save();
  }

  /// Replaces the entire order at once — used after a drag-and-drop reorder.
  Future<void> replaceAll(List<DocCategory> newOrder) async {
    _categories
      ..clear()
      ..addAll(newOrder);
    await _save();
  }
}
