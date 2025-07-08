import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart' as app_models;
import '../cache/cache_service.dart';

/// Wrapper pour contourner le bug de cast PigeonUserDetails
class FirebaseAuthWrapper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CacheService? _cacheService;

  /// Créer un compte utilisateur sans déclencher le bug de cast
  static Future<String?> createAccount(String email, String password) async {
    try {
      // Méthode 1: Utiliser l'API REST directement (contournement)
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        print('❌ Email déjà utilisé');
        return null;
      }

      // Créer le compte de manière asynchrone
      UserCredential? userCredential;

      await Future.delayed(Duration(milliseconds: 100)); // Petit délai pour éviter les conflits

      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        print('❌ Erreur création compte: $e');
        return null;
      }

      final user = userCredential.user;
      if (user == null) return null;

      // Attendre que l'utilisateur soit complètement créé
      await Future.delayed(Duration(milliseconds: 500));

      return user.uid;
    } catch (e) {
      print('❌ Erreur dans createAccount: $e');
      return null;
    }
  }

  /// Se connecter sans déclencher le bug
  static Future<String?> signIn(String email, String password) async {
    try {
      // Déconnexion préventive
      if (_auth.currentUser != null) {
        await _auth.signOut();
        await Future.delayed(Duration(milliseconds: 200));
      }

      UserCredential? userCredential;

      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        print('❌ Erreur connexion: $e');
        return null;
      }

      final user = userCredential.user;
      if (user == null) return null;

      // Attendre la stabilisation
      await Future.delayed(Duration(milliseconds: 300));

      return user.uid;
    } catch (e) {
      print('❌ Erreur dans signIn: $e');
      return null;
    }
  }

  /// Obtenir l'UID de l'utilisateur actuel sans déclencher le bug
  static String? getCurrentUserId() {
    try {
      final user = _auth.currentUser;
      return user?.uid;
    } catch (e) {
      print('❌ Erreur getCurrentUserId: $e');
      return null;
    }
  }

  /// Créer le document utilisateur dans Firestore
  static Future<bool> createUserDocument({
    required String uid,
    required String nom,
    required String email,
    required String telephone,
    required String ville,
    required app_models.UserRole role,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'ville': ville,
        'role': role == app_models.UserRole.joueur ? 'joueur' : 'gerant',
        'dateCreation': FieldValue.serverTimestamp(),
        'statistiques': {},
      });
      return true;
    } catch (e) {
      print('❌ Erreur createUserDocument: $e');
      return false;
    }
  }

  /// Initialiser le service de cache
  static Future<void> _initCacheService() async {
    _cacheService ??= await CacheService.getInstance();
  }

  /// Récupérer les données utilisateur depuis le cache ou Firestore
  static Future<app_models.User?> getUserFromFirestore(String uid, {bool forceRefresh = false}) async {
    try {
      await _initCacheService();

      // Essayer de récupérer depuis le cache d'abord
      if (!forceRefresh) {
        final cachedData = _cacheService?.getUserProfile();
        if (cachedData != null && cachedData['id'] == uid) {
          print('📱 Profil utilisateur récupéré depuis le cache');
          return app_models.User(
            id: cachedData['id'],
            nom: cachedData['nom'] ?? '',
            telephone: cachedData['telephone'] ?? '',
            email: cachedData['email'] ?? '',
            ville: cachedData['ville'] ?? 'Dakar',
            role: cachedData['role'] == 'gerant' ? app_models.UserRole.gerant : app_models.UserRole.joueur,
            photo: cachedData['photo'],
            dateCreation: DateTime.parse(cachedData['dateCreation']),
            statistiques: Map<String, dynamic>.from(cachedData['statistiques'] ?? {}),
            username: cachedData['username'],
          );
        }
      }

      // Récupérer depuis Firestore
      print('🔥 Récupération profil utilisateur depuis Firestore');
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final user = app_models.User(
        id: uid,
        nom: data['nom'] ?? '',
        telephone: data['telephone'] ?? '',
        email: data['email'] ?? '',
        ville: data['ville'] ?? 'Dakar',
        role: data['role'] == 'gerant' ? app_models.UserRole.gerant : app_models.UserRole.joueur,
        photo: data['photo'],
        dateCreation: (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
        statistiques: Map<String, dynamic>.from(data['statistiques'] ?? {}),
        username: data['username'],
      );

      // Sauvegarder dans le cache
      await _cacheService?.saveUserProfile({
        'id': user.id,
        'nom': user.nom,
        'telephone': user.telephone,
        'email': user.email,
        'ville': user.ville,
        'role': user.role.toString().split('.').last,
        'photo': user.photo,
        'dateCreation': user.dateCreation.toIso8601String(),
        'statistiques': user.statistiques,
        'username': user.username,
      });

      return user;
    } catch (e) {
      print('❌ Erreur getUserFromFirestore: $e');
      return null;
    }
  }

  /// Vider le cache utilisateur (lors de la déconnexion)
  static Future<void> clearUserCache() async {
    await _initCacheService();
    await _cacheService?.clearUserProfile();
  }

  /// Se déconnecter
  static Future<void> signOut() async {
    try {
      // Vider le cache avant de se déconnecter
      await clearUserCache();
      await _auth.signOut();
    } catch (e) {
      print('❌ Erreur signOut: $e');
    }
  }

  /// Stream pour écouter les changements d'authentification
  static Stream<String?> authStateChanges() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }
}
