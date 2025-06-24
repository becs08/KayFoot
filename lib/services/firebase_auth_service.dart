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

  /// Inscription d'un nouvel utilisateur avec structure complète
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nom,
    required String telephone,
    required String ville,
    required UserRole role,
  }) async {
    try {
      print('📝 === DÉBUT INSCRIPTION (Structure Complète) ===');
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

      // Étape 2: Créer le document Firestore avec structure complète
      print('📝 Création du document utilisateur complet...');
      final docCreated = await _createCompleteUserDocument(
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

      print('✅ Document utilisateur complet créé');

      // Étape 3: Récupérer l'utilisateur créé
      final user = User(
        id: uid,
        nom: nom,
        telephone: telephone,
        email: email,
        ville: ville,
        role: role,
        photo: null, // Photo ajoutée automatiquement
        dateCreation: DateTime.now(),
        statistiques: _getDefaultStatistics(role), // Statistiques selon le rôle
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

  /// Crée un document utilisateur avec TOUS les champs requis
  Future<bool> _createCompleteUserDocument({
    required String uid,
    required String nom,
    required String email,
    required String telephone,
    required String ville,
    required UserRole role,
  }) async {
    try {
      // Préparer les statistiques selon le rôle
      final statistiques = _getDefaultStatistics(role);

      // Document utilisateur complet
      final userData = {
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'ville': ville,
        'role': role == UserRole.joueur ? 'joueur' : 'gerant',
        'photo': null,                                    // ← NOUVEAU: Photo par défaut
        'isActive': true,                                 // ← NOUVEAU: Actif par défaut
        'statistiques': statistiques,                     // ← NOUVEAU: Stats selon rôle
        'dateCreation': firestore.FieldValue.serverTimestamp(),
      };

      print('📊 Document à créer:');
      print('   - nom: $nom');
      print('   - email: $email');
      print('   - telephone: $telephone');
      print('   - ville: $ville');
      print('   - role: ${role == UserRole.joueur ? 'joueur' : 'gerant'}');
      print('   - photo: null (par défaut)');
      print('   - isActive: true');
      print('   - statistiques: $statistiques');

      await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);

      print('✅ Document utilisateur complet sauvegardé');
      return true;
    } catch (e) {
      print('❌ Erreur createCompleteUserDocument: $e');
      return false;
    }
  }

  /// Retourne les statistiques par défaut selon le rôle
  Map<String, dynamic> _getDefaultStatistics(UserRole role) {
    if (role == UserRole.joueur) {
      return {
        'matchsJoues': 0,
        'tempsJeu': 0,           // en heures
        'terrainsVisites': 0,
        'montantDepense': 0,     // en FCFA
        'dernierMatch': null,
      };
    } else if (role == UserRole.gerant) {
      return {
        'terrainsGeres': 0,
        'reservationsRecues': 0,
        'chiffreAffaires': 0,    // en FCFA
        'noteMoyenne': 0.0,
      };
    } else {
      return {}; // Fallback
    }
  }

  /// Connexion d'un utilisateur (INCHANGÉ)
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
        print('⚠️ Utilisateur non trouvé dans Firestore');
        return AuthResult(
          success: false,
          message: 'Profil utilisateur non trouvé',
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

  /// Déconnexion (INCHANGÉ)
  Future<void> signOut() async {
    try {
      await FirebaseAuthWrapper.signOut();
      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur déconnexion: $e');
      throw e;
    }
  }

  /// Récupérer l'utilisateur actuel (INCHANGÉ)
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

  /// Mettre à jour le profil (AMÉLIORÉ)
  Future<AuthResult> updateProfile(User user) async {
    try {
      // Mise à jour avec préservation des champs existants
      final updateData = {
        'nom': user.nom,
        'telephone': user.telephone,
        'ville': user.ville,
        // Ne pas écraser photo, isActive, statistiques si pas fournis
      };

      if (user.photo != null) {
        updateData['photo'] = user.photo!;
      }

      await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update(updateData);

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

  /// Stream des changements d'authentification (INCHANGÉ)
  Stream<User?> get authStateChanges {
    return FirebaseAuthWrapper.authStateChanges().asyncMap((uid) async {
      if (uid == null) return null;
      return await FirebaseAuthWrapper.getUserFromFirestore(uid);
    });
  }

  /// Obtenir l'utilisateur Firebase actuel (INCHANGÉ)
  String? get currentFirebaseUserId => FirebaseAuthWrapper.getCurrentUserId();

  /// Obtenir l'utilisateur Firebase actuel (INCHANGÉ)
  firebase_auth.User? get currentFirebaseUser => firebase_auth.FirebaseAuth.instance.currentUser;

  /// Réinitialiser le mot de passe (INCHANGÉ)
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

  /// Supprimer le compte (INCHANGÉ)
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
