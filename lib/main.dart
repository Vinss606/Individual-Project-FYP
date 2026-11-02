import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads Malay month/day names so DateFormat(..., 'ms') works correctly
  // on the Belanjawan and Jualan Rahmah screens.
  await initializeDateFormatting('ms');
  runApp(const MyKasihApp());
}

class MyKasihApp extends StatelessWidget {
  const MyKasihApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Point this at your running FastAPI backend.
    // Android emulator -> 'http://10.0.2.2:8000'
    // iOS simulator / desktop -> 'http://127.0.0.1:8000'
    final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000');

    return MaterialApp(
      title: 'MyKasih',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: LoginScreen(apiService: apiService),
    );
  }
}
