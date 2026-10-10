import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/document_provider.dart';
import 'providers/member_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/lock_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  // Needed before any plugin (shared_preferences, local_auth) can be used
  // prior to runApp.
  WidgetsFlutterBinding.ensureInitialized();

  final documentProvider = DocumentProvider();
  final categoryProvider = CategoryProvider();
  final memberProvider = MemberProvider();

  // Load persisted data from disk before the UI ever builds, so the first
  // frame already shows real saved documents/categories, not empty state.
  await documentProvider.load();
  await categoryProvider.load();
  await memberProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: documentProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: memberProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Unlike the data providers above, this doesn't need to finish
        // before the first frame — sign-in state can resolve in the
        // background without delaying app startup.
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryRestoreSession()),
      ],
      child: const PitaraApp(),
    ),
  );
}

class PitaraApp extends StatelessWidget {
  const PitaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;

    return MaterialApp(
      title: 'Pitara',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const LockScreen(),
    );
  }
}