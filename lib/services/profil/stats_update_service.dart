import 'package:cloud_firestore/cloud_firestore.dart';
import 'statistics_service.dart';

/// Service pour automatiser les mises à jour des statistiques
class StatsUpdateService {
  static final StatsUpdateService _instance = StatsUpdateService._internal();
  factory StatsUpdateService() => _instance;
  StatsUpdateService._internal();

  final StatisticsService _statsService = StatisticsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔄 HOOKS AUTOMATIQUES

  /// Appelé après création d'une réservation
  Future<void> onReservationCreated(String userId, String terrainId) async {
    try {
      print('📊 Mise à jour stats après création réservation');
      
      // Mettre à jour stats utilisateur (asynchrone)
      _updateUserStatsAsync(userId);
      
      // Mettre à jour stats terrain (asynchrone)
      _updateTerrainStatsAsync(terrainId);
      
    } catch (e) {
      print('❌ Erreur onReservationCreated: $e');
    }
  }

  /// Appelé quand une réservation change de statut
  Future<void> onReservationStatusChanged(
    String userId, 
    String terrainId, 
    String oldStatus, 
    String newStatus
  ) async {
    try {
      print('📊 Mise à jour stats après changement statut: $oldStatus → $newStatus');
      
      // Si la réservation est maintenant terminée ou payée (avance incluse)
      if (newStatus == 'terminee' || newStatus == 'payee' || newStatus == 'avance') {
        await _updateUserStatsAsync(userId);
        await _updateTerrainStatsAsync(terrainId);
      }
      
      // Si une réservation payée/avance est annulée
      if ((oldStatus == 'payee' || oldStatus == 'avance') && newStatus == 'annulee') {
        await _updateUserStatsAsync(userId);
        await _updateTerrainStatsAsync(terrainId);
      }
      
    } catch (e) {
      print('❌ Erreur onReservationStatusChanged: $e');
    }
  }

  /// Appelé après ajout d'un avis
  Future<void> onAvisAdded(String userId, String terrainId) async {
    try {
      print('📊 Mise à jour stats après ajout avis');
      
      // Mettre à jour stats utilisateur (nombre d'avis laissés)
      _updateUserStatsAsync(userId);
      
      // Mettre à jour stats terrain (note moyenne, nombre d'avis)
      await _updateTerrainStatsAsync(terrainId);
      
    } catch (e) {
      print('❌ Erreur onAvisAdded: $e');
    }
  }

  /// Appelé après modification d'un avis
  Future<void> onAvisUpdated(String userId, String terrainId) async {
    try {
      print('📊 Mise à jour stats après modification avis');
      
      // Mettre à jour stats terrain (note moyenne change)
      await _updateTerrainStatsAsync(terrainId);
      
    } catch (e) {
      print('❌ Erreur onAvisUpdated: $e');
    }
  }

  /// 🕐 MISES À JOUR PROGRAMMÉES

  /// Met à jour toutes les statistiques (à exécuter périodiquement)
  Future<void> updateAllStats() async {
    try {
      print('🔄 Mise à jour globale des statistiques...');
      
      // Mettre à jour stats de tous les utilisateurs
      final usersSnapshot = await _firestore.collection('users').get();
      for (final doc in usersSnapshot.docs) {
        await _updateUserStatsAsync(doc.id);
      }
      
      // Mettre à jour stats de tous les terrains
      final terrainsSnapshot = await _firestore.collection('terrains').get();
      for (final doc in terrainsSnapshot.docs) {
        await _updateTerrainStatsAsync(doc.id);
      }
      
      print('✅ Mise à jour globale terminée');
      
    } catch (e) {
      print('❌ Erreur updateAllStats: $e');
    }
  }

  /// Met à jour les statistiques d'utilisateurs spécifiques
  Future<void> updateUsersStats(List<String> userIds) async {
    try {
      print('🔄 Mise à jour stats utilisateurs: ${userIds.length}');
      
      for (final userId in userIds) {
        await _updateUserStatsAsync(userId);
      }
      
    } catch (e) {
      print('❌ Erreur updateUsersStats: $e');
    }
  }

  /// Met à jour les statistiques de terrains spécifiques
  Future<void> updateTerrainsStats(List<String> terrainIds) async {
    try {
      print('🔄 Mise à jour stats terrains: ${terrainIds.length}');
      
      for (final terrainId in terrainIds) {
        await _updateTerrainStatsAsync(terrainId);
      }
      
    } catch (e) {
      print('❌ Erreur updateTerrainsStats: $e');
    }
  }

  /// 📊 STATISTIQUES DE CACHE

  /// Vérifie si les stats d'un utilisateur sont récentes
  Future<bool> areUserStatsRecent(String userId, {Duration maxAge = const Duration(hours: 1)}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final data = userDoc.data()!;
      final lastUpdate = (data['statistiquesMAJ'] as Timestamp?)?.toDate();
      
      if (lastUpdate == null) return false;
      
      return DateTime.now().difference(lastUpdate) < maxAge;
      
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si les stats d'un terrain sont récentes
  Future<bool> areTerrainStatsRecent(String terrainId, {Duration maxAge = const Duration(hours: 1)}) async {
    try {
      final terrainDoc = await _firestore.collection('terrains').doc(terrainId).get();
      if (!terrainDoc.exists) return false;
      
      final data = terrainDoc.data()!;
      final lastUpdate = (data['statistiquesMAJ'] as Timestamp?)?.toDate();
      
      if (lastUpdate == null) return false;
      
      return DateTime.now().difference(lastUpdate) < maxAge;
      
    } catch (e) {
      return false;
    }
  }

  /// 🚀 OPTIMISATIONS

  /// Met à jour stats utilisateur de manière asynchrone (non-bloquante)
  Future<void> _updateUserStatsAsync(String userId) async {
    // Exécuter en arrière-plan sans bloquer l'UI
    Future.microtask(() async {
      try {
        await _statsService.updateUserStats(userId);
      } catch (e) {
        print('❌ Erreur updateUserStatsAsync: $e');
      }
    });
  }

  /// Met à jour stats terrain de manière asynchrone (non-bloquante)
  Future<void> _updateTerrainStatsAsync(String terrainId) async {
    // Exécuter en arrière-plan sans bloquer l'UI
    Future.microtask(() async {
      try {
        await _statsService.updateTerrainStats(terrainId);
      } catch (e) {
        print('❌ Erreur updateTerrainStatsAsync: $e');
      }
    });
  }

  /// 🔧 MÉTHODES DE MAINTENANCE

  /// Recalcule et corrige toutes les statistiques (maintenance)
  Future<void> recalculateAllStats() async {
    try {
      print('🔧 Recalcul complet des statistiques...');
      
      // 1. Nettoyer les statistiques existantes
      await _cleanupStats();
      
      // 2. Recalculer toutes les stats
      await updateAllStats();
      
      print('✅ Recalcul complet terminé');
      
    } catch (e) {
      print('❌ Erreur recalculateAllStats: $e');
    }
  }

  /// Nettoie les statistiques obsolètes
  Future<void> _cleanupStats() async {
    try {
      // Supprimer les champs statistiques obsolètes des utilisateurs
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      
      for (final doc in usersSnapshot.docs) {
        batch.update(doc.reference, {
          'statistiques': FieldValue.delete(),
          'statistiquesMAJ': FieldValue.delete(),
        });
      }
      
      await batch.commit();
      print('✅ Nettoyage des statistiques terminé');
      
    } catch (e) {
      print('❌ Erreur cleanup: $e');
    }
  }

  /// 📈 MÉTRIQUES DE PERFORMANCE

  /// Retourne les métriques de performance du système de stats
  Future<Map<String, dynamic>> getStatsMetrics() async {
    try {
      final now = DateTime.now();
      
      // Compter utilisateurs avec stats récentes
      final usersSnapshot = await _firestore.collection('users').get();
      int usersWithRecentStats = 0;
      
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final lastUpdate = (data['statistiquesMAJ'] as Timestamp?)?.toDate();
        if (lastUpdate != null && now.difference(lastUpdate).inHours < 24) {
          usersWithRecentStats++;
        }
      }
      
      return {
        'totalUsers': usersSnapshot.docs.length,
        'usersWithRecentStats': usersWithRecentStats,
        'statsUpdateRate': usersSnapshot.docs.isNotEmpty 
            ? (usersWithRecentStats / usersSnapshot.docs.length * 100).round()
            : 0,
        'lastCheck': now.toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur getStatsMetrics: $e');
      return {};
    }
  }
}