import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
import '../services/auth_service.dart';
import 'LoginPage.dart';
import 'register_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final streetController = TextEditingController();
  final barangayController = TextEditingController();
  final municipalityController = TextEditingController();
  final provinceController = TextEditingController();

  final picker = ImagePicker();
  final cloudinaryService = CloudinaryService();

  File? selectedImage;
  String avatarUrl = '';
  bool isLoading = false;
  bool isSaving = false;

  User? get user => AuthService().currentUser;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    if (user == null) return;

    setState(() => isLoading = true);

    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user!.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      usernameController.text = data['username'] ?? '';
      emailController.text = data['email'] ?? user!.email ?? '';
      phoneController.text = data['phone'] ?? '';
      streetController.text = data['street'] ?? '';
      barangayController.text = data['barangay'] ?? '';
      municipalityController.text = data['municipality'] ?? '';
      provinceController.text = data['province'] ?? '';
      avatarUrl = data['avatarUrl'] ?? '';
    }

    setState(() => isLoading = false);
  }

  Future<void> pickAvatar() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> saveProfile() async {
    if (user == null) return;

    try {
      setState(() => isSaving = true);

      String finalAvatarUrl = avatarUrl;

      if (selectedImage != null) {
        finalAvatarUrl = await cloudinaryService.uploadImage(selectedImage!);
      }

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user!.uid)
          .update({
            'username': usernameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'street': streetController.text.trim(),
            'barangay': barangayController.text.trim(),
            'municipality': municipalityController.text.trim(),
            'province': provinceController.text.trim(),
            'avatarUrl': finalAvatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        avatarUrl = finalAvatarUrl;
        selectedImage = null;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> logout() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyWidget()),
      (route) => false,
    );
  }

  void navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyWidget()),
    );
  }

  void navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  Widget input(
    TextEditingController controller,
    String hint, {
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.75),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget mainButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
            Icon(icon, color: Colors.white),
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

  Widget avatar() {
    return GestureDetector(
      onTap: pickAvatar,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 58,
              backgroundColor: Colors.white,
              backgroundImage: selectedImage != null
                  ? FileImage(selectedImage!)
                  : avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: selectedImage == null && avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFFF267AF), size: 55)
                  : null,
            ),
          ),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF267AF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
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
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE5B4), Color(0xFFF267AF)],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(width: 4),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'PROFILE SETTINGS',
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 18),

                      if (user != null) ...[
                        avatar(),
                        const SizedBox(height: 10),
                        Text(
                          'Tap profile picture to edit',
                          style: GoogleFonts.lexend(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 25),
                        input(
                          usernameController,
                          'Username',
                          icon: Icons.person,
                        ),
                        input(emailController, 'Email', icon: Icons.email),
                        input(
                          phoneController,
                          'Phone Number',
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
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 16,
                                color: Colors.black26,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [
                                      Color(0xFFFFE5B4),
                                      Color(0xFFF267AF),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ready to Order?',
                                style: GoogleFonts.lexend(
                                  color: const Color(0xFFF267AF),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create an account to start ordering your favorite sweets!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lexend(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (user != null)
                        mainButton(
                          text: isSaving ? 'SAVING...' : 'SAVE PROFILE',
                          icon: Icons.save,
                          onTap: isSaving ? null : saveProfile,
                        ),

                      if (user != null) const SizedBox(height: 12),

                      if (user == null)
                        mainButton(
                          text: 'CREATE NEW ACCOUNT',
                          icon: Icons.app_registration,
                          onTap: navigateToRegister,
                        ),

                      if (user == null) const SizedBox(height: 12),

                      mainButton(
                        text: user == null ? 'LOG IN' : 'LOGOUT',
                        icon: user == null ? Icons.login : Icons.logout,
                        onTap: user == null ? navigateToLogin : logout,
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
