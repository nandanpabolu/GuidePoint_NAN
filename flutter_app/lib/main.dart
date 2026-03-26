import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/terms_screen.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;


  final String initialRoute = termsAccepted ? AppRoutes.scanner : AppRoutes.terms;

  runApp(MyApp(initialRoute: initialRoute));
}

// A class to hold route names as constants to avoid typos.
class AppRoutes {
  static const String terms = '/';
  static const String scanner = '/scanner';
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuidePoint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB19CD9), // Light purple
          foregroundColor: Colors.white,
          elevation: 1.0,
        ),
        fontFamily: 'Times New Roman',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB19CD9), // Light purple
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      routes: {
        AppRoutes.terms: (context) => const TermsScreen(),
        AppRoutes.scanner: (context) => const QRScannerScreen(),
      },
    );
  }
}
