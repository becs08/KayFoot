import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';
import '../models/auth_result.dart';
import '../constants/app_constants.dart';
import 'firebase_auth_service.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  User? _currentUser;
  String? _authToken;

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;

  /// Initialise le service d'authentification
  Future<void> initialize() async {
    print('🔧 Initialisation AuthService...');
    try {
      final prefs = await SharedPreferences.getInstance();

      // Vérifier si l'utilisateur est connecté avec Firebase
      final firebaseUser = _firebaseAuthService.currentFirebaseUser;
      if (firebaseUser != null) {
        print('🔥 Utilisateur Firebase trouvé: ${firebaseUser.uid}');

        // Récupérer les données depuis Firestore
        final user = await _firebaseAuthService.getCurrentUser();
        if (user != null) {
          _currentUser = user;
          _authToken = await firebaseUser.getIdToken();
          print('✅ Utilisateur chargé depuis Firestore');

          // Sauvegarder dans les préférences locales
          await _saveUserData(user, _authToken!);
        }
      } else {
        print('📴 Aucun utilisateur Firebase connecté');

        // Essayer de récupérer depuis les préférences locales
        final userData = prefs.getString(_userKey);
        if (userData != null) {
          _currentUser = User.fromJson(jsonDecode(userData));
          _authToken = prefs.getString(_tokenKey);
          print('📱 Utilisateur chargé depuis les préférences locales');
        }
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
    }
  }

  /// Inscription d'un nouvel utilisateur
  Future<AuthResult> signUp({
    required String nom,
    required String telephone,
    required String email,
    required String motDePasse,
    required String ville,
    required UserRole role,
  }) async {
    try {
      // Validation des données
      if (!_validatePhone(telephone)) {
        return AuthResult(
          success: false,
          message: 'Numéro de téléphone invalide',
        );
      }

      if (!_validateEmail(email)) {
        return AuthResult(
          success: false,
          message: 'Adresse email invalide',
        );
      }

      if (motDePasse.length < AppConstants.minPasswordLength) {
        return AuthResult(
          success: false,
          message: 'Le mot de passe doit contenir au moins ${AppConstants.minPasswordLength} caractères',
        );
      }

      // Inscription via Firebase
      final result = await _firebaseAuthService.signUp(
        email: email,
        password: motDePasse,
        nom: nom,
        telephone: telephone,
        ville: ville,
        role: role,
      );

      if (result.success && result.user != null) {
        // Obtenir le token
        final token = await _firebaseAuthService.currentFirebaseUser?.getIdToken();
        if (token != null) {
          await _saveUserData(result.user!, token);
        }
      }

      return result;
    } catch (e) {
      print('❌ Erreur dans AuthService.signUp: $e');
      return AuthResult(
        success: false,
        message: 'Erreur lors de l\'inscription: ${e.toString()}',
      );
    }
  }

  /// Connexion d'un utilisateur
  Future<AuthResult> signIn({
    required String identifier, // Email ou téléphone
    required String motDePasse,
  }) async {
    try {
      // Déterminer si c'est un email ou un téléphone
      String email = identifier;
      if (_validatePhone(identifier)) {
        // Si c'est un téléphone, on devrait chercher l'email associé
        // Pour l'instant, on suppose que l'utilisateur entre son email
        return AuthResult(
          success: false,
          message: 'Veuillez utiliser votre email pour vous connecter',
        );
      }

      // Connexion via Firebase
      final result = await _firebaseAuthService.signIn(
        email: email,
        password: motDePasse,
      );

      if (result.success && result.user != null) {
        // Obtenir le token
        final token = await _firebaseAuthService.currentFirebaseUser?.getIdToken();
        if (token != null) {
          await _saveUserData(result.user!, token);
        }
      }

      return result;
    } catch (e) {
      print('❌ Erreur dans AuthService.signIn: $e');
      return AuthResult(
        success: false,
        message: 'Erreur lors de la connexion: ${e.toString()}',
      );
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      // Déconnexion Firebase
      await _firebaseAuthService.signOut();

      // Effacer les données locales
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);

      _currentUser = null;
      _authToken = null;

      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
      throw e;
    }
  }

  /// Mise à jour du profil utilisateur
  Future<AuthResult> updateProfile(User updatedUser) async {
    try {
      final result = await _firebaseAuthService.updateProfile(updatedUser);

      if (result.success && result.user != null) {
        await _saveUserData(result.user!, _authToken!);
      }

      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur lors de la mise à jour: ${e.toString()}',
      );
    }
  }

  /// Mise à jour de la photo de profil uniquement
  Future<AuthResult> updateProfilePhoto(String photoUrl) async {
    try {
      if (_currentUser == null) {
        return AuthResult(
          success: false,
          message: 'Aucun utilisateur connecté',
        );
      }

      // Créer un utilisateur mis à jour avec la nouvelle photo
      final updatedUser = _currentUser!.copyWith(photo: photoUrl);
      
      final result = await _firebaseAuthService.updateProfile(updatedUser);

      if (result.success && result.user != null) {
        await _saveUserData(result.user!, _authToken!);
      }

      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur lors de la mise à jour de la photo: ${e.toString()}',
      );
    }
  }

  /// Réinitialiser le mot de passe
  Future<AuthResult> resetPassword(String email) async {
    try {
      return await _firebaseAuthService.resetPassword(email);
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// Supprimer le compte
  Future<AuthResult> deleteAccount() async {
    try {
      final result = await _firebaseAuthService.deleteAccount();

      if (result.success) {
        await signOut();
      }

      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// Recharger l'utilisateur actuel
  Future<void> reloadCurrentUser() async {
    try {
      final user = await _firebaseAuthService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        final token = await _firebaseAuthService.currentFirebaseUser?.getIdToken();
        if (token != null) {
          _authToken = token;
          await _saveUserData(user, token);
        }
      }
    } catch (e) {
      print('❌ Erreur lors du rechargement de l\'utilisateur: $e');
    }
  }

  /// Sauvegarde des données utilisateur
  Future<void> _saveUserData(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, token);

    _currentUser = user;
    _authToken = token;

    print('💾 Données utilisateur sauvegardées');
  }

  /// Validation du numéro de téléphone
  bool _validatePhone(String phone) {
    return RegExp(AppConstants.phonePattern).hasMatch(phone);
  }

  /// Validation de l'email
  bool _validateEmail(String email) {
    return RegExp(AppConstants.emailPattern).hasMatch(email);
  }

  /// Stream des changements d'authentification
  Stream<User?> get authStateChanges {
    return _firebaseAuthService.authStateChanges.map((appUser) {
      if (appUser != null) {
        _currentUser = appUser;

        // Le token sera obtenu séparément
        // via reloadCurrentUser() qui est appelé après la connexion

        return appUser;
      }
      _currentUser = null;
      _authToken = null;
      return null;
    });
  }
}
