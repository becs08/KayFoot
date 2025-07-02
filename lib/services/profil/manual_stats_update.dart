import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'statistics_service.dart';
import 'test_stats_service.dart';

/// Service pour forcer une mise à jour manuelle des statistiques
class ManualStatsUpdate {
  static final ManualStatsUpdate _instance = ManualStatsUpdate._internal();
  factory ManualStatsUpdate() => _instance;
  ManualStatsUpdate._internal();

  final StatisticsService _statsService = StatisticsService();
  final TestStatsService _testStatsService = TestStatsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Force la mise à jour de toutes les statistiques
  Future<void> updateAllStatsNow() async {
    try {
      print('🔄 === MISE À JOUR FORCÉE DE TOUTES LES STATISTIQUES ===');

      // 1. Récupérer tous les utilisateurs
      final usersSnapshot = await _firestore.collection('users').get();
      print('👥 ${usersSnapshot.docs.length} utilisateurs trouvés');

      // 2. Récupérer tous les terrains
      final terrainsSnapshot = await _firestore.collection('terrains').get();
      print('🏟️ ${terrainsSnapshot.docs.length} terrains trouvés');

      // 3. Mettre à jour chaque utilisateur
      for (int i = 0; i < usersSnapshot.docs.length; i++) {
        final doc = usersSnapshot.docs[i];
        print('📊 Mise à jour utilisateur ${i + 1}/${usersSnapshot.docs.length}: ${doc.id}');
        await _statsService.updateUserStats(doc.id);
      }

      // 4. Mettre à jour chaque terrain
      for (int i = 0; i < terrainsSnapshot.docs.length; i++) {
        final doc = terrainsSnapshot.docs[i];
        print('🏟️ Mise à jour terrain ${i + 1}/${terrainsSnapshot.docs.length}: ${doc.id}');
        await _statsService.updateTerrainStats(doc.id);
      }

      print('✅ === MISE À JOUR FORCÉE TERMINÉE ===');

    } catch (e) {
      print('❌ Erreur lors de la mise à jour forcée: $e');
      rethrow;
    }
  }

  /// Met à jour les statistiques d'un utilisateur spécifique
  Future<void> updateUserStatsNow(String userId) async {
    try {
      print('📊 Mise à jour forcée utilisateur: $userId');
      await _statsService.updateUserStats(userId);
      print('✅ Statistiques utilisateur mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour utilisateur $userId: $e');
      rethrow;
    }
  }

  /// Met à jour les statistiques d'un terrain spécifique
  Future<void> updateTerrainStatsNow(String terrainId) async {
    try {
      print('🏟️ Mise à jour forcée terrain: $terrainId');
      await _statsService.updateTerrainStats(terrainId);
      print('✅ Statistiques terrain mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour terrain $terrainId: $e');
      rethrow;
    }
  }

  /// Vérifie le nombre de réservations pour diagnostic
  Future<void> diagnosticReservations() async {
    try {
      print('🔍 === DIAGNOSTIC DES RÉSERVATIONS ===');

      final reservationsSnapshot = await _firestore.collection('reservations').get();
      print('📋 Total réservations: ${reservationsSnapshot.docs.length}');

      Map<String, int> statusCounts = {};
      Map<String, int> userCounts = {};
      Map<String, int> terrainCounts = {};

      for (final doc in reservationsSnapshot.docs) {
        final data = doc.data();

        // Compter par statut
        final statut = data['statut'] as String? ?? 'inconnu';
        statusCounts[statut] = (statusCounts[statut] ?? 0) + 1;

        // Compter par utilisateur
        final userId = data['joueurId'] as String? ?? 'inconnu';
        userCounts[userId] = (userCounts[userId] ?? 0) + 1;

        // Compter par terrain
        final terrainId = data['terrainId'] as String? ?? 'inconnu';
        terrainCounts[terrainId] = (terrainCounts[terrainId] ?? 0) + 1;
      }

      print('📊 Répartition par statut:');
      statusCounts.forEach((statut, count) {
        print('  - $statut: $count');
      });

      print('👥 Nombre d\'utilisateurs actifs: ${userCounts.length}');
      print('🏟️ Nombre de terrains utilisés: ${terrainCounts.length}');

      if (kDebugMode) {
        print('✅ === DIAGNOSTIC TERMINÉ ===');
      }

    } catch (e) {
      print('❌ Erreur diagnostic: $e');
    }
  }

  /// TEST: Met à jour les statistiques avec la version test (inclut futures)
  Future<void> updateUserStatsTestVersion(String userId) async {
    try {
      print('🧪 TEST - Mise à jour stats utilisateur (version test): $userId');
      await _testStatsService.updateUserStatsTest(userId);
      print('✅ Statistiques TEST utilisateur mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour stats TEST: $e');
      rethrow;
    }
  }

  /// TEST: Diagnostic des réservations d'un utilisateur spécifique
  Future<void> diagnosticUserReservations(String userId) async {
    try {
      await _testStatsService.diagnosticUserReservations(userId);
    } catch (e) {
      print('❌ Erreur diagnostic utilisateur: $e');
    }
  }
}
