import 'package:flutter/material.dart';
import '../models/planned_item.dart';
import '../repositories/planned_item_repository.dart';

class PlannedItemProvider extends ChangeNotifier {
  final PlannedItemRepository _repository = PlannedItemRepository();

  Future<void> load() async {
    await _repository.load();
    notifyListeners();
  }

  List<PlannedItem> get items => _repository.getAll();

  Future<void> addItem(PlannedItem item) async {
    await _repository.add(item);
    notifyListeners();
  }

  Future<void> updateItem(PlannedItem item) async {
    await _repository.update(item);
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    await _repository.delete(id);
    notifyListeners();
  }

  Future<void> linkDocument(String itemId, String documentId) async {
    await _repository.link(itemId, documentId);
    notifyListeners();
  }

  Future<void> unlink(String itemId) async {
    await _repository.unlink(itemId);
    notifyListeners();
  }

  /// Rows still waiting for a document: not linked, or linked to a document
  /// that has since been deleted.
  int toAddCount(Iterable<String> existingDocumentIds) {
    final existing = existingDocumentIds.toSet();
    return items
        .where((i) => i.linkedDocumentId == null || !existing.contains(i.linkedDocumentId))
        .length;
  }
}