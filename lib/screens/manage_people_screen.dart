import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';

class ManagePeopleScreen extends StatelessWidget {
  const ManagePeopleScreen({super.key});

  Future<void> _addOrEditMember(BuildContext context, {FamilyMember? existing}) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final provider = context.read<MemberProvider>();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add person' : 'Rename person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    if (existing == null) {
      await provider.addMember(
        FamilyMember(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          color: provider.nextColor(),
        ),
      );
    } else {
      await provider.updateMember(FamilyMember(id: existing.id, name: name, color: existing.color));
    }
  }

  void _confirmDelete(BuildContext context, FamilyMember member) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove "${member.name}"?'),
        content: const Text(
          'Documents tagged with this person will stay in the vault, just untagged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<MemberProvider>().deleteMember(member.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<MemberProvider>().members;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: members.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Add people to tag documents by who they belong to — '
                  'e.g. "Dad\'s passport", "Mum\'s visa".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.color,
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(member.name),
                  onTap: () => _addOrEditMember(context, existing: member),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDelete(context, member),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditMember(context),
        icon: const Icon(Icons.add),
        label: const Text('Add person'),
      ),
    );
  }
}
