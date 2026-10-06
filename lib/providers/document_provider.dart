import 'package:flutter/material.dart';
import '../models/document.dart';
import '../repositories/document_repository.dart';

class DocumentProvider extends ChangeNotifier {
  final DocumentRepository _repository = DocumentRepository();

  /// Loads saved documents from disk. Call once at startup, before the UI
  /// reads anything, so the app opens with real (persisted) data.
  Future<void> load() async {
    await _repository.load();
    notifyListeners();
  }

  List<VaultDocument> byCategory(String categoryId) =>
      _repository.byCategory(categoryId);

  /// All documents across every category — used by search.
  List<VaultDocument> get all => _repository.getAll();

  int countForCategory(String categoryId) => byCategory(categoryId).length;

  List<VaultDocument> get expiringSoon =>
      _repository.getAll().where((d) => d.expiringWithin(60)).toList();

  Future<void> addDocument(VaultDocument doc) async {
    await _repository.add(doc);
    notifyListeners();
  }

  Future<void> updateDocument(VaultDocument doc) async {
    await _repository.update(doc);
    notifyListeners();
  }

  Future<void> deleteDocument(String id) async {
    await _repository.delete(id);
    notifyListeners();
  }

  Future<void> deleteCategoryDocuments(String categoryId) async {
    await _repository.deleteByCategory(categoryId);
    notifyListeners();
  }
}
