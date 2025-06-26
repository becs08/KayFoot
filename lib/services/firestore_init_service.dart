// 🌱 SERVICE D'INITIALISATION - SANS MIGRATION D'UTILISATEURS
// Fichier: lib/services/firestore_init_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sama_minifoot/services/terrain_service.dart';
import '../models/user.dart';
import '../models/terrain.dart';
import '../models/avis.dart';

class FirestoreInitService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialise seulement les terrains (les utilisateurs sont modifiés manuellement)
  static Future<void> initializeTestData() async {
    try {
      print('🌱 Initialisation des terrains de test...');
      print('👥 Note: Utilisateurs existants préservés (modification manuelle)');

      // Vérifier si les terrains existent déjà
      final terrainsSnapshot = await _firestore.collection('terrains').limit(1).get();
      if (terrainsSnapshot.docs.isNotEmpty) {
        print('✅ Terrains déjà initialisés');
        
        // Toujours recréer les avis pour corriger le problème
        await _createTestAvis();
        
        await _showIndexInstructions(); // Toujours afficher les instructions index
        return;
      }

      // Afficher les stats des utilisateurs existants
      await _showExistingUsersStats();

      // Créer les terrains de test
      await _createTestTerrains();

      // Créer des avis de test
      await _createTestAvis();

      // Afficher les instructions pour les index
      await _showIndexInstructions();

      print('✅ Terrains de test créés avec succès');
      print('💡 Les nouveaux utilisateurs auront automatiquement la structure complète');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }

  /// Affiche les statistiques des utilisateurs existants
  static Future<void> _showExistingUsersStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      if (usersSnapshot.docs.isEmpty) {
        print('ℹ️ Aucun utilisateur existant');
        return;
      }

      int joueurs = 0;
      int gerants = 0;
      int withPhoto = 0;
      int withStats = 0;
      int active = 0;

      print('\n📊 UTILISATEURS EXISTANTS:');
      print('${'Nom'.padRight(20)} | ${'Rôle'.padRight(8)} | Photo | Stats | Actif');
      print('-' * 60);

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final nom = (data['nom'] as String? ?? 'Nom manquant').padRight(20);
        final role = (data['role'] as String? ?? 'Inconnu').padRight(8);
        final hasPhoto = data.containsKey('photo') ? '✅' : '❌';
        final hasStats = data.containsKey('statistiques') ? '✅' : '❌';
        final isActive = data.containsKey('isActive') ? '✅' : '❌';

        print('$nom | $role | $hasPhoto     | $hasStats     | $isActive');

        // Compter
        if (data['role'] == 'joueur') joueurs++;
        if (data['role'] == 'gerant') gerants++;
        if (data.containsKey('photo')) withPhoto++;
        if (data.containsKey('statistiques')) withStats++;
        if (data.containsKey('isActive')) active++;
      }

      print('\n📈 RÉSUMÉ:');
      print('👥 Total utilisateurs: ${usersSnapshot.docs.length}');
      print('🎮 Joueurs: $joueurs');
      print('🏢 Gérants: $gerants');
      print('📸 Avec champ photo: $withPhoto');
      print('📊 Avec statistiques: $withStats');
      print('🟢 Avec isActive: $active');

      final missingFields = usersSnapshot.docs.length - withStats;
      if (missingFields > 0) {
        print('\n⚠️ $missingFields utilisateur(s) à modifier manuellement dans Firebase Console');
        print('💡 Nouveaux utilisateurs auront automatiquement tous les champs');
      } else {
        print('\n✅ Tous les utilisateurs ont la structure complète !');
      }

    } catch (e) {
      print('❌ Erreur lecture utilisateurs: $e');
    }
  }

  /// Récupère un gérant disponible pour créer les terrains
  static Future<String> _getAvailableGerantId() async {
    // Chercher un gérant existant
    final gerantsQuery = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'gerant')
        .limit(1)
        .get();

    if (gerantsQuery.docs.isNotEmpty) {
      final gerantId = gerantsQuery.docs.first.id;
      print('📋 Utilisation du gérant existant: $gerantId');
      return gerantId;
    }

    // Si aucun gérant, créer un gérant temporaire avec structure complète
    print('⚠️ Aucun gérant trouvé, création d\'un gérant temporaire...');
    final gerantRef = await _firestore.collection('users').add({
      'nom': 'Gérant Test Automatique',
      'telephone': '771111111',
      'email': 'gerant.auto@test.com',
      'ville': 'Dakar',
      'role': 'gerant',
      'photo': null,                          // ← Nouveau champ
      'isActive': true,                       // ← Nouveau champ
      'statistiques': {                       // ← Nouveau champ avec stats gérant
        'terrainsGeres': 0,
        'reservationsRecues': 0,
        'chiffreAffaires': 0,
        'noteMoyenne': 0.0,
      },
      'dateCreation': FieldValue.serverTimestamp(),
    });

    print('✅ Gérant temporaire créé avec structure complète');
    return gerantRef.id;
  }

  /// Crée des terrains de test
  static Future<void> _createTestTerrains() async {
    print('🏟️ Création des terrains de test...');

    // Récupérer un gérant disponible
    final gerantId = await _getAvailableGerantId();

    final terrains = [
      {
        'nom': 'Terrain Excellence Dakar',
        'description': 'Terrain de minifoot moderne avec éclairage LED et vestiaires. Idéal pour les matchs en soirée.',
        'ville': 'Dakar',
        'adresse': 'Plateau, Avenue Léopold Sédar Senghor',
        'geolocation': const GeoPoint(14.6937, -17.4441),
        'gerantId': gerantId,
        'photos': [
          'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800',
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
        ],
        'equipements': ['Éclairage LED', 'Vestiaires', 'Douches', 'Parking', 'Sécurité', 'Buvette'],
        'prixHeure': 15000,
        'disponibilites': {
          'lundi': ['08:00-09:00', '09:00-10:00', '16:00-17:00', '17:00-18:00', '18:00-19:00'],
          'mardi': ['08:00-09:00', '10:00-11:00', '16:00-17:00', '17:00-18:00', '19:00-20:00'],
          'mercredi': ['09:00-10:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00'],
          'jeudi': ['08:00-09:00', '09:00-10:00', '17:00-18:00', '18:00-19:00', '20:00-21:00'],
          'vendredi': ['15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00'],
          'samedi': ['09:00-10:00', '10:00-11:00', '14:00-15:00', '15:00-16:00', '16:00-17:00'],
          'dimanche': ['10:00-11:00', '11:00-12:00', '15:00-16:00', '16:00-17:00'],
        },
        'notemoyenne': 4.5,
        'nombreAvis': 12,
        'isActive': true,
        'dateCreation': FieldValue.serverTimestamp(),
      },
      {
        'nom': 'Stade Municipal Thiès',
        'description': 'Terrain communautaire avec gradins pour les spectateurs. Terrain naturel bien entretenu.',
        'ville': 'Thiès',
        'adresse': 'Centre-ville, Route de Mbour',
        'geolocation': const GeoPoint(14.7886, -16.9361),
        'gerantId': gerantId,
        'photos': [
          'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800',
        ],
        'equipements': ['Gradins', 'Toilettes', 'Buvette', 'Terrain naturel', 'Parking'],
        'prixHeure': 12000,
        'disponibilites': {
          'lundi': ['07:00-08:00', '16:00-17:00', '17:00-18:00'],
          'mardi': ['07:00-08:00', '08:00-09:00', '16:00-17:00', '18:00-19:00'],
          'mercredi': ['07:00-08:00', '17:00-18:00', '18:00-19:00', '19:00-20:00'],
          'jeudi': ['16:00-17:00', '17:00-18:00', '18:00-19:00', '20:00-21:00'],
          'vendredi': ['07:00-08:00', '16:00-17:00', '17:00-18:00', '18:00-19:00'],
          'samedi': ['09:00-10:00', '10:00-11:00', '15:00-16:00', '16:00-17:00'],
          'dimanche': ['09:00-10:00', '15:00-16:00', '16:00-17:00'],
        },
        'notemoyenne': 4.2,
        'nombreAvis': 8,
        'isActive': true,
        'dateCreation': FieldValue.serverTimestamp(),
      },
      {
        'nom': 'Arena Saint-Louis',
        'description': 'Terrain synthétique de haute qualité avec douches et vestiaires modernes.',
        'ville': 'Saint-Louis',
        'adresse': 'Sor, Quartier Nord',
        'geolocation': const GeoPoint(16.0402, -16.4897),
        'gerantId': gerantId,
        'photos': [
          'https://images.unsplash.com/photo-1579952363873-27d3bfad9c0d?w=800',
          'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=800',
        ],
        'equipements': ['Terrain synthétique', 'Douches', 'Vestiaires', 'Éclairage', 'Sécurité'],
        'prixHeure': 18000,
        'disponibilites': {
          'lundi': ['08:00-09:00', '17:00-18:00', '18:00-19:00'],
          'mardi': ['08:00-09:00', '09:00-10:00', '17:00-18:00'],
          'mercredi': ['17:00-18:00', '18:00-19:00', '19:00-20:00'],
          'jeudi': ['08:00-09:00', '17:00-18:00', '19:00-20:00'],
          'vendredi': ['15:00-16:00', '16:00-17:00', '17:00-18:00', '19:00-20:00'],
          'samedi': ['09:00-10:00', '10:00-11:00', '14:00-15:00', '15:00-16:00'],
          'dimanche': ['10:00-11:00', '15:00-16:00', '16:00-17:00'],
        },
        'notemoyenne': 4.8,
        'nombreAvis': 15,
        'isActive': true,
        'dateCreation': FieldValue.serverTimestamp(),
      },
      {
        'nom': 'Complex Sportif Kaolack',
        'description': 'Nouveau terrain avec équipements modernes au coeur de Kaolack.',
        'ville': 'Kaolack',
        'adresse': 'Quartier Médina, près du marché central',
        'geolocation': const GeoPoint(14.1592, -16.0729),
        'gerantId': gerantId,
        'photos': [
          'https://images.unsplash.com/photo-1541252260730-0412e8e2108e?w=800',
        ],
        'equipements': ['Éclairage', 'Vestiaires', 'Terrain synthétique', 'Parking'],
        'prixHeure': 10000,
        'disponibilites': {
          'lundi': ['07:00-08:00', '17:00-18:00', '18:00-19:00'],
          'mardi': ['07:00-08:00', '17:00-18:00', '19:00-20:00'],
          'mercredi': ['17:00-18:00', '18:00-19:00'],
          'jeudi': ['07:00-08:00', '18:00-19:00', '19:00-20:00'],
          'vendredi': ['16:00-17:00', '17:00-18:00', '18:00-19:00'],
          'samedi': ['09:00-10:00', '15:00-16:00', '16:00-17:00'],
          'dimanche': ['15:00-16:00', '16:00-17:00'],
        },
        'notemoyenne': 4.0,
        'nombreAvis': 5,
        'isActive': true,
        'dateCreation': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();

    for (final terrain in terrains) {
      final docRef = _firestore.collection('terrains').doc();
      batch.set(docRef, terrain);
    }

    await batch.commit();
    print('✅ ${terrains.length} terrains de test créés');
  }

  /// Affiche les instructions pour créer les index
  static Future<void> _showIndexInstructions() async {
    print('');
    print('📊 INDEX COMPOSITES À CRÉER dans Firebase Console:');
    print('🔗 https://console.firebase.google.com/project/sama-minifoot-2024/firestore/indexes');
    print('');
    print('1. Collection "terrains":');
    print('   - ville (Ascending) + isActive (Ascending)');
    print('   - gerantId (Ascending) + isActive (Ascending)');
    print('   - notemoyenne (Descending) + isActive (Ascending)');
    print('');
    print('2. Collection "reservations" (à créer plus tard):');
    print('   - joueurId (Ascending) + dateCreation (Descending)');
    print('   - terrainId (Ascending) + date (Ascending)');
    print('   - gerantId (Ascending) + statut (Ascending)');
    print('');
    print('3. Collection "avis":');
    print('   - terrainId (Ascending) + dateCreation (Descending)');
    print('   - joueurId (Ascending) + dateCreation (Descending)');
    print('   - reservationId (Ascending) + joueurId (Ascending)');
    print('');
  }

  /// Crée des avis de test pour les terrains
  static Future<void> _createTestAvis() async {
    try {
      print('💬 Création des avis de test...');

      // Supprimer les anciens avis et recréer avec la bonne structure
      print('🗑️ Suppression des anciens avis...');
      final oldAvisSnapshot = await _firestore.collection('avis').get();
      final batch = _firestore.batch();
      for (final doc in oldAvisSnapshot.docs) {
        batch.delete(doc.reference);
      }
      if (oldAvisSnapshot.docs.isNotEmpty) {
        await batch.commit();
        print('✅ Anciens avis supprimés');
      }

      // Récupérer les terrains pour les lier aux avis
      final terrainsSnapshot = await _firestore.collection('terrains').get();
      if (terrainsSnapshot.docs.isEmpty) {
        print('⚠️ Aucun terrain trouvé pour créer des avis');
        return;
      }

      // Récupérer quelques utilisateurs pour créer des avis
      final usersSnapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'joueur')
          .limit(3)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        print('⚠️ Aucun joueur trouvé pour créer des avis');
        return;
      }

      final List<Avis> avisTest = [];
      int avisCounter = 1;

      // Créer des avis pour chaque terrain avec le nouveau modèle
      for (final terrainDoc in terrainsSnapshot.docs.take(3)) {
        for (final userDoc in usersSnapshot.docs) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final avis = Avis(
            id: 'avis_test_$avisCounter',
            utilisateurId: userDoc.id,
            utilisateurNom: userData['nom'] ?? 'Utilisateur $avisCounter',
            terrainId: terrainDoc.id,
            note: (3 + (avisCounter % 3)), // Notes entre 3 et 5
            commentaire: _getRandomComment(avisCounter),
            dateCreation: DateTime.now().subtract(Duration(days: avisCounter * 2)),
          );
          avisTest.add(avis);
          avisCounter++;
        }
      }

      // Sauvegarder les avis dans Firestore
      final newBatch = _firestore.batch();
      for (final avis in avisTest) {
        final docRef = _firestore.collection('avis').doc(avis.id);
        newBatch.set(docRef, avis.toFirestore());
      }

      await newBatch.commit();

      print('✅ ${avisTest.length} avis de test créés');

      // Mettre à jour les notes moyennes des terrains
      await _updateTerrainsRatings();

    } catch (e) {
      print('❌ Erreur lors de la création des avis: $e');
    }
  }

  /// Met à jour les notes moyennes des terrains basées sur les avis
  static Future<void> _updateTerrainsRatings() async {
    try {
      final terrainsSnapshot = await _firestore.collection('terrains').get();

      for (final terrainDoc in terrainsSnapshot.docs) {
        final avisSnapshot = await _firestore
            .collection('avis')
            .where('terrainId', isEqualTo: terrainDoc.id)
            .get();

        if (avisSnapshot.docs.isNotEmpty) {
          final notes = avisSnapshot.docs
              .map((doc) => (doc.data()['note'] as int).toDouble())
              .toList();

          final noteMoyenne = notes.reduce((a, b) => a + b) / notes.length;

          await terrainDoc.reference.update({
            'noteMoyenne': double.parse(noteMoyenne.toStringAsFixed(1)),
            'nombreAvis': notes.length,
          });
        }
      }

      print('✅ Notes moyennes des terrains mises à jour');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des notes: $e');
    }
  }

  /// Retourne un commentaire aléatoire pour les avis de test
  static String _getRandomComment(int index) {
    final comments = [
      'Excellent terrain, très bien entretenu !',
      'Bon terrain mais pourrait être mieux éclairé.',
      'Parfait pour jouer entre amis, recommandé !',
      'Terrain correct, vestiaires propres.',
      'Très bon accueil, terrain en bon état.',
      'Prix raisonnable, qualité correcte.',
      'Super expérience, on reviendra !',
      'Terrain un peu dur mais jouable.',
      'Excellente infrastructure, très propre.',
      'Bon rapport qualité-prix.',
    ];

    return comments[index % comments.length];
  }
}

// 🎯 EXTENSION POUR FIRESTORE
extension FirestoreInitExtension on FirebaseFirestore {
  Future<void> initTestDataNoMigration() async {
    await FirestoreInitService.initializeTestData();
  }
}
