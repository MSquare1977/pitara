import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../providers/member_provider.dart';
import '../services/encryption_service.dart';
import '../services/file_vault_service.dart';

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};

/// One form for every category. Pass categoryId to add into that category,
/// or pass an existingDocument to edit it.
class AddEditDocumentScreen extends StatefulWidget {
  final String categoryId;
  final VaultDocument? existingDocument;

  const AddEditDocumentScreen({
    super.key,
    required this.categoryId,
    this.existingDocument,
  });

  bool get isEditing => existingDocument != null;

  @override
  State<AddEditDocumentScreen> createState() => _AddEditDocumentScreenState();
}

class _AddEditDocumentScreenState extends State<AddEditDocumentScreen> {
  late final TextEditingController _titleController;
  DateTime? _expiryDate;
  String? _memberId;

  final _fileVault = FileVaultService(EncryptionService());
  final _picker = ImagePicker();

  Uint8List? _pickedBytes; // newly picked file, not yet saved
  String? _pickedFileType; // 'image', 'pdf', or 'file'
  String? _pickedFileExtension; // e.g. 'docx' — only meaningful when fileType == 'file'
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingDocument?.title ?? '');
    _expiryDate = widget.existingDocument?.expiryDate;
    _memberId = widget.existingDocument?.memberId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, size: 20),
              title: const Text('Choose a file'),
              subtitle: const Text('PDF, Word, Excel, or any other document'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'file') {
      // No extension restriction — classification happens after picking,
      // based on whatever extension actually comes back.
      final file = await FilePicker.pickFile();
      final path = file?.path;
      if (path == null) return;

      final extension = path.contains('.') ? path.split('.').last.toLowerCase() : '';
      final bytes = await File(path).readAsBytes();

      setState(() {
        _pickedBytes = bytes;
        if (_imageExtensions.contains(extension)) {
          _pickedFileType = 'image';
          _pickedFileExtension = null;
        } else if (extension == 'pdf') {
          _pickedFileType = 'pdf';
          _pickedFileExtension = null;
        } else {
          _pickedFileType = 'file';
          _pickedFileExtension = extension.isEmpty ? null : extension;
        }
      });
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedFileType = 'image';
      _pickedFileExtension = null;
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final provider = context.read<DocumentProvider>();
    final id = widget.existingDocument?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    String? encryptedFilePath = widget.existingDocument?.encryptedFilePath;
    String? fileType = widget.existingDocument?.fileType;
    String? fileExtension = widget.existingDocument?.fileExtension;

    // Only touch the file if the user actually picked a new one —
    // editing just the title/date shouldn't re-encrypt anything.
    if (_pickedBytes != null) {
      // Replacing an existing file: delete the old encrypted copy first
      // so we don't leave orphaned encrypted files behind.
      if (encryptedFilePath != null) {
        await _fileVault.delete(encryptedFilePath);
      }
      encryptedFilePath = await _fileVault.saveEncrypted(_pickedBytes!, id);
      fileType = _pickedFileType;
      fileExtension = _pickedFileExtension;
    }

    final doc = VaultDocument(
      id: id,
      categoryId: widget.categoryId,
      title: _titleController.text.trim(),
      subtitle: _expiryDate != null
          ? 'Expires ${DateFormat.yMMM().format(_expiryDate!)}'
          : null,
      expiryDate: _expiryDate,
      encryptedFilePath: encryptedFilePath,
      fileType: fileType,
      fileExtension: fileExtension,
      memberId: _memberId,
    );

    widget.isEditing ? await provider.updateDocument(doc) : await provider.addDocument(doc);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasExistingFile =
        !widget.isEditing ? false : widget.existingDocument!.encryptedFilePath != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit document' : 'Add document')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: !widget.isEditing,
              decoration: const InputDecoration(labelText: 'Document title'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined, size: 18),
              title: Text(
                _expiryDate == null
                    ? 'No expiry date'
                    : 'Expires ${DateFormat.yMMMd().format(_expiryDate!)}',
              ),
              trailing: _expiryDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _expiryDate = null),
                    )
                  : null,
              onTap: _pickExpiryDate,
            ),
            Consumer<MemberProvider>(
              builder: (context, memberProvider, _) {
                final members = memberProvider.members;
                if (members.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Shared'),
                        selected: _memberId == null,
                        onSelected: (_) => setState(() => _memberId = null),
                      ),
                      for (final member in members)
                        ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: member.color,
                            radius: 10,
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                          label: Text(member.name),
                          selected: _memberId == member.id,
                          onSelected: (_) => setState(() => _memberId = member.id),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // File attachment preview / picker.
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant, width: 0.6),
                ),
                child: _pickedBytes != null
                    ? (_pickedFileType == 'image'
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pickedFileType == 'pdf'
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 32,
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _pickedFileType == 'pdf'
                                    ? 'PDF selected'
                                    : '${(_pickedFileExtension ?? 'File').toUpperCase()} selected',
                                style:
                                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasExistingFile ? Icons.lock_outline : Icons.add_a_photo_outlined,
                            size: 28,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasExistingFile
                                ? 'Tap to replace the attached file'
                                : 'Tap to attach a photo, scan, or any file',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Encrypting and saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
