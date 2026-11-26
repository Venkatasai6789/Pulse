import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

/// Wraps Firebase Auth and Google Sign-In.
/// No UI code belongs here.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Stream of mapped AppUsers
  Stream<AppUser?> get userChanges {
    return _auth.userChanges().map((User? firebaseUser) {
      if (firebaseUser == null) return null;
      return _mapFirebaseUser(firebaseUser);
    });
  }

  AppUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _mapFirebaseUser(u);
  }

  AppUser _mapFirebaseUser(User user) {
    return AppUser(
      id: user.uid,
      name: (user.displayName != null && user.displayName!.trim().isNotEmpty)
          ? user.displayName!
          : (user.email?.split('@').first ?? 'User'),
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  /// Sign in with Google using google_sign_in v7 and Firebase Auth.
  Future<AppUser?> signInWithGoogle() async {
    debugPrint('[auth] Starting Google sign-in flow...');
    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null) {
        debugPrint('[auth] Google sign-in did not return an idToken');
        throw const AuthException('Google sign-in did not return an ID token');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        debugPrint('[auth] Firebase sign-in completed without user');
        return null;
      }

      debugPrint('[auth] Successfully signed in user: ${firebaseUser.uid} (${firebaseUser.email})');
      return _mapFirebaseUser(firebaseUser);
    } on GoogleSignInException catch (e) {
      debugPrint('[auth] GoogleSignInException: code=${e.code}, description=${e.description}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth] FirebaseAuthException: code=${e.code}, message=${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[auth] Unexpected error during Google sign-in: $e\n$stack');
      rethrow;
    }
  }

  /// Sign out of Firebase Auth and Google Sign-In together.
  Future<void> signOut() async {
    debugPrint('[auth] Signing out of Firebase and Google...');
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      debugPrint('[auth] Sign-out complete');
    } catch (e) {
      debugPrint('[auth] Error during sign-out: $e');
      rethrow;
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
