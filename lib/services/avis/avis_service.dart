import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/avis.dart';
import '../../models/user.dart';
import '../profil/statistics_service.dart';

class AvisService {
  static final AvisService _instance = AvisService._internal();
  factory AvisService() => _instance;
  AvisService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StatisticsService _statsService = StatisticsService();

  /// 📝 Ajouter un avis pour un terrain
  Future<bool> ajouterAvis({
    required String terrainId,
    required User utilisateur,
    required int note,
    required String commentaire,
  }) async {
    try {
      print('📝 Ajout avis: terrain=$terrainId, note=$note');

      // Vérifier si l'utilisateur a déjà donné un avis
      final existingAvis = await _firestore
          .collection('avis')
          .where('terrainId', isEqualTo: terrainId)
          .where('utilisateurId', isEqualTo: utilisateur.id)
          .get();

      if (existingAvis.docs.isNotEmpty) {
        // Modifier l'avis existant
        await existingAvis.docs.first.reference.update({
          'note': note,
          'commentaire': commentaire,
          'dateCreation': Timestamp.now(),
        });
        print('✅ Avis mis à jour');
      } else {
        // Créer un nouvel avis
        final avis = Avis(
          id: '',
          utilisateurId: utilisateur.id,
          utilisateurNom: utilisateur.nom,
          terrainId: terrainId,
          note: note,
          commentaire: commentaire,
          dateCreation: DateTime.now(),
        );

        await _firestore.collection('avis').add(avis.toFirestore());
        print('✅ Nouvel avis créé');
      }

      // Mettre à jour les statistiques du terrain (méthode améliorée)
      print('🔧 Mise à jour statistiques après ajout avis...');
      await _synchroniserStatistiquesTerrain(terrainId);
      

      return true;
    } catch (e) {
      print('❌ Erreur ajout avis: $e');
      return false;
    }
  }

  /// 📋 Récupérer tous les avis d'un terrain
  Future<List<Avis>> getAvisParTerrain(String terrainId) async {
    try {
      print('📋 Récupération avis terrain: $terrainId');

      final snapshot = await _firestore
          .collection('avis')
          .where('terrainId', isEqualTo: terrainId)
          .orderBy('dateCreation', descending: true)
          .get();

      final avis = snapshot.docs
          .map((doc) => Avis.fromFirestore(doc.data(), doc.id))
          .toList();

      print('📋 ${avis.length} avis trouvés');
      return avis;
    } catch (e) {
      print('❌ Erreur récupération avis: $e');
      return [];
    }
  }

  /// 📊 Obtenir les statistiques d'avis pour un terrain
  Future<Map<String, dynamic>> getStatistiquesAvis(String terrainId) async {
    try {
      final avis = await getAvisParTerrain(terrainId);

      if (avis.isEmpty) {
        return {
          'nombreAvis': 0,
          'noteMoyenne': 0.0,
          'repartition': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      // Calculer la note moyenne
      final notes = avis.map((a) => a.note).toList();
      final noteMoyenne = notes.reduce((a, b) => a + b) / notes.length;

      // Calculer la répartition des notes
      final repartition = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final note in notes) {
        repartition[note] = (repartition[note] ?? 0) + 1;
      }

      return {
        'nombreAvis': avis.length,
        'noteMoyenne': double.parse(noteMoyenne.toStringAsFixed(1)),
        'repartition': repartition,
      };
    } catch (e) {
      print('❌ Erreur statistiques avis: $e');
      return {
        'nombreAvis': 0,
        'noteMoyenne': 0.0,
        'repartition': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }
  }

  /// ✅ Vérifier si un utilisateur a déjà donné un avis
  Future<Avis?> getAvisUtilisateur(String terrainId, String utilisateurId) async {
    try {
      final snapshot = await _firestore
          .collection('avis')
          .where('terrainId', isEqualTo: terrainId)
          .where('utilisateurId', isEqualTo: utilisateurId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Avis.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('❌ Erreur vérification avis utilisateur: $e');
      return null;
    }
  }

  /// 🔄 Mettre à jour la note moyenne du terrain
  Future<void> _mettreAJourNoteMoyenne(String terrainId) async {
    try {
      final stats = await getStatistiquesAvis(terrainId);

      await _firestore.collection('terrains').doc(terrainId).update({
        'notemoyenne': stats['noteMoyenne'],
        'nombreAvis': stats['nombreAvis'],
      });

      print('✅ Note moyenne mise à jour: ${stats['noteMoyenne']}');
    } catch (e) {
      print('❌ Erreur mise à jour note moyenne: $e');
    }
  }

  /// 🗑️ Supprimer un avis
  Future<bool> supprimerAvis(String avisId, String terrainId) async {
    try {
      await _firestore.collection('avis').doc(avisId).delete();
      print('✅ Avis supprimé');
      
      // Mettre à jour les statistiques après suppression
      await _synchroniserStatistiquesTerrain(terrainId);
      
      return true;
    } catch (e) {
      print('❌ Erreur suppression avis: $e');
      return false;
    }
  }

  /// 🔄 Synchroniser les statistiques d'un terrain (méthode améliorée)
  Future<void> _synchroniserStatistiquesTerrain(String terrainId) async {
    try {
      print('🔄 Synchronisation statistiques terrain: $terrainId');
      
      // Utiliser StatisticsService pour des calculs plus précis
      await _statsService.updateTerrainStats(terrainId);
      
      print('✅ Statistiques terrain synchronisées');
    } catch (e) {
      print('❌ Erreur synchronisation statistiques: $e');
      
      // Fallback vers l'ancienne méthode
      await _mettreAJourNoteMoyenne(terrainId);
    }
  }

  /// 🛠️ Corriger les statistiques de tous les terrains
  Future<void> corrigerToutesLesStatistiques() async {
    try {
      print('🛠️ Correction de toutes les statistiques des terrains...');
      
      // Récupérer tous les terrains
      final terrainsSnapshot = await _firestore.collection('terrains').get();
      
      int terrainsCorreges = 0;
      
      for (final terrainDoc in terrainsSnapshot.docs) {
        try {
          await _synchroniserStatistiquesTerrain(terrainDoc.id);
          terrainsCorreges++;
          print('✅ Terrain ${terrainDoc.id} corrigé ($terrainsCorreges/${terrainsSnapshot.docs.length})');
        } catch (e) {
          print('❌ Erreur correction terrain ${terrainDoc.id}: $e');
        }
      }
      
      print('🎉 Correction terminée: $terrainsCorreges/${terrainsSnapshot.docs.length} terrains corrigés');
    } catch (e) {
      print('❌ Erreur correction globale: $e');
    }
  }

}
