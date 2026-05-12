import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:main_amato/screens/MenuPageScreen.dart';
import 'package:main_amato/admin/admin_login_page.dart';
import 'package:main_amato/Pages/ForgotPasswordPage.dart';
import 'package:main_amato/Pages/register_page.dart';
import 'package:main_amato/services/auth_service.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;

  bool isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _clearErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    _clearErrors();

    try {
      setState(() => isLoading = true);

      final credential = await AuthService().login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();

      if (adminDoc.exists) {
        await AuthService().logout();

        if (!mounted) return;

        _showMessage('Admin account ito. Use Admin Login.');
        return;
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MenuPageScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';

      switch (e.code) {
        case 'user-not-found':
          message =
              'No account found with this email address. Please check your email or create a new account.';
          setState(() {
            _emailError = 'Email not found';
            isLoading = false;
            _formKey.currentState?.validate();
          });
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          setState(() {
            _passwordError = 'Password is incorrect';
            isLoading = false;
            _formKey.currentState?.validate();
          });
          break;
        case 'invalid-email':
          message = 'Invalid email format. Please enter a valid email address.';
          setState(() {
            _emailError = 'Invalid email format';
            isLoading = false;
            _formKey.currentState?.validate();
          });
          break;
        case 'invalid-credential':
          message =
              'Invalid email or password. Please check both and try again.';
          setState(() {
            _emailError = 'Invalid credentials';
            _passwordError = 'Invalid credentials';
            isLoading = false;
            _formKey.currentState?.validate();
          });
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          setState(() => isLoading = false);
          break;
        case 'account-exists-with-different-credential':
          message =
              'An account exists with this email but with different credentials.';
          setState(() {
            _emailError = 'Account exists with different method';
            isLoading = false;
            _formKey.currentState?.validate();
          });
          break;
        case 'operation-not-allowed':
          message =
              'Email login is currently disabled. Please contact support.';
          setState(() => isLoading = false);
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          setState(() => isLoading = false);
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
          setState(() => isLoading = false);
      }

      if (mounted) {
        _showMessage(message);
      }
    } finally {
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    }
  }

  void _goToForgotPasswordPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordPage(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  void _goToAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginPage()),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  void _continueAsGuest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MenuPageScreen()),
    );
  }

  Widget _mainButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _outlineButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: Colors.white.withValues(alpha: 0.25),
          border: Border.all(color: Colors.white, width: 1.2),
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

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onPasswordToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: onPasswordToggle,
            )
          : null,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.6),
      errorStyle: GoogleFonts.lexend(
        color: Colors.red.shade700,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 55),

                Image.asset('assets/images/sakuraImage.png', height: 90),

                const SizedBox(height: 10),

                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFFF9A9A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    'AMATO',
                    style: GoogleFonts.lexendZetta(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 4,
                          offset: Offset(0, 2),
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'SWEET DESSERTS JAPANESE STORE',
                  style: GoogleFonts.lexend(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  width: 310,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC1C1), Color(0xFFFF8A8A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => _clearErrors(),
                          decoration: inputDecoration(
                            hint: 'EMAIL',
                            icon: Icons.email,
                          ),
                          validator: (value) {
                            if (_emailError != null) {
                              return _emailError;
                            }

                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }

                            if (!isValidEmail(value.trim())) {
                              return 'Enter a valid email';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 15),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !isPasswordVisible,
                          onChanged: (_) => _clearErrors(),
                          decoration: inputDecoration(
                            hint: 'PASSWORD',
                            icon: Icons.lock,
                            isPassword: true,
                            isPasswordVisible: isPasswordVisible,
                            onPasswordToggle: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                          validator: (value) {
                            if (_passwordError != null) {
                              return _passwordError;
                            }

                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }

                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }

                            return null;
                          },
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _goToForgotPasswordPage,
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.lexend(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                _mainButton(
                  text: isLoading ? 'LOGGING IN...' : 'LOG IN AS USER',
                  icon: Icons.person,
                  onTap: isLoading ? null : _loginUser,
                ),

                const SizedBox(height: 12),

                _outlineButton(
                  text: 'CONTINUE AS GUEST',
                  icon: Icons.explore,
                  onTap: _continueAsGuest,
                ),

                const SizedBox(height: 60),

                GestureDetector(
                  onTap: _goToRegister,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        TextSpan(
                          text: 'Create here',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                GestureDetector(
                  onTap: _goToAdminLogin,
                  child: Text(
                    'Admin Login',
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
