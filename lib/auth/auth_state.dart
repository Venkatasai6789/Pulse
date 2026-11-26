import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/api_service.dart';
import '../models/models.dart';
import 'auth_service.dart';

enum AuthStatus {
  unknown,
  signedOut,
  signingIn,
  signedIn,
  guest,
}

class AuthState extends ChangeNotifier {
  AuthState({
    required this._authService,
    required this._apiService,
    this._apiServiceProvider,
  });

  final AuthService _authService;
  final ApiService _apiService;
  final ApiService Function()? _apiServiceProvider;

  ApiService get _activeApiService => _apiServiceProvider?.call() ?? _apiService;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _error;
  bool _needsProfileSetup = false;
  StreamSubscription<AppUser?>? _userSub;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  AppUser? get currentUser => _user;
  String? get error => _error;
  bool get needsProfileSetup => _needsProfileSetup;
  bool get isLoggedIn => _status == AuthStatus.signedIn || _status == AuthStatus.guest;
  bool get isInitialized => _status != AuthStatus.unknown;
  bool get isLoading => _status == AuthStatus.signingIn;

  void init() {
    debugPrint('[auth] Initializing AuthState and listening to userChanges...');
    _userSub = _authService.userChanges.listen(
      (AppUser? firebaseUser) async {
        debugPrint('[auth] userChanges emitted: ${firebaseUser?.id} (${firebaseUser?.email})');
        if (firebaseUser == null) {
          if (_status != AuthStatus.guest) {
            _user = null;
            _status = AuthStatus.signedOut;
            _needsProfileSetup = false;
            notifyListeners();
          }
        } else {
          // Check if profile exists in ApiService
          AppUser effectiveUser = firebaseUser;
          try {
            final existingProfile = await _activeApiService.currentUser();
            if (existingProfile != null && existingProfile.id == firebaseUser.id) {
              effectiveUser = existingProfile;
              _needsProfileSetup = false;
            } else {
              // First sign-in! Needs profile setup
              _needsProfileSetup = true;
            }
          } catch (e) {
            debugPrint('[auth] Error checking existing profile: $e');
            _needsProfileSetup = true;
          }

          _user = effectiveUser;
          _status = AuthStatus.signedIn;
          _error = null;
          notifyListeners();
        }
      },
      onError: (err) {
        debugPrint('[auth] Error in userChanges stream: $err');
        _status = AuthStatus.signedOut;
        _user = null;
        notifyListeners();
      },
    );
  }

  /// Guest / Demo mode: signs in a local mock user with no Firebase
  void signInGuest() {
    debugPrint('[auth] Entering guest/demo mode');
    _user = const AppUser(
      id: 'demo_user_1',
      name: 'Demo User',
      email: 'demo@pulse.eco',
      organisation: 'Individual',
    );
    _status = AuthStatus.guest;
    _error = null;
    _needsProfileSetup = false;
    notifyListeners();
  }

  /// Sign in with Google with comprehensive error handling
  Future<void> signInWithGoogle() async {
    _status = AuthStatus.signingIn;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        // User canceled or dialog closed without selecting account
        debugPrint('[auth] Google sign-in canceled by user (null returned)');
        _status = AuthStatus.signedOut;
        _error = null;
      }
    } on GoogleSignInException catch (e) {
      debugPrint('[auth] GoogleSignInException caught: code=${e.code}, description=${e.description}');
      final codeStr = e.code.toString().toLowerCase();
      if (codeStr.contains('canceled') || codeStr.contains('cancel') || codeStr == '13') {
        // User closed the account picker
        _error = null;
      } else if (codeStr.contains('clientconfigurationerror') ||
          codeStr.contains('developer_error') ||
          codeStr == '10') {
        _error = "Google sign-in isn't set up correctly on this build.";
      } else {
        _error = "Couldn't sign you in. Please try again.";
      }
      _status = AuthStatus.signedOut;
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth] FirebaseAuthException caught: code=${e.code}, message=${e.message}');
      if (e.code == 'network-request-failed') {
        _error = "You're offline. Check your connection and try again.";
      } else if (e.code == 'user-disabled') {
        _error = "This account has been disabled. Contact support.";
      } else if (e.code == 'invalid-credential' || e.code == 'account-exists-with-different-credential') {
        _error = "Couldn't sign you in. Please try again.";
      } else {
        _error = "Couldn't sign you in. Please try again.";
      }
      _status = AuthStatus.signedOut;
    } catch (e) {
      debugPrint('[auth] Unknown exception caught during sign in: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('canceled') || errStr.contains('cancel')) {
        _error = null;
      } else if (errStr.contains('10') || errStr.contains('developer_error') || errStr.contains('clientconfigurationerror')) {
        _error = "Google sign-in isn't set up correctly on this build.";
      } else {
        _error = "Couldn't sign you in. Please try again.";
      }
      _status = AuthStatus.signedOut;
    } finally {
      notifyListeners();
    }
  }

  /// Complete profile setup for first-time sign-in
  Future<bool> completeProfileSetup({
    required String name,
    String? organisation,
  }) async {
    if (_user == null) return false;
    final updated = AppUser(
      id: _user!.id,
      name: name.trim().isEmpty ? _user!.name : name.trim(),
      email: _user!.email,
      organisation: organisation?.trim(),
      photoUrl: _user!.photoUrl,
    );

    try {
      final saved = await _activeApiService.updateProfile(updated);
      _user = saved;
      _needsProfileSetup = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[auth] Failed to update profile: $e');
      _user = updated;
      _needsProfileSetup = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> updateProfile(AppUser updatedUser) async {
    try {
      final saved = await _activeApiService.updateProfile(updatedUser);
      _user = saved;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    debugPrint('[auth] AuthState signing out');
    _error = null;
    try {
      if (_status != AuthStatus.guest) {
        await _authService.signOut();
      }
    } catch (e) {
      debugPrint('[auth] Error signing out: $e');
    } finally {
      _user = null;
      _status = AuthStatus.signedOut;
      _needsProfileSetup = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
