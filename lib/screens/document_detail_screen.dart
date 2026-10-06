import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../services/encryption_service.dart';
import '../services/file_vault_service.dart';
import '../services/share_export_service.dart';
import 'add_edit_document_screen.dart';

/// Takes IDs rather than a full document object, and watches the provider —
/// so if you edit the document, this screen reflects the change immediately
/// without needing to be re-navigated to.
class DocumentDetailScreen extends StatefulWidget {
  final String documentId;
  final String categoryId;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.categoryId,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _encryption = EncryptionService();
  late final _fileVault = FileVaultService(_encryption);
  late final _shareExport = ShareExportService(_encryption);
  Future<Uint8List>? _decryptedBytesFuture;
  String? _loadedForPath; // avoids re-decrypting on every rebuild
  bool _sharing = false;
  bool _opening = false;

  /// For file types we can't render inline (docx, xlsx, etc.) — decrypts to
  /// a temp file and hands it to whatever app the device has for that type.
  Future<void> _handleOpenExternally(VaultDocument document) async {
    if (document.encryptedFilePath == null) return;
    setState(() => _opening = true);
    try {
      final bytes = await _fileVault.readDecrypted(document.encryptedFilePath!);
      final extension = document.fileExtension ?? 'bin';
      final safeName = document.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$safeName.$extension');
      await tempFile.writeAsBytes(bytes);

      final result = await OpenFilex.open(tempFile.path);
      if (mounted && result.type.toString() != 'ResultType.done') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _handleShare(VaultDocument document) async {
    if (document.encryptedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file attached to this document yet')),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      await _shareExport.shareDocument(document);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _handleExport(VaultDocument document) async {
    if (document.encryptedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file attached to this document yet')),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      final savedPath = await _shareExport.exportDocument(document);
      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _ensureDecrypted(String? encryptedFilePath) {
    if (encryptedFilePath == null) return;
    if (_loadedForPath == encryptedFilePath) return; // already loading/loaded
    _loadedForPath = encryptedFilePath;
    _decryptedBytesFuture = _fileVault.readDecrypted(encryptedFilePath);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this document?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<DocumentProvider>().deleteDocument(widget.documentId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final document = context
        .watch<DocumentProvider>()
        .byCategory(widget.categoryId)
        .firstWhere((d) => d.id == widget.documentId);

    // Only pre-decrypt for types we actually render inline (image/pdf) —
    // 'file' types are decrypted on demand when "Open file" is tapped.
    if (document.fileType != 'file') {
      _ensureDecrypted(document.encryptedFilePath);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditDocumentScreen(
                  categoryId: widget.categoryId,
                  existingDocument: document,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant, width: 0.6),
              ),
              child: document.encryptedFilePath == null
                  ? Center(
                      child: Icon(Icons.lock_outline, size: 32, color: scheme.onSurfaceVariant),
                    )
                  : document.fileType == 'file'
                      // Can't render docx/xlsx/etc. inline — offer to open
                      // it in whatever app the device has for that type.
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insert_drive_file_outlined,
                                  size: 40, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 10),
                              Text(
                                (document.fileExtension ?? 'FILE').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _opening ? null : () => _handleOpenExternally(document),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(_opening ? 'Opening...' : 'Open file'),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FutureBuilder<Uint8List>(
                            future: _decryptedBytesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState != ConnectionState.done) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                return Center(
                                  child: Icon(Icons.error_outline, color: scheme.error),
                                );
                              }
                              // Decrypted only in memory, for this frame — never
                              // written back to disk unencrypted.
                              return document.fileType == 'pdf'
                                  ? _DecryptedPdfView(bytes: snapshot.data!)
                                  : Image.memory(snapshot.data!, fit: BoxFit.contain);
                            },
                          ),
                        ),
            ),
            const SizedBox(height: 16),
            if (document.subtitle != null)
              Text(document.subtitle!,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : () => _handleShare(document),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Distinct from Share: this opens the native save dialog
                  // to pick an exact folder, rather than sending the file
                  // to another app.
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : () => _handleExport(document),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Export'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Encrypted locally',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders decrypted PDF bytes using pdfx. Kept separate so it can manage
/// its own controller lifecycle (pdfx needs disposing) independently of
/// the detail screen's rebuilds.
class _DecryptedPdfView extends StatefulWidget {
  final Uint8List bytes;

  const _DecryptedPdfView({required this.bytes});

  @override
  State<_DecryptedPdfView> createState() => _DecryptedPdfViewState();
}

class _DecryptedPdfViewState extends State<_DecryptedPdfView> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(document: PdfDocument.openData(widget.bytes));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(controller: _controller);
  }
}