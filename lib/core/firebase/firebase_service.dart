import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kDebugMode) {
        print('✅ Firebase initialisé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Firebase: $e');
      }
      rethrow;
    }
  }
}
