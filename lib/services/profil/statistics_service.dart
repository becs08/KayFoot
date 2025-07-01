import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📊 STATISTIQUES UTILISATEUR

  /// Calcule les statistiques complètes d'un utilisateur
  Future<Map<String, dynamic>> calculateUserStats(String userId) async {
    try {
      print('📊 Calcul statistiques utilisateur: $userId');

      // Récupérer toutes les réservations de l'utilisateur
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('joueurId', isEqualTo: userId)
          .get();

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

        final heureDebut = data['heureDebut'] as String?;
        final heureFin = data['heureFin'] as String?;
        
        // Vérifier si la réservation est dans le passé
        final isMatchPasse = _isReservationPasse(data);

        // Compter seulement les matchs terminés OU les matchs payés qui sont dans le passé
        if (statut == 'terminee' || (statut == 'payee' && isMatchPasse)) {
          matchsJoues++;

          // Calculer temps de jeu
          if (heureDebut != null && heureFin != null) {
            final duree = _calculerDureeMinutes(heureDebut, heureFin);
            tempsJeuMinutes += duree;
          }

          // Ajouter terrain visité
          final terrainId = data['terrainId'] as String?;
          if (terrainId != null) {
            terrainsVisites.add(terrainId);
          }

          // Ajouter montant dépensé (seulement pour les matchs passés)
          final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
          montantDepense += montant;

          // Mettre à jour dernier match (utiliser la date de réservation, pas de création)
          final dateReservation = (data['date'] as Timestamp?)?.toDate();
          if (dateReservation != null && (dernierMatch == null || dateReservation.isAfter(dernierMatch))) {
            dernierMatch = dateReservation;
          }
        }
      }

      final stats = {
        'matchsJoues': matchsJoues,
        'tempsJeu': (tempsJeuMinutes / 60).round(), // Convertir en heures
        'tempsJeuMinutes': tempsJeuMinutes,
        'terrainsVisites': terrainsVisites.length,
        'montantDepense': montantDepense,
        'dernierMatch': dernierMatch?.toIso8601String(),
        'avisLaisses': avisSnapshot.docs.length,

        // Statistiques avancées
        'moyenneSeanceMinutes': matchsJoues > 0 ? (tempsJeuMinutes / matchsJoues).round() : 0,
        'depenseParMatch': matchsJoues > 0 ? (montantDepense / matchsJoues).round() : 0,
      };

      print('✅ Statistiques calculées: $stats');
      return stats;

    } catch (e) {
      print('❌ Erreur calcul statistiques utilisateur: $e');
      return _getDefaultUserStats();
    }
  }

  /// Met à jour les statistiques d'un utilisateur dans Firestore
  Future<void> updateUserStats(String userId) async {
    try {
      final stats = await calculateUserStats(userId);

      await _firestore.collection('users').doc(userId).update({
        'statistiques': stats,
        'statistiquesMAJ': FieldValue.serverTimestamp(),
      });

      print('✅ Statistiques utilisateur mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour statistiques: $e');
    }
  }

  /// 🏟️ STATISTIQUES TERRAIN

  /// Calcule les statistiques complètes d'un terrain
  Future<Map<String, dynamic>> calculateTerrainStats(String terrainId) async {
    try {
      print('🏟️ Calcul statistiques terrain: $terrainId');

      // Réservations du terrain
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('terrainId', isEqualTo: terrainId)
          .get();

      // Avis du terrain
      final avisSnapshot = await _firestore
          .collection('avis')
          .where('terrainId', isEqualTo: terrainId)
          .get();

      int totalReservations = reservationsSnapshot.docs.length;
      int reservationsTerminees = 0;
      double chiffreAffaires = 0.0;
      Map<String, int> creneauxPopulaires = {};
      Set<String> clientsUniques = {};

      // Analyser les réservations
      for (final doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final statut = data['statut'] as String?;
        final joueurId = data['joueurId'] as String?;
        final heureDebut = data['heureDebut'] as String?;
        final heureFin = data['heureFin'] as String?;

        if (joueurId != null) {
          clientsUniques.add(joueurId);
        }

        // Vérifier si la réservation est dans le passé pour les statistiques de revenus
        final isMatchPasse = _isReservationPasse(data);

        // Compter seulement les réservations terminées OU payées qui sont dans le passé
        if (statut == 'terminee' || (statut == 'payee' && isMatchPasse)) {
          reservationsTerminees++;
          final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
          chiffreAffaires += montant;
        }

        // Analyser créneaux populaires (toutes les réservations confirmées)
        if (heureDebut != null && (statut == 'payee' || statut == 'confirmee' || statut == 'terminee')) {
          final creneau = _getCreneau(heureDebut);
          creneauxPopulaires[creneau] = (creneauxPopulaires[creneau] ?? 0) + 1;
        }
      }

      // Calcul note moyenne et répartition
      Map<int, int> repartitionNotes = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      double noteMoyenne = 0.0;

      if (avisSnapshot.docs.isNotEmpty) {
        int totalNotes = 0;
        for (final doc in avisSnapshot.docs) {
          final note = (doc.data()['note'] as int?) ?? 0;
          totalNotes += note;
          repartitionNotes[note] = (repartitionNotes[note] ?? 0) + 1;
        }
        noteMoyenne = totalNotes / avisSnapshot.docs.length;
      }

      final stats = {
        'totalReservations': totalReservations,
        'reservationsTerminees': reservationsTerminees,
        'tauxCompletion': totalReservations > 0 ? (reservationsTerminees / totalReservations * 100).round() : 0,
        'chiffreAffaires': chiffreAffaires,
        'clientsUniques': clientsUniques.length,
        'noteMoyenne': double.parse(noteMoyenne.toStringAsFixed(1)),
        'nombreAvis': avisSnapshot.docs.length,
        'repartitionNotes': repartitionNotes,
        'creneauxPopulaires': creneauxPopulaires,
        'moyenneParReservation': reservationsTerminees > 0 ? (chiffreAffaires / reservationsTerminees).round() : 0,
      };

      print('✅ Statistiques terrain calculées: $stats');
      return stats;

    } catch (e) {
      print('❌ Erreur calcul statistiques terrain: $e');
      return {};
    }
  }

  /// Met à jour les statistiques d'un terrain
  Future<void> updateTerrainStats(String terrainId) async {
    try {
      final stats = await calculateTerrainStats(terrainId);

      await _firestore.collection('terrains').doc(terrainId).update({
        'notemoyenne': stats['noteMoyenne'] ?? 0.0,
        'nombreAvis': stats['nombreAvis'] ?? 0,
        'totalReservations': stats['totalReservations'] ?? 0,
        'chiffreAffaires': stats['chiffreAffaires'] ?? 0.0,
        'statistiquesMAJ': FieldValue.serverTimestamp(),
      });

      print('✅ Statistiques terrain mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour statistiques terrain: $e');
    }
  }

  /// 🌍 STATISTIQUES GLOBALES

  /// Calcule les statistiques globales de l'application
  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      print('🌍 Calcul statistiques globales');

      // Compter les documents
      final usersSnapshot = await _firestore.collection('users').get();
      final terrainsSnapshot = await _firestore.collection('terrains').get();
      final reservationsSnapshot = await _firestore.collection('reservations').get();
      final avisSnapshot = await _firestore.collection('avis').get();

      // Analyser par rôle
      int joueurs = 0;
      int gerants = 0;
      for (final doc in usersSnapshot.docs) {
        final role = doc.data()['role'] as String?;
        if (role == 'joueur') joueurs++;
        if (role == 'gerant') gerants++;
      }

      // Analyser revenus totaux (seulement pour les matchs passés)
      double revenus = 0.0;
      int reservationsPayees = 0;
      for (final doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final statut = data['statut'] as String?;
        
        // Vérifier si la réservation est dans le passé
        final isMatchPasse = _isReservationPasse(data);
        
        // Compter seulement les réservations terminées OU payées qui sont dans le passé
        if (statut == 'terminee' || (statut == 'payee' && isMatchPasse)) {
          reservationsPayees++;
          final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
          revenus += montant;
        }
      }

      return {
        'totalUtilisateurs': usersSnapshot.docs.length,
        'totalJoueurs': joueurs,
        'totalGerants': gerants,
        'totalTerrains': terrainsSnapshot.docs.length,
        'totalReservations': reservationsSnapshot.docs.length,
        'reservationsPayees': reservationsPayees,
        'totalAvis': avisSnapshot.docs.length,
        'revenuTotal': revenus,
        'moyenneParReservation': reservationsPayees > 0 ? (revenus / reservationsPayees).round() : 0,
      };

    } catch (e) {
      print('❌ Erreur statistiques globales: $e');
      return {};
    }
  }

  /// 🔄 MÉTHODES UTILITAIRES

  /// Vérifie si une réservation est dans le passé
  bool _isReservationPasse(Map<String, dynamic> reservationData) {
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
      print('❌ Erreur vérification date réservation: $e');
      return false;
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

  /// Détermine le créneau d'une heure
  String _getCreneau(String heure) {
    try {
      final h = int.parse(heure.split(':')[0]);
      if (h >= 6 && h < 12) return 'Matin';
      if (h >= 12 && h < 18) return 'Après-midi';
      if (h >= 18 && h < 24) return 'Soirée';
      return 'Nuit';
    } catch (e) {
      return 'Inconnu';
    }
  }

  /// Statistiques par défaut pour un utilisateur
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

  /// 📱 MÉTHODES POUR L'UI

  /// Formate le temps de jeu pour l'affichage
  String formatTempsJeu(int minutes) {
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final heures = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${heures}h${mins}min' : '${heures}h';
    }
  }

  /// Formate un montant en FCFA
  String formatMontant(double montant) {
    return '${montant.toStringAsFixed(0)} FCFA';
  }
}

