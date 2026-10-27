import '../models/category.dart';
import '../models/document.dart';
import '../models/planned_item.dart';

enum ChecklistStatus { added, toAdd }

/// One line of the checklist table.
class ChecklistRow {
  final String key;
  final String title;
  final String folderName;
  final ChecklistStatus status;
  final DateTime? dueDate;
  final bool overdue;

  /// Set when the row is backed by a real document (status == added).
  final VaultDocument? document;

  /// Set when the row came from a placeholder the user created.
  final PlannedItem? plannedItem;

  const ChecklistRow({
    required this.key,
    required this.title,
    required this.folderName,
    required this.status,
    this.dueDate,
    this.overdue = false,
    this.document,
    this.plannedItem,
  });
}

const String noFolderLabel = 'No folder';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Builds the checklist from what is in the vault plus the user's
/// placeholders. Every document appears automatically; a placeholder either
/// waits for a document ("To add") or is attached to one ("Added").
///
///  * A document attached to a placeholder shows once, not twice.
///  * If the attached document is deleted, the placeholder goes back to
///    "To add" instead of disappearing.
///  * If a folder is deleted, its placeholders show "No folder".
///  * "Overdue" means a To-add row whose due date has passed.
List<ChecklistRow> buildChecklistRows({
  required List<VaultDocument> documents,
  required List<DocCategory> categories,
  required List<PlannedItem> plannedItems,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final documentsById = {for (final d in documents) d.id: d};
  final categoryNameById = {for (final c in categories) c.id: c.name};

  String folderName(String? id) =>
      id == null ? noFolderLabel : (categoryNameById[id] ?? noFolderLabel);

  final rows = <ChecklistRow>[];
  final attachedDocumentIds = <String>{};

  for (final item in plannedItems) {
    final linkedId = item.linkedDocumentId;
    final document = linkedId == null ? null : documentsById[linkedId];

    if (document != null && !attachedDocumentIds.contains(document.id)) {
      attachedDocumentIds.add(document.id);
      rows.add(ChecklistRow(
        key: 'planned:${item.id}',
        title: document.title,
        folderName: folderName(document.categoryId),
        status: ChecklistStatus.added,
        dueDate: item.dueDate,
        document: document,
        plannedItem: item,
      ));
    } else {
      final due = item.dueDate;
      rows.add(ChecklistRow(
        key: 'planned:${item.id}',
        title: item.name,
        folderName: folderName(item.categoryId),
        status: ChecklistStatus.toAdd,
        dueDate: due,
        overdue: due != null && _dateOnly(due).isBefore(today),
        plannedItem: item,
      ));
    }
  }

  for (final document in documents) {
    if (attachedDocumentIds.contains(document.id)) continue;
    rows.add(ChecklistRow(
      key: 'doc:${document.id}',
      title: document.title,
      folderName: folderName(document.categoryId),
      status: ChecklistStatus.added,
      document: document,
    ));
  }

  rows.sort(_compareRows);
  return rows;
}

/// To-add rows first (overdue, then soonest due date), then added rows;
/// within each group by folder, then title.
int _compareRows(ChecklistRow a, ChecklistRow b) {
  final groupA = a.status == ChecklistStatus.toAdd ? 0 : 1;
  final groupB = b.status == ChecklistStatus.toAdd ? 0 : 1;
  if (groupA != groupB) return groupA - groupB;

  if (groupA == 0) {
    if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
    final dueA = a.dueDate;
    final dueB = b.dueDate;
    if (dueA != null && dueB != null) {
      final byDue = dueA.compareTo(dueB);
      if (byDue != 0) return byDue;
    } else if (dueA != null) {
      return -1;
    } else if (dueB != null) {
      return 1;
    }
  }

  final byFolder = a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase());
  if (byFolder != 0) return byFolder;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.key.compareTo(b.key);
}