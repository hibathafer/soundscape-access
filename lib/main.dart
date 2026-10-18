import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui/home_screen.dart';

void main() => runApp(const SoundscapeApp());

class SoundscapeApp extends StatelessWidget {
  const SoundscapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soundscape Access',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SoundscapeColors.accent,
          brightness: Brightness.dark,
          surface: SoundscapeColors.background,
        ),
        scaffoldBackgroundColor: SoundscapeColors.background,
        // Fairly large, glanceable type — prd.md > Look and Feel.
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24),
          bodyLarge: TextStyle(fontSize: 17),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
