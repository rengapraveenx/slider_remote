import 'package:flutter/material.dart';

import 'server/server.dart';
import 'ui/dashboard.dart';

class DesktopApp extends StatelessWidget {
  const DesktopApp({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    required this.themeMode,
    this.server,
  });

  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final ThemeMode themeMode;
  final SlideServer? server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Slider Remote Host',
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: Dashboard(
        onToggleTheme: onToggleTheme,
        isDarkMode: isDarkMode,
        server: server,
      ),
    );
  }
}
