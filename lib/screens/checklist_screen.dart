import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/document.dart';
import '../models/planned_item.dart';
import '../providers/category_provider.dart';
import '../providers/document_provider.dart';
import '../providers/planned_item_provider.dart';
import '../utils/checklist_rows.dart';
import 'add_edit_document_screen.dart';
import 'add_planned_item_screen.dart';
import 'document_detail_screen.dart';

enum _Filter { all, toAdd, added }

/// A table of every document in the vault (automatically) plus placeholder
/// rows for documents the user still needs.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final documents = context.watch<DocumentProvider>().all;
    final categories = context.watch<CategoryProvider>().categories;
    final planned = context.watch<PlannedItemProvider>().items;

    final rows = buildChecklistRows(
      documents: documents,
      categories: categories,
      plannedItems: planned,
    );
    final addedCount = rows.where((r) => r.status == ChecklistStatus.added).length;
    final toAddCount = rows.length - addedCount;

    final visible = rows.where((r) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.toAdd => r.status == ChecklistStatus.toAdd,
        _Filter.added => r.status == ChecklistStatus.added,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Checklist')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _SummaryCard(added: addedCount, total: rows.length),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('All (${rows.length})'),
                    selected: _filter == _Filter.all,
                    onSelected: (_) => setState(() => _filter = _Filter.all),
                  ),
                  ChoiceChip(
                    label: Text('To add ($toAddCount)'),
                    selected: _filter == _Filter.toAdd,
                    onSelected: (_) => setState(() => _filter = _Filter.toAdd),
                  ),
                  ChoiceChip(
                    label: Text('Added ($addedCount)'),
                    selected: _filter == _Filter.added,
                    onSelected: (_) => setState(() => _filter = _Filter.added),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.outlineVariant),
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                _headerCell(scheme, 'DOCUMENT', flex: 5),
                _headerCell(scheme, 'FOLDER', flex: 3, leftPad: 8),
                SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('STATUS', style: _headerStyle(scheme)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(hasAnyRows: rows.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final row = visible[index];
                      return _RowTile(
                        row: row,
                        onTap: () => _onTap(row, rows),
                        onLongPress:
                            row.plannedItem == null ? null : () => _showActions(row, rows),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRow(categories),
        icon: const Icon(Icons.add),
        label: const Text('Add row'),
      ),
    );
  }

  TextStyle _headerStyle(ColorScheme scheme) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: scheme.onSurfaceVariant,
      );

  Widget _headerCell(ColorScheme scheme, String text, {required int flex, double leftPad = 0}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(left: leftPad),
        child: Text(text, style: _headerStyle(scheme)),
      ),
    );
  }

  // --- actions ---------------------------------------------------------

  Future<void> _addRow(List<DocCategory> categories) async {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a folder on the home screen first')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPlannedItemScreen()),
    );
  }

  void _onTap(ChecklistRow row, List<ChecklistRow> rows) {
    final document = row.document;
    if (document != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(
            documentId: document.id,
            categoryId: document.categoryId,
          ),
        ),
      );
      return;
    }
    _showActions(row, rows);
  }

  void _showActions(ChecklistRow row, List<ChecklistRow> rows) {
    final item = row.plannedItem;
    if (item == null) return;
    final isAdded = row.status == ChecklistStatus.added;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  row.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (!isAdded)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add the document now'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addNow(row);
                },
              ),
            if (!isAdded)
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Link a document already in the vault'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _linkExisting(row, rows);
                },
              ),
            if (isAdded)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open document'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _onTap(row, rows);
                },
              ),
            if (isAdded)
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('Unlink document (back to To add)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<PlannedItemProvider>().unlink(item.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit row'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddPlannedItemScreen(existing: item)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text('Delete row', style: TextStyle(color: scheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the normal add-document form with the name pre-filled, and
  /// attaches the saved document to this row.
  Future<void> _addNow(ChecklistRow row) async {
    final item = row.plannedItem;
    if (item == null) return;

    final categories = context.read<CategoryProvider>().categories;
    String? categoryId = categories.any((c) => c.id == item.categoryId) ? item.categoryId : null;
    categoryId ??= await _pickFolder(categories);
    if (categoryId == null || !mounted) return;
    final folderId = categoryId;

    final saved = await Navigator.push<VaultDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditDocumentScreen(categoryId: folderId, initialTitle: item.name),
      ),
    );
    if (saved != null && mounted) {
      await context.read<PlannedItemProvider>().linkDocument(item.id, saved.id);
    }
  }

  Future<String?> _pickFolder(List<DocCategory> categories) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose a folder'),
        children: [
          for (final category in categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, category.id),
              child: Text(category.name),
            ),
        ],
      ),
    );
  }

  Future<void> _linkExisting(ChecklistRow row, List<ChecklistRow> rows) async {
    final item = row.plannedItem;
    if (item == null) return;

    // Only documents not already attached to another row.
    final candidates = rows
        .where((r) => r.document != null && r.plannedItem == null)
        .map((r) => r.document!)
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every document in your vault is already on a row')),
      );
      return;
    }

    // Documents from the same folder first.
    candidates.sort((a, b) {
      final sameA = a.categoryId == item.categoryId ? 0 : 1;
      final sameB = b.categoryId == item.categoryId ? 0 : 1;
      if (sameA != sameB) return sameA - sameB;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    final chosen = await showModalBottomSheet<VaultDocument>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Link which document?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              for (final document in candidates)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(document.title),
                  subtitle: document.subtitle != null ? Text(document.subtitle!) : null,
                  onTap: () => Navigator.pop(sheetContext, document),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen != null && mounted) {
      await context.read<PlannedItemProvider>().linkDocument(item.id, chosen.id);
    }
  }

  void _confirmDelete(PlannedItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${item.name}"?'),
        content: const Text(
          'This removes the row from your checklist. A document attached to it stays in your vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await context.read<PlannedItemProvider>().deleteItem(item.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// --- small widgets -------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final int added;
  final int total;

  const _SummaryCard({required this.added, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toAdd = total - added;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == 0 ? 'Nothing on your list yet' : '$added of $total added',
            style: const TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : added / total,
              minHeight: 8,
              backgroundColor: scheme.outlineVariant,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == 0
                ? 'Add a row for each document you still need.'
                : toAdd == 0
                    ? 'Everything on your list is in the vault.'
                    : '$toAdd still to add',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAnyRows;

  const _EmptyState({required this.hasAnyRows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          hasAnyRows
              ? 'No rows match this filter.'
              : 'Your vault is empty. Add a row for each document you need, and it moves to "Added" when you attach the real one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final ChecklistRow row;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RowTile({required this.row, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = row.dueDate;

    String? subtitle;
    if (row.status == ChecklistStatus.toAdd && due != null) {
      subtitle = 'Get by ${DateFormat.yMMMd().format(due)}';
    } else if (row.document?.subtitle != null) {
      subtitle = row.document!.subtitle;
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: row.overdue ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  row.folderName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: row.folderName == noFolderLabel
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerRight,
                child: _StatusChip(row: row),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status is always spelled out in words and never conveyed by colour alone.
class _StatusChip extends StatelessWidget {
  final ChecklistRow row;

  const _StatusChip({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late final String label;
    late final IconData icon;
    late final Color color;
    late final bool filled;

    if (row.status == ChecklistStatus.added) {
      label = 'Added';
      icon = Icons.check;
      color = scheme.primary;
      filled = true;
    } else if (row.overdue) {
      label = 'Overdue';
      icon = Icons.schedule;
      color = scheme.error;
      filled = false;
    } else {
      label = 'To add';
      icon = Icons.add;
      color = scheme.onSurfaceVariant;
      filled = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : null,
        border: filled ? null : Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}