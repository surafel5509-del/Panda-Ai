import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/widgets/main_shell.dart';

/// Root widget: applies the persisted theme and shows the app shell.
class PandaAiStudioApp extends StatelessWidget {
  const PandaAiStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'PANDA AI STUDIO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const MainShell(),
    );
  }
}
