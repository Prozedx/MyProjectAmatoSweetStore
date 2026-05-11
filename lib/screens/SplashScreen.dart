import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:main_amato/Pages/HomePage.dart';
import 'package:main_amato/screens/MenuPageScreen.dart';
import 'package:main_amato/admin/admin_main_page.dart';
import 'package:main_amato/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _redirectAfterSplash);
  }

  Future<void> _redirectAfterSplash() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      if (!mounted) return;

      if (adminDoc.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminMainPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuPageScreen()),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/SplashScreen.png', width: 160),
              const SizedBox(height: 16),
              Text(
                "AMATO",
                style: GoogleFonts.lexendZetta(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 10,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),
              const Text(
                "SWEET DESSERTS JAPANESE STORE",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
