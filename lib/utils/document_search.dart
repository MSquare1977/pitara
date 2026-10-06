import '../models/document.dart';
import '../models/category.dart';
import '../models/member.dart';

/// Plain keyword matching across title, category name, person name, and
/// status text — not true natural-language AI search (that's a planned
/// later upgrade once an API key is wired up), but functional today at
/// zero cost.
List<VaultDocument> searchDocuments({
  required String query,
  required List<VaultDocument> documents,
  required List<DocCategory> categories,
  List<FamilyMember> members = const [],
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  final categoryNameById = {for (final c in categories) c.id: c.name.toLowerCase()};
  final memberNameById = {for (final m in members) m.id: m.name.toLowerCase()};

  // A few keyword synonyms so simple natural-ish phrases ("what's expiring
  // soon") still find something, without needing a real AI call.
  final isExpiryQuery = ['expir', 'renew', 'soon'].any((k) => q.contains(k));

  return documents.where((doc) {
    final title = doc.title.toLowerCase();
    final subtitle = (doc.subtitle ?? '').toLowerCase();
    final categoryName = categoryNameById[doc.categoryId] ?? '';
    final memberName = memberNameById[doc.memberId] ?? '';

    final matchesText = title.contains(q) ||
        subtitle.contains(q) ||
        categoryName.contains(q) ||
        memberName.contains(q);
    final matchesExpiry = isExpiryQuery && doc.expiringWithin(90);

    return matchesText || matchesExpiry;
  }).toList();
}
