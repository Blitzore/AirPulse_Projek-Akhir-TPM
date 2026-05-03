import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tzLocal;
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  tz.initializeTimeZones();
  tzLocal.setLocalLocation(tzLocal.getLocation('Asia/Jakarta'));
  await NotificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root widget aplikasi AirPulse.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          primary: const Color(0xFF0077B6),
          secondary: const Color(0xFF00B4D8),
          surface: const Color(0xFFF8F9FA),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF03045E),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
