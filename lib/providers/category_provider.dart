import 'package:flutter/material.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository = CategoryRepository();

  Future<void> load() async {
    await _repository.load();
    notifyListeners();
  }

  List<DocCategory> get categories => _repository.getAll();

  Future<void> addCategory(DocCategory category) async {
    await _repository.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(DocCategory category) async {
    await _repository.update(category);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _repository.delete(id);
    notifyListeners();
  }

  Future<void> reorderAll(List<DocCategory> newOrder) async {
    await _repository.replaceAll(newOrder);
    notifyListeners();
  }
}
