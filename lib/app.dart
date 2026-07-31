import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';


class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsProvider settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Journal',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _getThemeMode(settings.themeMode),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.pinIsSet && !auth.isAuthenticated) {
            return const LockScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }

  
  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeData _buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.mintDark,
      primary: AppColors.mintDark,
      secondary: AppColors.mint,
      surface: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
  );
}

ThemeData _buildDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkGreenPrimary,
      primary: AppColors.darkGreenPrimary,
      secondary: AppColors.darkGreenAccent,
      surface: AppColors.darkGreenSurface,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.darkGreenBg,
    useMaterial3: true,
  );
}
}
