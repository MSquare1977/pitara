import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/planned_item.dart';
import '../providers/category_provider.dart';
import '../providers/planned_item_provider.dart';

/// Add or edit a checklist row for a document the user still needs.
/// Pass [existing] to edit; leave it null to add.
class AddPlannedItemScreen extends StatefulWidget {
  final PlannedItem? existing;

  const AddPlannedItemScreen({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<AddPlannedItemScreen> createState() => _AddPlannedItemScreenState();
}

class _AddPlannedItemScreenState extends State<AddPlannedItemScreen> {
  late final TextEditingController _nameController;
  String? _categoryId;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _categoryId = widget.existing?.categoryId;
    _dueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a document name and choose a folder')),
      );
      return;
    }
    setState(() => _saving = true);

    final provider = context.read<PlannedItemProvider>();
    final existing = widget.existing;
    if (existing != null) {
      await provider.updateItem(PlannedItem(
        id: existing.id,
        name: name,
        categoryId: _categoryId,
        dueDate: _dueDate,
        linkedDocumentId: existing.linkedDocumentId,
      ));
    } else {
      await provider.addItem(PlannedItem(
        id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        categoryId: _categoryId,
        dueDate: _dueDate,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit row' : 'Add to checklist')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            autofocus: !widget.isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Document name'),
          ),
          const SizedBox(height: 20),
          Text('Folder', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                ChoiceChip(
                  avatar: Icon(category.icon, size: 16),
                  label: Text(category.name),
                  selected: _categoryId == category.id,
                  onSelected: (_) => setState(() => _categoryId = category.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined, size: 20),
            title: Text(
              _dueDate == null
                  ? 'No due date'
                  : 'Get this by ${DateFormat.yMMMd().format(_dueDate!)}',
            ),
            trailing: _dueDate != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _dueDate = null),
                  )
                : null,
            onTap: _pickDueDate,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.isEditing ? 'Save changes' : 'Add row'),
          ),
        ],
      ),
    );
  }
}