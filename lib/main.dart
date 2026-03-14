import 'package:echo_reading/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HiDooApp());
}

class HiDooApp extends StatelessWidget {
  const HiDooApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF8C42);
    const secondary = Color(0xFF6FB1FC);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: const Color(0xFFFFF7F0),
    );

    return MaterialApp(
      title: 'Hi-Doo 绘读',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF7F0),
        textTheme: GoogleFonts.quicksandTextTheme(),
        appBarTheme: const AppBarTheme(centerTitle: true),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}
