import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';

class DocumentCard extends StatelessWidget {
  final VaultDocument document;
  final VoidCallback onTap;

  const DocumentCard({super.key, required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWarning = document.subtitle?.toLowerCase().contains('renew') ?? false;

    FamilyMember? member;
    if (document.memberId != null) {
      final members = context.watch<MemberProvider>().members;
      for (final m in members) {
        if (m.id == document.memberId) {
          member = m;
          break;
        }
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWarning ? scheme.error.withValues(alpha: 0.5) : scheme.outlineVariant,
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isWarning
                    ? scheme.errorContainer
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 18,
                color: isWarning ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(document.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (document.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      document.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isWarning ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (member != null) ...[
              CircleAvatar(
                radius: 10,
                backgroundColor: member.color,
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
