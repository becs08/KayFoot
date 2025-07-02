import 'debug_stats_service.dart';

/// Fonction utilitaire pour corriger rapidement les statistiques
class QuickFixStats {
  /// Corrige immédiatement les stats d'Abou Niang
  static Future<void> fixAbouNiangStatsNow() async {
    try {
      print('🚀 === DÉMARRAGE CORRECTION RAPIDE ===');
      
      final debugService = DebugStatsService();
      
      // Vérifier l'état actuel
      await debugService.checkCurrentStats('QeyRsA26LxP2qrnBWYA1rIgM2is2');
      
      // Appliquer la correction
      await debugService.fixAbouNiangStats();
      
      print('✅ === CORRECTION TERMINÉE ===');
      
    } catch (e) {
      print('❌ Erreur correction rapide: $e');
    }
  }
}