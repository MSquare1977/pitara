import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:flutter_reorderable_grid_view/utils/definitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/document.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/document_provider.dart';
import '../providers/member_provider.dart';
import '../providers/theme_provider.dart';
import '../services/encryption_service.dart';
import '../services/share_export_service.dart';
import '../utils/document_search.dart';
import '../utils/storage_size.dart';
import '../widgets/category_tile.dart';
import '../widgets/document_card.dart';
import 'category_screen.dart';
import 'add_category_screen.dart';
import 'document_detail_screen.dart';
import 'manage_people_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _lastBackupPrefsKey = 'pitara_last_backup_at';

  bool _editMode = false;
  final _scrollController = ScrollController();
  final _gridViewKey = GlobalKey();
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';


  final _shareExport = ShareExportService(EncryptionService());
  DateTime? _lastBackupAt;

  Future<int>? _storageFuture;
  String? _storageCacheKey; // avoids re-scanning files on every rebuild

  void _ensureStorageFuture(List<VaultDocument> documents) {
    final key = documents.map((d) => '${d.id}:${d.encryptedFilePath}').join(',');
    if (_storageCacheKey == key) return;
    _storageCacheKey = key;
    _storageFuture = totalStorageBytes(documents);
  }

  bool _backupLoaded = false; // avoids flashing the reminder banner before we know
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _loadLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupPrefsKey);
    if (!mounted) return;
    setState(() {
      _lastBackupAt = raw == null ? null : DateTime.tryParse(raw);
      _backupLoaded = true;
    });
  }

  Future<void> _recordBackupTime() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupPrefsKey, now.toIso8601String());
    if (mounted) setState(() => _lastBackupAt = now);
  }

  Future<void> _performBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Back up your vault?'),
        content: const Text(
          'This creates a copy of all your documents outside the app so '
          "you don't lose access if the app is ever uninstalled.\n\n"
          'Important: the backup file itself is NOT encrypted — keep it '
          'somewhere private once saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _backingUp = true);
    try {
      final documentProvider = context.read<DocumentProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      await _shareExport.exportFullBackup(
        documents: documentProvider.all,
        categories: categoryProvider.categories,
      );
      await _recordBackupTime();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteCategory(BuildContext context, DocCategory category) {
    final docCount = context.read<DocumentProvider>().countForCategory(category.id);
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Text(
          docCount == 0
              ? "This category has no documents in it. This can't be undone."
              : 'This will also delete $docCount document${docCount == 1 ? '' : 's'} '
                  "inside it. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<DocumentProvider>().deleteCategoryDocuments(category.id);
              await context.read<CategoryProvider>().deleteCategory(category.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExpiringDialog(BuildContext context, List<VaultDocument> expiring) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Expiring soon'),
        content: SizedBox(
          width: double.maxFinite,
          child: expiring.isEmpty
              ? const Text("Nothing needs renewing right now.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: expiring.length,
                  itemBuilder: (context, index) {
                    final doc = expiring[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: Text(doc.title),
                      subtitle: doc.subtitle != null ? Text(doc.subtitle!) : null,
                      onTap: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(
                              documentId: doc.id,
                              categoryId: doc.categoryId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, List<DocCategory> categories) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final expiring = context.watch<DocumentProvider>().expiringSoon;
    final authProvider = context.watch<AuthProvider>();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
              child: authProvider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : authProvider.isSignedIn
                      ? Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: authProvider.user!.photoUrl != null
                                  ? NetworkImage(authProvider.user!.photoUrl!)
                                  : null,
                              child: authProvider.user!.photoUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    authProvider.user!.displayName ?? 'Signed in',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    authProvider.user!.email,
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Pitara',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await authProvider.signIn();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Sign-in failed: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.login, size: 16),
                                label: const Text('Sign in with Google'),
                              ),
                            ],
                          ),
                        ),
            ),
            if (authProvider.isSignedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  authProvider.signOut();
                },
              ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Dark mode'),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggle(),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Alerts'),
              subtitle: Text(
                expiring.isEmpty ? 'Nothing expiring soon' : '${expiring.length} expiring soon',
              ),
              onTap: () {
                Navigator.pop(context);
                _showExpiringDialog(context, expiring);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Back up vault'),
              subtitle: _lastBackupAt == null
                  ? const Text('Never backed up')
                  : Text('Last backup ${_lastBackupAt!.toLocal()}'.split('.').first),
              onTap: () {
                Navigator.pop(context); // close the drawer first
                _performBackup(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('People'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManagePeopleScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentProvider = context.watch<DocumentProvider>();
    final categories = context.watch<CategoryProvider>().categories;
    final scheme = Theme.of(context).colorScheme;
    final expiring = documentProvider.expiringSoon;
    final isSearching = _searchQuery.trim().isNotEmpty;

    _ensureStorageFuture(documentProvider.all);

    final members = context.watch<MemberProvider>().members;
    final searchResults = isSearching
        ? searchDocuments(
            query: _searchQuery,
            documents: documentProvider.all,
            categories: categories,
            members: members,
          )
        : const [];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, categories),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(),
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        const Text('Your vault',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        if (!_editMode)
                          FutureBuilder<int>(
                            future: _storageFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${formatStorageSize(snapshot.data!)} used',
                                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  if (!_editMode) ...[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _showExpiringDialog(context, expiring),
                          icon: const Icon(Icons.notifications_outlined, size: 20),
                          tooltip: 'Alerts',
                        ),
                        if (expiring.isNotEmpty)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: scheme.error,
                                shape: BoxShape.circle,
                                border: Border.all(color: scheme.surface, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _editMode = !_editMode),
                    icon: Icon(_editMode ? Icons.check : Icons.edit_outlined, size: 20),
                    tooltip: _editMode ? 'Done' : 'Edit categories',
                  ),
                  const SizedBox(width: 8),
                  // Dark mode, backup, people all live in here now, instead
                  // of as separate header icons.
                  IconButton.filledTonal(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu, size: 20),
                    tooltip: 'Menu',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_editMode)
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search documents',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                )
              else
                Text(
                  'Tap a tile to rename, hold and drag to reorder, tap × to delete',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: isSearching
                    // Search results — matches on title, category name, or
                    // status (e.g. "renew", "expiring"). Plain keyword
                    // matching today; a real AI-powered version is a
                    // documented next step once an API key is wired up.
                    ? searchResults.isEmpty
                        ? Center(
                            child: Text(
                              'No documents match "$_searchQuery"',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final doc = searchResults[index];
                              return DocumentCard(
                                document: doc,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentDetailScreen(
                                      documentId: doc.id,
                                      categoryId: doc.categoryId,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                    // Responsive column count — on a phone this settles at
                    // 2, but on a tablet's wider screen it steps up to 3/4/5
                    // so tiles stay a sensible size instead of ballooning.
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const targetTileWidth = 170.0;
                          final columns =
                              (constraints.maxWidth / targetTileWidth).floor().clamp(2, 6);
                          final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.4,
                          );

                          return !_editMode
                              // Plain, lightweight grid when just browsing — no drag machinery.
                              ? GridView.builder(
                                  itemCount: categories.length,
                                  gridDelegate: gridDelegate,
                                  itemBuilder: (context, index) {
                                    final category = categories[index];
                                    return CategoryTile(
                                      category: category,
                                      documentCount:
                                          documentProvider.countForCategory(category.id),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CategoryScreen(category: category),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              // Reorderable grid in edit mode, handled by a dedicated package
                              // rather than a hand-rolled drag — it resolves the touch/scroll
                              // gesture conflict properly.
                              : ReorderableBuilder(
                                  scrollController: _scrollController,
                                  onReorder: (ReorderedListFunction reorderedListFunction) {
                                    final newOrder =
                                        reorderedListFunction(categories).cast<DocCategory>();
                                    context.read<CategoryProvider>().reorderAll(newOrder);
                                  },
                                  children: [
                                    for (final category in categories)
                                      CategoryTile(
                                        key: Key(category.id),
                                        category: category,
                                        documentCount:
                                            documentProvider.countForCategory(category.id),
                                        editMode: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AddCategoryScreen(existingCategory: category),
                                          ),
                                        ),
                                        onDelete: () => _confirmDeleteCategory(context, category),
                                      ),
                                  ],
                                  builder: (children) {
                                    return GridView(
                                      key: _gridViewKey,
                                      controller: _scrollController,
                                      gridDelegate: gridDelegate,
                                      children: children,
                                    );
                                  },
                                );
                        },
                      ),
              ),
              if (_editMode) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add category'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManagePeopleScreen()),
                        ),
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: const Text('People'),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_editMode &&
                  !isSearching &&
                  _backupLoaded &&
                  _lastBackupAt == null &&
                  documentProvider.all.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You haven't backed up your vault — uninstalling the "
                          'app would lose access to your documents.',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      TextButton(
                        onPressed: _backingUp ? null : () => _performBackup(context),
                        child: const Text('Back up'),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_editMode && !isSearching && expiring.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: scheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${expiring.first.title} needs renewing soon',
                          style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}