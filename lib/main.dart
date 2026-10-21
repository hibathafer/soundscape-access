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
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SoundscapeColors.accent,
          brightness: Brightness.light,
          surface: SoundscapeColors.surface,
        ),
        scaffoldBackgroundColor: SoundscapeColors.background,
        // Glanceable type — prd.md > Look and Feel.
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: SoundscapeColors.ink,
          ),
          bodyLarge: TextStyle(fontSize: 17, color: SoundscapeColors.ink),
          bodyMedium: TextStyle(fontSize: 16, color: SoundscapeColors.ink),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
