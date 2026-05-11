import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:main_amato/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final streetController = TextEditingController();
  final barangayController = TextEditingController();
  final municipalityController = TextEditingController();
  final provinceController = TextEditingController();

  bool isLoading = false;

  bool isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    try {
      setState(() => isLoading = true);

      final credential = await AuthService().register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('customers').doc(uid).set({
        'uid': uid,
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'street': streetController.text.trim(),
        'barangay': barangayController.text.trim(),
        'municipality': municipalityController.text.trim(),
        'province': provinceController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await AuthService().logout();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Register failed';

      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget input(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator:
            validator ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return '$hint is required';
              }
              return null;
            },
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.7),
          errorStyle: GoogleFonts.lexend(
            color: Colors.red.shade700,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget button({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC1C1), Color(0xFFFF8A8A)],
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black26,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.lexend(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    streetController.dispose();
    barangayController.dispose();
    municipalityController.dispose();
    provinceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),

                  Image.asset('assets/images/sakuraImage.png', height: 80),

                  const SizedBox(height: 10),

                  Text(
                    'CREATE ACCOUNT',
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  input(usernameController, 'Username', icon: Icons.person),

                  input(
                    emailController,
                    'Email',
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!isValidEmail(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  input(
                    passwordController,
                    'Password',
                    obscure: true,
                    icon: Icons.lock,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  input(
                    confirmPasswordController,
                    'Confirm Password',
                    obscure: true,
                    icon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm password is required';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  input(
                    phoneController,
                    'Phone Number',
                    keyboardType: TextInputType.phone,
                    icon: Icons.phone,
                  ),

                  input(
                    streetController,
                    'House Number / Street',
                    icon: Icons.home,
                  ),

                  input(
                    barangayController,
                    'Barangay',
                    icon: Icons.location_on,
                  ),

                  input(
                    municipalityController,
                    'Municipality',
                    icon: Icons.location_city,
                  ),

                  input(provinceController, 'Province', icon: Icons.map),

                  const SizedBox(height: 12),

                  button(
                    text: isLoading ? 'CREATING ACCOUNT...' : 'CREATE ACCOUNT',
                    icon: Icons.person_add,
                    onTap: isLoading ? null : register,
                  ),

                  const SizedBox(height: 18),

                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Already have an account? Login',
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
