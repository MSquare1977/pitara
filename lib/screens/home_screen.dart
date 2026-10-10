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
import '../theme/app_theme.dart';
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF22386B), AppTheme.navy800, Color(0xFF0E182E)],
                ),
              ),
              child: authProvider.loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.brassLight))
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
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ivory,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    authProvider.user!.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.ivory.withValues(alpha: 0.7),
                                    ),
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
                              const Text(
                                'Pitara',
                                style: TextStyle(
                                  fontFamily: AppTheme.serif,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ivory,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.brassLight,
                                  side: BorderSide(
                                    color: AppTheme.brassLight.withValues(alpha: 0.6),
                                  ),
                                ),
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

  /// "Manish's Vault" once signed in, "Your Vault" otherwise.
  String _vaultTitle(AuthProvider auth) {
    if (!auth.isSignedIn) return 'Your Vault';
    final user = auth.user!;
    final source = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : user.email.split('@').first;
    final first =
        source.split(RegExp(r'[\s._\-]+')).firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (first.isEmpty) return 'Your Vault';
    return "${first[0].toUpperCase()}${first.substring(1)}'s Vault";
  }

  Widget _heroIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        foregroundColor: AppTheme.brassLight,
        minimumSize: const Size(42, 42),
      ),
      icon: Icon(icon, size: 20),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.brassLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.ivory.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// The bold navy card at the top: greeting, "{Name}'s Vault" with a shield,
  /// the action buttons, and quick facts about what's inside.
  Widget _buildHero(
    BuildContext context,
    DocumentProvider documentProvider,
    List<VaultDocument> expiring,
  ) {
    final auth = context.watch<AuthProvider>();
    final docCount = documentProvider.all.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22386B), AppTheme.navy800, Color(0xFF0E182E)],
        ),
        border: Border.all(color: AppTheme.brassLight.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy800.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _greeting().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brassLight.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (!_editMode) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _heroIconButton(
                      icon: Icons.notifications_outlined,
                      tooltip: 'Alerts',
                      onPressed: () => _showExpiringDialog(context, expiring),
                    ),
                    if (expiring.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B5E),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.navy800, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
              ],
              _heroIconButton(
                icon: _editMode ? Icons.check : Icons.edit_outlined,
                tooltip: _editMode ? 'Done' : 'Edit categories',
                onPressed: () => setState(() => _editMode = !_editMode),
              ),
              const SizedBox(width: 6),
              _heroIconButton(
                icon: Icons.menu,
                tooltip: 'Menu',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _vaultTitle(auth),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.serif,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: AppTheme.ivory,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.verified_user_rounded, size: 26, color: AppTheme.brassLight),
              ],
            ),
          ),
          if (!_editMode) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroPill(Icons.lock_outline, 'Files AES-256 encrypted'),
                  _heroPill(
                    Icons.description_outlined,
                    '$docCount document${docCount == 1 ? '' : 's'}',
                  ),
                  FutureBuilder<int>(
                    future: _storageFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return _heroPill(
                        Icons.storage_outlined,
                        '${formatStorageSize(snapshot.data!)} used',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
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
              _buildHero(context, documentProvider, expiring),
              const SizedBox(height: 16),
              if (!_editMode)
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search documents',
                    prefixIcon: Icon(Icons.search, size: 22, color: scheme.primary),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
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
                            childAspectRatio: 1.15,
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