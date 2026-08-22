import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'state/app_settings.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru_RU', null);

  final databaseService = DatabaseService();
  await databaseService.init();

  final settings = AppSettings();
  await settings.load();

  await NotificationService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: const NivelirApp(),
    ),
  );
}

class NivelirApp extends StatefulWidget {
  const NivelirApp({super.key});

  @override
  State<NivelirApp> createState() => _NivelirAppState();
}

class _NivelirAppState extends State<NivelirApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Смена часового пояса не приходит событием — сверяем при возврате
    // приложения на передний план и при необходимости перепланируем
    // напоминания.
    if (state == AppLifecycleState.resumed) {
      final db = context.read<DatabaseService>();
      NotificationService.instance.rescheduleIfTimezoneChanged(db);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Поверка нивелира',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
