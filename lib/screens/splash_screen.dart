import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/screens/home_screen.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 启动页：Logo + Slogan，然后进入登录/首页
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      if (EnvConfig.isConfigured) {
        try {
          final isReal = await ApiAuthService.isRealUser;
          if (mounted && isReal) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            );
            return;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF7F0), Color(0xFFF0F8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Text(
                'Hi-Doo',
                style: GoogleFonts.quicksand(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF8C42),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '绘读',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6FB1FC),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '会读，更会说 | Read it, Speak it.',
                style: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
