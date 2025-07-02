import 'package:cloud_firestore/cloud_firestore.dart';
import 'statistics_service.dart';
import '../Authentification/auth_service.dart';

/// Service pour forcer la synchronisation des statistiques dans Firestore
class ForceStatsSync {
  static final ForceStatsSync _instance = ForceStatsSync._internal();
  factory ForceStatsSync() => _instance;
  ForceStatsSync._internal();

  final StatisticsService _statsService = StatisticsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Force la synchronisation pour l'utilisateur connecté
  Future<bool> syncCurrentUserStats() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        print('❌ Aucun utilisateur connecté');
        return false;
      }

      print('🔄 === SYNCHRONISATION FORCÉE ===');
      print('👤 Utilisateur: ${user.nom} (${user.id})');

      // 1. Vérifier l'état actuel dans Firestore
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      final currentStats = userDoc.data()?['statistiques'];
      print('📊 Stats actuelles Firestore: $currentStats');

      // 2. Calculer les nouvelles statistiques
      final newStats = await _statsService.calculateUserStats(user.id);
      print('📊 Stats calculées: $newStats');

      // 3. Forcer la mise à jour dans Firestore
      await _statsService.updateUserStats(user.id);
      print('✅ Statistiques sauvegardées dans Firestore');

      // 4. Vérifier la sauvegarde
      final updatedDoc = await _firestore.collection('users').doc(user.id).get();
      final finalStats = updatedDoc.data()?['statistiques'];
      print('📊 Stats finales Firestore: $finalStats');

      // 5. Comparer
      final hasChanged = currentStats.toString() != finalStats.toString();
      print('🔍 Changement détecté: $hasChanged');

      print('✅ === SYNCHRONISATION TERMINÉE ===');
      return true;

    } catch (e) {
      print('❌ Erreur synchronisation: $e');
      return false;
    }
  }

  /// Force la synchronisation pour un utilisateur spécifique
  Future<bool> syncUserStats(String userId) async {
    try {
      print('🔄 Synchronisation forcée pour: $userId');

      // Calculer et sauvegarder
      await _statsService.updateUserStats(userId);
      print('✅ Stats synchronisées pour $userId');

      return true;
    } catch (e) {
      print('❌ Erreur sync $userId: $e');
      return false;
    }
  }

  /// Synchronise tous les utilisateurs qui ont des réservations
  Future<void> syncAllActiveUsers() async {
    try {
      print('🔄 === SYNCHRONISATION GLOBALE ===');

      // Récupérer tous les utilisateurs uniques qui ont des réservations
      final reservationsSnapshot = await _firestore.collection('reservations').get();
      final activeUserIds = <String>{};

      for (final doc in reservationsSnapshot.docs) {
        final userId = doc.data()['joueurId'] as String?;
        if (userId != null) {
          activeUserIds.add(userId);
        }
      }

      print('👥 Utilisateurs actifs trouvés: ${activeUserIds.length}');

      // Synchroniser chaque utilisateur actif
      for (final userId in activeUserIds) {
        print('📊 Sync utilisateur: $userId');
        await syncUserStats(userId);
      }

      print('✅ === SYNCHRONISATION GLOBALE TERMINÉE ===');

    } catch (e) {
      print('❌ Erreur synchronisation globale: $e');
    }
  }
}