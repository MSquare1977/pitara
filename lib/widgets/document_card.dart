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

    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHigh,
        border: Border.all(
          color: isWarning
              ? scheme.error.withValues(alpha: 0.6)
              : scheme.primary.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isWarning
                        ? scheme.errorContainer
                        : scheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    size: 22,
                    color: isWarning ? scheme.onErrorContainer : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      if (document.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          document.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isWarning ? scheme.error : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (member != null) ...[
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: member.color,
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right_rounded, size: 22, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}