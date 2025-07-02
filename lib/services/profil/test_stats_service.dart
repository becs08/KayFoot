import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service de test pour les statistiques - compte TOUTES les réservations (futures incluses)
class TestStatsService {
  static final TestStatsService _instance = TestStatsService._internal();
  factory TestStatsService() => _instance;
  TestStatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calcule les statistiques d'un utilisateur (VERSION TEST - inclut futures)
  Future<Map<String, dynamic>> calculateUserStatsTest(String userId) async {
    try {
      print('🧪 TEST - Calcul statistiques utilisateur: $userId');

      // Récupérer toutes les réservations de l'utilisateur
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('joueurId', isEqualTo: userId)
          .get();

      print('📋 Réservations trouvées: ${reservationsSnapshot.docs.length}');

      // Récupérer les avis de l'utilisateur
      final avisSnapshot = await _firestore
          .collection('avis')
          .where('utilisateurId', isEqualTo: userId)
          .get();

      int matchsJoues = 0;
      int tempsJeuMinutes = 0;
      Set<String> terrainsVisites = {};
      double montantDepense = 0.0;
      DateTime? dernierMatch;

      // Analyser les réservations
      for (final doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final statut = data['statut'] as String?;

        print('📊 Réservation ${doc.id}: statut=$statut');

        final heureDebut = data['heureDebut'] as String?;
        final heureFin = data['heureFin'] as String?;

        // VERSION TEST: Compter TOUTES les réservations payées/avance (futures incluses)
        if (statut == 'terminee' || statut == 'payee' || statut == 'avance') {
          matchsJoues++;
          print('✅ Match compté: $statut');

          // Calculer temps de jeu
          if (heureDebut != null && heureFin != null) {
            final duree = _calculerDureeMinutes(heureDebut, heureFin);
            tempsJeuMinutes += duree;
            print('⏱️ Durée: ${duree}min');
          }

          // Ajouter terrain visité
          final terrainId = data['terrainId'] as String?;
          if (terrainId != null) {
            terrainsVisites.add(terrainId);
            print('🏟️ Terrain: $terrainId');
          }

          // Ajouter montant dépensé
          final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
          montantDepense += montant;
          print('💰 Montant: ${montant.toInt()} FCFA');

          // Mettre à jour dernier match
          final dateReservation = (data['date'] as Timestamp?)?.toDate();
          if (dateReservation != null && (dernierMatch == null || dateReservation.isAfter(dernierMatch))) {
            dernierMatch = dateReservation;
          }
        } else {
          print('❌ Match non compté: $statut');
        }
      }

      final stats = {
        'matchsJoues': matchsJoues,
        'tempsJeu': (tempsJeuMinutes / 60).round(),
        'tempsJeuMinutes': tempsJeuMinutes,
        'terrainsVisites': terrainsVisites.length,
        'montantDepense': montantDepense,
        'dernierMatch': dernierMatch?.toIso8601String(),
        'avisLaisses': avisSnapshot.docs.length,
        'moyenneSeanceMinutes': matchsJoues > 0 ? (tempsJeuMinutes / matchsJoues).round() : 0,
        'depenseParMatch': matchsJoues > 0 ? (montantDepense / matchsJoues).round() : 0,
      };

      print('✅ Statistiques TEST calculées: $stats');
      return stats;

    } catch (e) {
      print('❌ Erreur calcul statistiques TEST: $e');
      return _getDefaultUserStats();
    }
  }

  /// Met à jour les statistiques d'un utilisateur (VERSION TEST)
  Future<void> updateUserStatsTest(String userId) async {
    try {
      print('🧪 TEST - Mise à jour stats utilisateur: $userId');
      final stats = await calculateUserStatsTest(userId);

      await _firestore.collection('users').doc(userId).update({
        'statistiques': stats,
        'statistiquesMAJ': FieldValue.serverTimestamp(),
      });

      print('✅ Statistiques TEST utilisateur mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour statistiques TEST: $e');
    }
  }

  /// Calcule la durée en minutes entre deux heures
  int _calculerDureeMinutes(String heureDebut, String heureFin) {
    try {
      final debut = TimeOfDay(
        hour: int.parse(heureDebut.split(':')[0]),
        minute: int.parse(heureDebut.split(':')[1]),
      );
      final fin = TimeOfDay(
        hour: int.parse(heureFin.split(':')[0]),
        minute: int.parse(heureFin.split(':')[1]),
      );

      int debutMinutes = debut.hour * 60 + debut.minute;
      int finMinutes = fin.hour * 60 + fin.minute;

      return finMinutes - debutMinutes;
    } catch (e) {
      return 60; // Défaut 1h
    }
  }

  /// Statistiques par défaut
  Map<String, dynamic> _getDefaultUserStats() {
    return {
      'matchsJoues': 0,
      'tempsJeu': 0,
      'tempsJeuMinutes': 0,
      'terrainsVisites': 0,
      'montantDepense': 0.0,
      'dernierMatch': null,
      'avisLaisses': 0,
      'moyenneSeanceMinutes': 0,
      'depenseParMatch': 0,
    };
  }

  /// Diagnostic des réservations pour un utilisateur
  Future<void> diagnosticUserReservations(String userId) async {
    try {
      print('🔍 === DIAGNOSTIC RÉSERVATIONS UTILISATEUR $userId ===');
      
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('joueurId', isEqualTo: userId)
          .get();
      
      print('📋 Total réservations utilisateur: ${reservationsSnapshot.docs.length}');
      
      if (reservationsSnapshot.docs.isEmpty) {
        print('❌ Aucune réservation trouvée pour cet utilisateur');
        return;
      }
      
      for (final doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final statut = data['statut'] as String? ?? 'inconnu';
        final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
        final date = (data['date'] as Timestamp?)?.toDate();
        final heureDebut = data['heureDebut'] as String?;
        final heureFin = data['heureFin'] as String?;
        
        print('📄 Réservation ${doc.id}:');
        print('   - Statut: $statut');
        print('   - Montant: ${montant.toInt()} FCFA');
        print('   - Date: $date');
        print('   - Créneau: $heureDebut - $heureFin');
        
        // Vérifier si dans le passé
        final isPassee = _isReservationPassee(data);
        print('   - Dans le passé: $isPassee');
        print('   ---');
      }
      
    } catch (e) {
      print('❌ Erreur diagnostic utilisateur: $e');
    }
  }

  /// Vérifie si une réservation est dans le passé
  bool _isReservationPassee(Map<String, dynamic> reservationData) {
    try {
      final dateReservation = (reservationData['date'] as Timestamp?)?.toDate();
      final heureFin = reservationData['heureFin'] as String?;
      
      if (dateReservation == null || heureFin == null) {
        return false;
      }
      
      final heureFinParts = heureFin.split(':');
      if (heureFinParts.length != 2) {
        return false;
      }
      
      final dateFinMatch = DateTime(
        dateReservation.year,
        dateReservation.month,
        dateReservation.day,
        int.parse(heureFinParts[0]),
        int.parse(heureFinParts[1]),
      );
      
      return dateFinMatch.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }
}