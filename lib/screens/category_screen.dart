import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/document_provider.dart';
import '../widgets/document_card.dart';
import 'document_detail_screen.dart';
import 'add_edit_document_screen.dart';

class CategoryScreen extends StatelessWidget {
  final DocCategory category;

  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentProvider>().byCategory(category.id);

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: documents.isEmpty
            ? Center(
                child: Text(
                  'No documents yet',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
            : ListView.builder(
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  return DocumentCard(
                    document: doc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DocumentDetailScreen(documentId: doc.id, categoryId: category.id),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditDocumentScreen(categoryId: category.id)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
    );
  }
}
