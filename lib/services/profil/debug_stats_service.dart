import 'package:cloud_firestore/cloud_firestore.dart';
import 'statistics_service.dart';

/// Service de debug pour diagnostiquer et forcer la mise à jour des statistiques
class DebugStatsService {
  static final DebugStatsService _instance = DebugStatsService._internal();
  factory DebugStatsService() => _instance;
  DebugStatsService._internal();

  final StatisticsService _statsService = StatisticsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Force la mise à jour immédiate des statistiques d'Abou Niang
  Future<void> fixAbouNiangStats() async {
    const userId = 'QeyRsA26LxP2qrnBWYA1rIgM2is2';
    
    try {
      print('🔧 === CORRECTION STATS ABOU NIANG ===');
      
      // 1. Diagnostic détaillé
      await diagnosticUserReservationsDetailed(userId);
      
      // 2. Calcul manuel des statistiques
      final stats = await _statsService.calculateUserStats(userId);
      print('📊 Statistiques calculées: $stats');
      
      // 3. Forcer la sauvegarde dans Firestore
      await _firestore.collection('users').doc(userId).update({
        'statistiques': stats,
        'statistiquesMAJ': FieldValue.serverTimestamp(),
      });
      
      print('✅ Statistiques forcées dans Firestore');
      
      // 4. Vérifier la sauvegarde
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final savedStats = userDoc.data()?['statistiques'];
      print('🔍 Statistiques sauvegardées: $savedStats');
      
    } catch (e) {
      print('❌ Erreur correction stats: $e');
      rethrow;
    }
  }

  /// Diagnostic détaillé des réservations d'un utilisateur
  Future<void> diagnosticUserReservationsDetailed(String userId) async {
    try {
      print('🔍 === DIAGNOSTIC DÉTAILLÉ UTILISATEUR $userId ===');
      
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('joueurId', isEqualTo: userId)
          .get();
      
      print('📋 Total réservations: ${reservationsSnapshot.docs.length}');
      
      if (reservationsSnapshot.docs.isEmpty) {
        print('❌ AUCUNE réservation trouvée!');
        return;
      }

      int matchsPassesValides = 0;
      double totalMontant = 0;
      int totalTemps = 0;
      Set<String> terrains = {};
      
      for (int i = 0; i < reservationsSnapshot.docs.length; i++) {
        final doc = reservationsSnapshot.docs[i];
        final data = doc.data();
        
        final statut = data['statut'] as String? ?? 'inconnu';
        final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
        final date = (data['date'] as Timestamp?)?.toDate();
        final heureDebut = data['heureDebut'] as String? ?? '';
        final heureFin = data['heureFin'] as String? ?? '';
        final terrainId = data['terrainId'] as String? ?? '';
        
        print('');
        print('📄 === RÉSERVATION ${i + 1} ===');
        print('ID: ${doc.id}');
        print('Statut: $statut');
        print('Montant: ${montant.toInt()} FCFA');
        print('Date: $date');
        print('Créneau: $heureDebut - $heureFin');
        print('Terrain: $terrainId');
        
        // Vérifier si dans le passé
        final isPassee = _isReservationPassee(data);
        print('Dans le passé: $isPassee');
        
        // Vérifier si elle devrait compter
        final shouldCount = (statut == 'terminee' || 
                           ((statut == 'payee' || statut == 'avance') && isPassee));
        print('Devrait compter: $shouldCount');
        
        if (shouldCount) {
          matchsPassesValides++;
          totalMontant += montant;
          if (terrainId.isNotEmpty) terrains.add(terrainId);
          
          // Calculer durée
          try {
            final duree = _calculerDureeMinutes(heureDebut, heureFin);
            totalTemps += duree;
            print('Durée: ${duree}min');
          } catch (e) {
            print('Erreur calcul durée: $e');
          }
        }
        
        print('─────────────');
      }
      
      print('');
      print('📊 === RÉSUMÉ CALCULÉ ===');
      print('Matchs qui comptent: $matchsPassesValides');
      print('Montant total: ${totalMontant.toInt()} FCFA');
      print('Temps total: ${totalTemps}min (${(totalTemps/60).round()}h)');
      print('Terrains uniques: ${terrains.length}');
      print('Terrains: $terrains');
      
    } catch (e) {
      print('❌ Erreur diagnostic: $e');
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
      
      final maintenant = DateTime.now();
      final estPassee = dateFinMatch.isBefore(maintenant);
      
      print('Date fin match: $dateFinMatch');
      print('Maintenant: $maintenant');
      print('Est passée: $estPassee');
      
      return estPassee;
    } catch (e) {
      print('Erreur vérification date: $e');
      return false;
    }
  }

  /// Calcule la durée en minutes
  int _calculerDureeMinutes(String heureDebut, String heureFin) {
    try {
      final debutParts = heureDebut.split(':');
      final finParts = heureFin.split(':');
      
      final debutMinutes = int.parse(debutParts[0]) * 60 + int.parse(debutParts[1]);
      final finMinutes = int.parse(finParts[0]) * 60 + int.parse(finParts[1]);
      
      return finMinutes - debutMinutes;
    } catch (e) {
      return 60; // 1h par défaut
    }
  }

  /// Vérifie l'état actuel des statistiques dans Firestore
  Future<void> checkCurrentStats(String userId) async {
    try {
      print('🔍 === VÉRIFICATION STATS ACTUELLES ===');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('❌ Document utilisateur introuvable!');
        return;
      }
      
      final data = userDoc.data()!;
      final stats = data['statistiques'];
      final maj = data['statistiquesMAJ'];
      
      print('📊 Statistiques actuelles: $stats');
      print('🕐 Dernière MAJ: $maj');
      
    } catch (e) {
      print('❌ Erreur vérification: $e');
    }
  }
}