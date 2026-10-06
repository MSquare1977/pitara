import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

/// Owns document CRUD *and* now persists to the device via
/// shared_preferences, so data survives an app restart. This is the only
/// file that needed to change for that — nothing in the UI or provider
/// had to know storage was added.
class DocumentRepository {
  static const _storageKey = 'pitara_documents';

  List<VaultDocument> _documents = [];

  static final List<VaultDocument> _seedDocuments = [
    VaultDocument(
      id: 'd1',
      categoryId: 'identity',
      title: 'British passport',
      subtitle: 'Expires Mar 2031',
      expiryDate: DateTime(2031, 3, 1),
    ),
    const VaultDocument(
      id: 'd2',
      categoryId: 'identity',
      title: 'Indian passport (surrendered)',
      subtitle: 'Archived',
    ),
    VaultDocument(
      id: 'd3',
      categoryId: 'identity',
      title: 'OCI card',
      subtitle: 'Renew soon',
      expiryDate: DateTime.now().add(const Duration(days: 20)),
    ),
    VaultDocument(
      id: 'd4',
      categoryId: 'identity',
      title: 'US visitor visa',
      subtitle: 'Expires Jan 2029',
      expiryDate: DateTime(2029, 1, 1),
    ),
    const VaultDocument(id: 'd5', categoryId: 'property', title: 'Flat deed — Pune'),
    const VaultDocument(id: 'd6', categoryId: 'education', title: 'BSc degree certificate'),
  ];

  /// Call once at app startup, before the UI reads anything. Loads saved
  /// documents, or seeds demo data the very first time the app ever runs.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      _documents = List.of(_seedDocuments);
      await _save();
    } else {
      final decoded = jsonDecode(raw) as List;
      _documents =
          decoded.map((e) => VaultDocument.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_documents.map((d) => d.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<VaultDocument> getAll() => List.unmodifiable(_documents);

  List<VaultDocument> byCategory(String categoryId) =>
      _documents.where((d) => d.categoryId == categoryId).toList();

  Future<void> add(VaultDocument doc) async {
    _documents.add(doc);
    await _save();
  }

  Future<void> update(VaultDocument doc) async {
    final index = _documents.indexWhere((d) => d.id == doc.id);
    if (index != -1) _documents[index] = doc;
    await _save();
  }

  Future<void> delete(String id) async {
    _documents.removeWhere((d) => d.id == id);
    await _save();
  }

  Future<void> deleteByCategory(String categoryId) async {
    _documents.removeWhere((d) => d.categoryId == categoryId);
    await _save();
  }
}
