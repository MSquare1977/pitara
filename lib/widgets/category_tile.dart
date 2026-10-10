import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryTile extends StatelessWidget {
  final DocCategory category;
  final int documentCount;
  final VoidCallback onTap;
  final bool editMode;
  final VoidCallback? onDelete;

  const CategoryTile({
    super.key,
    required this.category,
    required this.documentCount,
    required this.onTap,
    this.editMode = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh]
                    : [scheme.surfaceContainerHigh, scheme.surfaceContainerHighest],
              ),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.28), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(category.icon, color: scheme.primary, size: 22),
                          ),
                          const Spacer(),
                          if (!editMode)
                            Icon(Icons.arrow_outward_rounded,
                                size: 16, color: scheme.onSurfaceVariant),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$documentCount document${documentCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (editMode)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(Icons.close, size: 14, color: scheme.onError),
              ),
            ),
          ),
      ],
    );
  }
}