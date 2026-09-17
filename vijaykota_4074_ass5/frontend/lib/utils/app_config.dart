import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  // Configurable Backend API Base URL
  // Uses localhost for Web/Desktop, or 10.0.2.2 for Android emulator
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5050/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5050/api';
    }
    return 'http://localhost:5050/api';
  }

  // Firebase Web Options provided for mcq-exam-b768d
  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyA_2oKENZ1BDoWfk0GheylfpKVJtiU292c",
    authDomain: "mcq-exam-b768d.firebaseapp.com",
    projectId: "mcq-exam-b768d",
    storageBucket: "mcq-exam-b768d.firebasestorage.app",
    messagingSenderId: "439345333230",
    appId: "1:439345333230:web:b9a112c23d0445ea9744ff",
    measurementId: "G-3EES0RZ9FN",
  );

  static const String institutionName = "ITM Skills University";
  static const String portalTitle = "ITM MCQ Examination Portal";
}
