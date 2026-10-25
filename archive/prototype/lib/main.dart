import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/storage/services/hive_storage_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.info('Launching RESQ Emergency Mesh System...');

  // Initialize Hive CE Local Database
  await HiveStorageService.init();

  runApp(
    const ProviderScope(
      child: ResqApp(),
    ),
  );
}

class ResqApp extends StatelessWidget {
  const ResqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RESQ Mesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
