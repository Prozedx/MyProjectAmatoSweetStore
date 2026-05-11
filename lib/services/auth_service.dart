import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  // Get current user ID
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  // Check if current user is admin
  Future<bool> isAdmin() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    try {
      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();
      return adminDoc.exists;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Register with email and password
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Login with email and password
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'The email is invalid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
