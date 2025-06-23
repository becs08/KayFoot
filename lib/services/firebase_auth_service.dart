import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/user.dart';
import '../models/auth_result.dart';
import 'firebase_auth_wrapper.dart';

// Extension pour ajouter la méthode getIdToken à firebase_auth.User
extension FirebaseUserExtension on firebase_auth.User {
  Future<String?> getIdToken() async {
    try {
      final result = await getIdTokenResult();
      return result.token;
    } catch (e) {
      print('❌ Erreur getIdToken: $e');
      return null;
    }
  }
}

class FirebaseAuthService {
  // Singleton pattern
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  /// Inscription d'un nouvel utilisateur
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nom,
    required String telephone,
    required String ville,
    required UserRole role,
  }) async {
    try {
      print('📝 === DÉBUT INSCRIPTION (Méthode Alternative) ===');
      print('📝 Email: $email');
      print('📝 Nom: $nom');
      print('📝 Téléphone: $telephone');
      print('📝 Ville: $ville');
      print('📝 Role: $role');

      // Étape 1: Créer le compte Firebase Auth
      print('📝 Création du compte Firebase...');
      final uid = await FirebaseAuthWrapper.createAccount(email, password);

      if (uid == null) {
        return AuthResult(
          success: false,
          message: 'Échec de la création du compte. Email peut-être déjà utilisé.',
        );
      }

      print('✅ Compte Firebase créé avec UID: $uid');

      // Étape 2: Créer le document Firestore
      print('📝 Création du document utilisateur...');
      final docCreated = await FirebaseAuthWrapper.createUserDocument(
        uid: uid,
        nom: nom,
        email: email,
        telephone: telephone,
        ville: ville,
        role: role,
      );

      if (!docCreated) {
        return AuthResult(
          success: false,
          message: 'Erreur lors de la création du profil utilisateur',
        );
      }

      print('✅ Document utilisateur créé');

      // Étape 3: Récupérer l'utilisateur créé
      final user = User(
        id: uid,
        nom: nom,
        telephone: telephone,
        email: email,
        ville: ville,
        role: role,
        dateCreation: DateTime.now(),
        statistiques: {},
      );

      return AuthResult(
        success: true,
        message: 'Inscription réussie',
        user: user,
      );
    } catch (e) {
      print('❌ Erreur inscription: $e');
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// Connexion d'un utilisateur
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 === DÉBUT CONNEXION (Méthode Alternative) ===');
      print('🔐 Email: $email');

      // Étape 1: Se connecter avec Firebase Auth
      print('🔐 Connexion Firebase...');
      final uid = await FirebaseAuthWrapper.signIn(email, password);

      if (uid == null) {
        return AuthResult(
          success: false,
          message: 'Email ou mot de passe incorrect',
        );
      }

      print('✅ Connexion réussie avec UID: $uid');

      // Étape 2: Récupérer les données utilisateur
      print('📊 Récupération des données utilisateur...');
      final user = await FirebaseAuthWrapper.getUserFromFirestore(uid);

      if (user == null) {
        print('⚠️ Utilisateur non trouvé dans Firestore, création d\'un profil par défaut...');

        // Créer un profil par défaut
        await FirebaseAuthWrapper.createUserDocument(
          uid: uid,
          nom: 'Utilisateur',
          email: email,
          telephone: '',
          ville: 'Dakar',
          role: UserRole.joueur,
        );

        return AuthResult(
          success: true,
          message: 'Connexion réussie',
          user: User(
            id: uid,
            nom: 'Utilisateur',
            telephone: '',
            email: email,
            ville: 'Dakar',
            role: UserRole.joueur,
            dateCreation: DateTime.now(),
            statistiques: {},
          ),
        );
      }

      print('✅ Données utilisateur récupérées');

      return AuthResult(
        success: true,
        message: 'Connexion réussie',
        user: user,
      );
    } catch (e) {
      print('❌ Erreur connexion: $e');
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await FirebaseAuthWrapper.signOut();
      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur déconnexion: $e');
      throw e;
    }
  }

  /// Récupérer l'utilisateur actuel
  Future<User?> getCurrentUser() async {
    try {
      final uid = FirebaseAuthWrapper.getCurrentUserId();
      if (uid == null) return null;

      return await FirebaseAuthWrapper.getUserFromFirestore(uid);
    } catch (e) {
      print('❌ Erreur getCurrentUser: $e');
      return null;
    }
  }

  /// Mettre à jour le profil
  Future<AuthResult> updateProfile(User user) async {
    try {
      await FirebaseAuthWrapper.createUserDocument(
        uid: user.id,
        nom: user.nom,
        email: user.email,
        telephone: user.telephone,
        ville: user.ville,
        role: user.role,
      );

      return AuthResult(
        success: true,
        message: 'Profil mis à jour',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// Stream des changements d'authentification
  Stream<User?> get authStateChanges {
    return FirebaseAuthWrapper.authStateChanges().asyncMap((uid) async {
      if (uid == null) return null;
      return await FirebaseAuthWrapper.getUserFromFirestore(uid);
    });
  }

  /// Obtenir l'utilisateur Firebase actuel (pour compatibilité)
  String? get currentFirebaseUserId => FirebaseAuthWrapper.getCurrentUserId();

  /// Obtenir l'utilisateur Firebase actuel
  firebase_auth.User? get currentFirebaseUser => firebase_auth.FirebaseAuth.instance.currentUser;

  /// Réinitialiser le mot de passe
  Future<AuthResult> resetPassword(String email) async {
    try {
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: 'Un email de réinitialisation a été envoyé à $email',
      );
    } catch (e) {
      print('❌ Erreur resetPassword: $e');
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// Supprimer le compte
  Future<AuthResult> deleteAccount() async {
    try {
      final uid = FirebaseAuthWrapper.getCurrentUserId();
      if (uid == null) {
        return AuthResult(
          success: false,
          message: 'Aucun utilisateur connecté',
        );
      }

      // Supprimer le document Firestore
      try {
        // Utiliser une méthode directe pour supprimer le document
        final user = currentFirebaseUser;
        if (user != null) {
          await user.delete();
        }
      } catch (e) {
        print('❌ Erreur lors de la suppression du compte: $e');
        return AuthResult(
          success: false,
          message: 'Erreur: ${e.toString()}',
        );
      }

      return AuthResult(
        success: true,
        message: 'Compte supprimé avec succès',
      );
    } catch (e) {
      print('❌ Erreur deleteAccount: $e');
      return AuthResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }
}
