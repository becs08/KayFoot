import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../constants/app_constants.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  User? _currentUser;
  String? _authToken;
  
  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  
  /// Initialise le service d'authentification
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Récupérer l'utilisateur stocké
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      _currentUser = User.fromJson(jsonDecode(userData));
    }
    
    // Récupérer le token
    _authToken = prefs.getString(_tokenKey);
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
      
      // Simuler l'inscription (remplacer par un appel API réel)
      await Future.delayed(Duration(seconds: 2));
      
      // Créer l'utilisateur
      final user = User(
        id: _generateId(),
        nom: nom,
        telephone: telephone,
        email: email,
        ville: ville,
        role: role,
        dateCreation: DateTime.now(),
      );
      
      // Générer un token (à remplacer par la réponse du serveur)
      final token = _generateToken();
      
      // Sauvegarder localement
      await _saveUserData(user, token);
      
      return AuthResult(
        success: true,
        message: 'Inscription réussie',
        user: user,
      );
    } catch (e) {
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
      // Simuler la connexion (remplacer par un appel API réel)
      await Future.delayed(Duration(seconds: 2));
      
      // Utilisateur de test
      final user = User(
        id: 'test_user_id',
        nom: 'Utilisateur Test',
        telephone: '771234567',
        email: 'test@example.com',
        ville: 'Dakar',
        role: UserRole.joueur,
        dateCreation: DateTime.now(),
      );
      
      final token = _generateToken();
      
      // Sauvegarder localement
      await _saveUserData(user, token);
      
      return AuthResult(
        success: true,
        message: 'Connexion réussie',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur lors de la connexion: ${e.toString()}',
      );
    }
  }
  
  /// Déconnexion
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    
    _currentUser = null;
    _authToken = null;
  }
  
  /// Mise à jour du profil utilisateur
  Future<AuthResult> updateProfile(User updatedUser) async {
    try {
      // Simuler la mise à jour (remplacer par un appel API réel)
      await Future.delayed(Duration(seconds: 1));
      
      await _saveUserData(updatedUser, _authToken!);
      
      return AuthResult(
        success: true,
        message: 'Profil mis à jour',
        user: updatedUser,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur lors de la mise à jour: ${e.toString()}',
      );
    }
  }
  
  /// Sauvegarde des données utilisateur
  Future<void> _saveUserData(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, token);
    
    _currentUser = user;
    _authToken = token;
  }
  
  /// Validation du numéro de téléphone
  bool _validatePhone(String phone) {
    return RegExp(AppConstants.phonePattern).hasMatch(phone);
  }
  
  /// Validation de l'email
  bool _validateEmail(String email) {
    return RegExp(AppConstants.emailPattern).hasMatch(email);
  }
  
  /// Génération d'un ID unique
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  /// Génération d'un token
  String _generateToken() {
    return 'token_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class AuthResult {
  final bool success;
  final String message;
  final User? user;
  
  AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}