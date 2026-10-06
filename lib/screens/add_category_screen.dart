import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';

/// A fixed set of sensible icons to choose from — no need for a full icon
/// library browser for a first version of this.
const List<IconData> _iconChoices = [
  Icons.badge_outlined,
  Icons.home_outlined,
  Icons.school_outlined,
  Icons.description_outlined,
  Icons.shield_outlined,
  Icons.account_balance_outlined,
  Icons.directions_car_outlined,
  Icons.favorite_outline,
  Icons.work_outline,
  Icons.pets_outlined,
  Icons.flight_outlined,
  Icons.medical_services_outlined,
];

/// Same form handles both adding a new category and editing an existing
/// one — pass existingCategory to edit, leave it null to add.
class AddCategoryScreen extends StatefulWidget {
  final DocCategory? existingCategory;

  const AddCategoryScreen({super.key, this.existingCategory});

  bool get isEditing => existingCategory != null;

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  late final TextEditingController _nameController;
  late IconData _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingCategory?.name ?? '');
    _selectedIcon = widget.existingCategory?.icon ?? _iconChoices.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<CategoryProvider>();
    final category = DocCategory(
      id: widget.existingCategory?.id ?? 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: _selectedIcon,
    );

    widget.isEditing ? await provider.updateCategory(category) : await provider.addCategory(category);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit category' : 'New category')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: !widget.isEditing,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const SizedBox(height: 20),
            Text('Icon', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _iconChoices.map((icon) {
                final selected = icon == _selectedIcon;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? scheme.primary : scheme.outlineVariant,
                        width: selected ? 1.5 : 0.6,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(widget.isEditing ? 'Save changes' : 'Create category'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
