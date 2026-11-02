import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/feed_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Caso o arquivo .env não esteja disponível, o ApodService fará fallback para DEMO_KEY.
  }
  runApp(const MyApp());
}

/// Widget raiz da aplicação NASA APOD Feed com Dark Theme espacial consistente.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C7CFA),
      brightness: Brightness.dark,
      surface: const Color(0xFF0B0E17),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0B0E17),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF121726),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF151C2E),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2740),
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        actionTextColor: colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = _buildDarkTheme();

    return MaterialApp(
      title: 'NASA APOD Feed',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: darkTheme,
      darkTheme: darkTheme,
      home: const FeedScreen(),
    );
  }
}
