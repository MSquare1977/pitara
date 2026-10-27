import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planned_item.dart';

/// Same persistence pattern as the category and document repositories.
class PlannedItemRepository {
  static const _storageKey = 'pitara_planned_items';

  List<PlannedItem> _items = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      _items = [];
    } else {
      final decoded = jsonDecode(raw) as List;
      _items = decoded.map((e) => PlannedItem.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  List<PlannedItem> getAll() => List.unmodifiable(_items);

  Future<void> add(PlannedItem item) async {
    _items.add(item);
    await _save();
  }

  Future<void> update(PlannedItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) _items[index] = item;
    await _save();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _save();
  }

  /// Attaches [documentId] to the item. A document can belong to only one
  /// row, so any other row that pointed at it is released first.
  Future<void> link(String itemId, String documentId) async {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].linkedDocumentId == documentId && _items[i].id != itemId) {
        _items[i] = _items[i].copyWith(clearLink: true);
      }
    }
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) _items[index] = _items[index].copyWith(linkedDocumentId: documentId);
    await _save();
  }

  Future<void> unlink(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) _items[index] = _items[index].copyWith(clearLink: true);
    await _save();
  }
}