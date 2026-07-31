import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/storage_service.dart';
import 'screens/boards_list_screen.dart';
import 'state/board_provider.dart';
import 'state/settings_provider.dart';
import 'theme/app_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  runApp(ExpenseApp(storage: storage));
}

class ExpenseApp extends StatelessWidget {
  final StorageService storage;
  const ExpenseApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => BoardProvider(storage)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Expense',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.materialThemeFor(settings.themeIndex),
            home: const BoardsListScreen(),
          );
        },
      ),
    );
  }
}
