import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'providers/admin_provider.dart';
import 'providers/attempt_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/exam_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with provided credentials
  try {
    await Firebase.initializeApp(
      options: AppConfig.firebaseOptions,
    );
  } catch (e) {
    // Graceful fallback for environments without live Google Play Services or Web origin mismatch
    debugPrint('[Firebase] Initialization notice: $e');
  }

  runApp(const McqExamApp());
}

class McqExamApp extends StatelessWidget {
  const McqExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
        ChangeNotifierProvider(create: (_) => AttemptProvider()),
      ],
      child: MaterialApp(
        title: AppConfig.portalTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Dynamic routing gate directing users according to authentication status and authoritative role
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Connecting to ITM Skills University Examination Portal...',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.isAdmin) {
      return const AdminDashboardScreen();
    }

    return const StudentDashboardScreen();
  }
}
