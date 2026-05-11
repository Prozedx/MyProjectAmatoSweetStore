import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/SplashScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(const AmatoApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Firebase error: $e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class AmatoApp extends StatelessWidget {
  const AmatoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Amato Store',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
