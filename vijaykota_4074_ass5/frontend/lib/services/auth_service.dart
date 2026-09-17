import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  FirebaseAuth? _auth;
  bool _firebaseAvailable = false;

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _firebaseAvailable = true;
    } catch (_) {
      _firebaseAvailable = false;
    }
  }

  bool get isFirebaseAvailable => _firebaseAvailable;

  /// Restores cached session from local storage
  Future<UserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('cached_user');
      final token = prefs.getString('auth_token');
      final mockRole = prefs.getString('mock_role');

      if (mockRole != null) {
        ApiService.setMockRole(mockRole);
      }

      if (token != null) {
        ApiService.setAuthToken(token);
      }

      if (userJson != null) {
        final Map<String, dynamic> map = jsonDecode(userJson);
        return UserModel.fromJson(map);
      }
    } catch (e) {
      // Ignore cache reading error
    }
    return null;
  }

  /// Sign In with Email & Password
  Future<UserModel> signIn(String email, String password) async {
    final trimmedEmail = email.trim().toLowerCase();
    String? idToken;
    String uid = 'uid_${trimmedEmail.hashCode.abs()}';
    String displayName = trimmedEmail.split('@')[0];

    // 1. Try Firebase Authentication
    if (_firebaseAvailable && _auth != null) {
      try {
        final credential = await _auth!.signInWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
        final fbUser = credential.user;
        if (fbUser != null) {
          uid = fbUser.uid;
          displayName = fbUser.displayName ?? displayName;
          idToken = await fbUser.getIdToken();
        }
      } catch (fbErr) {
        // If Firebase Auth throws, pass through unless it's an offline/dev fallback
        if (!fbErr.toString().contains('network') && !fbErr.toString().contains('internal')) {
          rethrow;
        }
      }
    }

    // Fallback token for local testing
    idToken ??= 'jwt_token_${DateTime.now().millisecondsSinceEpoch}';
    ApiService.setAuthToken(idToken);

    // 2. Sync with Backend
    final syncRes = await ApiService.post('/auth/sync-user', body: {
      'uid': uid,
      'email': trimmedEmail,
      'name': displayName,
    });

    UserModel user;
    if (syncRes.success && syncRes.data != null) {
      user = UserModel.fromJson(syncRes.data as Map<String, dynamic>);
    } else {
      // Offline fallback role logic: emails with "admin" get admin
      final role = (trimmedEmail.contains('admin') || trimmedEmail == 'admin@itm.edu') ? 'admin' : 'student';
      user = UserModel(
        uid: uid,
        email: trimmedEmail,
        name: displayName,
        role: role,
      );
    }

    await _persistSession(user, idToken);
    return user;
  }

  /// Register new Student account
  Future<UserModel> register(String email, String password, String name) async {
    final trimmedEmail = email.trim().toLowerCase();
    String? idToken;
    String uid = 'uid_${trimmedEmail.hashCode.abs()}';

    if (_firebaseAvailable && _auth != null) {
      try {
        final credential = await _auth!.createUserWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
        final fbUser = credential.user;
        if (fbUser != null) {
          await fbUser.updateDisplayName(name);
          uid = fbUser.uid;
          idToken = await fbUser.getIdToken();
        }
      } catch (fbErr) {
        if (!fbErr.toString().contains('network') && !fbErr.toString().contains('internal')) {
          rethrow;
        }
      }
    }

    idToken ??= 'jwt_token_${DateTime.now().millisecondsSinceEpoch}';
    ApiService.setAuthToken(idToken);

    // Sync with backend
    final syncRes = await ApiService.post('/auth/sync-user', body: {
      'uid': uid,
      'email': trimmedEmail,
      'name': name.trim(),
    });

    UserModel user;
    if (syncRes.success && syncRes.data != null) {
      user = UserModel.fromJson(syncRes.data as Map<String, dynamic>);
    } else {
      user = UserModel(
        uid: uid,
        email: trimmedEmail,
        name: name.trim(),
        role: 'student',
      );
    }

    await _persistSession(user, idToken);
    return user;
  }

  /// Sign In with Dev / Demo Role (Admin or Student) for instant evaluation
  Future<UserModel> signInDemo(String role) async {
    final bool isAdmin = role == 'admin';
    final String email = isAdmin ? 'admin@itm.edu' : 'student@itm.edu';
    final String name = isAdmin ? 'ITM Administrator' : 'ITM Student';
    final String token = isAdmin ? 'test-admin-token' : 'test-student-token';

    ApiService.setAuthToken(token);
    ApiService.setMockRole(role);

    final syncRes = await ApiService.post('/auth/sync-user', body: {
      'email': email,
      'name': name,
    });

    UserModel user;
    if (syncRes.success && syncRes.data != null) {
      user = UserModel.fromJson(syncRes.data as Map<String, dynamic>);
    } else {
      user = UserModel(
        uid: '${role}_test_uid',
        email: email,
        name: name,
        role: role,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mock_role', role);
    await _persistSession(user, token);
    return user;
  }

  /// Reset Password
  Future<void> sendPasswordReset(String email) async {
    if (_firebaseAvailable && _auth != null) {
      await _auth!.sendPasswordResetEmail(email: email.trim().toLowerCase());
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    if (_firebaseAvailable && _auth != null) {
      try {
        await _auth!.signOut();
      } catch (_) {}
    }

    ApiService.setAuthToken(null);
    ApiService.setMockRole(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
    await prefs.remove('auth_token');
    await prefs.remove('mock_role');
  }

  Future<void> _persistSession(UserModel user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user.toJson()));
    await prefs.setString('auth_token', token);
  }
}
