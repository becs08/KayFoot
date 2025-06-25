// 🔥 TERRAIN SERVICE MIGRÉ VERS FIRESTORE
// Fichier: lib/services/terrain_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/terrain.dart';
import '../models/avis.dart';

class TerrainService {
  // Singleton pattern
  static final TerrainService _instance = TerrainService._internal();
  factory TerrainService() => _instance;
  TerrainService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🏟️ Récupère tous les terrains depuis Firestore
  Future<List<Terrain>> getAllTerrains() async {
    try {
      print('🔍 Récupération des terrains depuis Firestore...');

      final snapshot = await _firestore
          .collection('terrains')
          .where('isActive', isEqualTo: true)  // Seulement les terrains actifs
          .orderBy('notemoyenne', descending: true)  // Mieux notés d'abord
          .get();

      print('📊 ${snapshot.docs.length} terrains trouvés');

      if (snapshot.docs.isEmpty) {
        print('⚠️ Aucun terrain trouvé dans Firestore');
        return [];
      }

      final terrains = snapshot.docs.map((doc) {
        try {
          return _terrainFromFirestore(doc);
        } catch (e) {
          print('❌ Erreur parsing terrain ${doc.id}: $e');
          return null;
        }
      }).where((terrain) => terrain != null).cast<Terrain>().toList();

      print('✅ ${terrains.length} terrains parsés avec succès');
      return terrains;
    } catch (e) {
      print('❌ Erreur getAllTerrains: $e');
      rethrow;
    }
  }

  /// 🏙️ Récupère les terrains par ville
  Future<List<Terrain>> getTerrainsByVille(String ville) async {
    try {
      print('🔍 Terrains pour la ville: $ville');

      final snapshot = await _firestore
          .collection('terrains')
          .where('ville', isEqualTo: ville)
          .where('isActive', isEqualTo: true)
          .orderBy('notemoyenne', descending: true)
          .get();

      final terrains = snapshot.docs.map((doc) => _terrainFromFirestore(doc)).toList();
      print('📍 ${terrains.length} terrains trouvés à $ville');

      return terrains;
    } catch (e) {
      print('❌ Erreur getTerrainsByVille: $e');
      rethrow;
    }
  }

  /// 🆔 Récupère un terrain par ID
  Future<Terrain?> getTerrainById(String id) async {
    try {
      print('🔍 Récupération terrain ID: $id');

      final doc = await _firestore.collection('terrains').doc(id).get();

      if (!doc.exists || doc.data() == null) {
        print('❌ Terrain $id non trouvé');
        return null;
      }

      final terrain = _terrainFromDocumentSnapshot(doc);
      print('✅ Terrain ${terrain.nom} récupéré');
      return terrain;
    } catch (e) {
      print('❌ Erreur getTerrainById: $e');
      return null;
    }
  }

  /// 🔍 Recherche de terrains par nom ou description
  Future<List<Terrain>> searchTerrains(String query) async {
    try {
      if (query.trim().isEmpty) {
        return getAllTerrains();
      }

      print('🔍 Recherche: "$query"');

      // Firestore ne supporte pas les recherches full-text natives
      // On récupère tous les terrains et on filtre côté client
      final allTerrains = await getAllTerrains();

      final queryLower = query.toLowerCase();
      final filteredTerrains = allTerrains.where((terrain) =>
      terrain.nom.toLowerCase().contains(queryLower) ||
          terrain.description.toLowerCase().contains(queryLower) ||
          terrain.ville.toLowerCase().contains(queryLower) ||
          terrain.equipements.any((eq) => eq.toLowerCase().contains(queryLower))
      ).toList();

      print('🔍 ${filteredTerrains.length} terrains correspondent à "$query"');
      return filteredTerrains;
    } catch (e) {
      print('❌ Erreur searchTerrains: $e');
      rethrow;
    }
  }

  /// ➕ Ajoute un nouveau terrain (pour les gérants)
  Future<TerrainResult> addTerrain(Terrain terrain) async {
    try {
      print('➕ Ajout nouveau terrain: ${terrain.nom}');

      // Préparer les données pour Firestore
      final terrainData = terrain.toFirestore();
      terrainData['isActive'] = true;
      terrainData['dateCreation'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.collection('terrains').add(terrainData);

      print('✅ Terrain ajouté avec ID: ${docRef.id}');

      return TerrainResult(
        success: true,
        message: 'Terrain ajouté avec succès',
        terrain: terrain.copyWith(id: docRef.id),
      );
    } catch (e) {
      print('❌ Erreur addTerrain: $e');
      return TerrainResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// 🔄 Met à jour un terrain
  Future<TerrainResult> updateTerrain(Terrain terrain) async {
    try {
      print('🔄 Mise à jour terrain: ${terrain.nom}');

      final terrainData = terrain.toFirestore();
      // Ne pas écraser dateCreation
      terrainData.remove('dateCreation');

      await _firestore.collection('terrains').doc(terrain.id).update(terrainData);

      print('✅ Terrain ${terrain.id} mis à jour');

      return TerrainResult(
        success: true,
        message: 'Terrain mis à jour',
        terrain: terrain,
      );
    } catch (e) {
      print('❌ Erreur updateTerrain: $e');
      return TerrainResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// 🗑️ Supprime (désactive) un terrain
  Future<TerrainResult> deleteTerrain(String terrainId) async {
    try {
      print('🗑️ Suppression terrain: $terrainId');

      // Soft delete - marquer comme inactif
      await _firestore.collection('terrains').doc(terrainId).update({
        'isActive': false,
        'dateDesactivation': FieldValue.serverTimestamp(),
      });

      print('✅ Terrain $terrainId désactivé');

      return TerrainResult(
        success: true,
        message: 'Terrain supprimé',
      );
    } catch (e) {
      print('❌ Erreur deleteTerrain: $e');
      return TerrainResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// ⭐ Récupère les avis d'un terrain
  Future<List<Avis>> getAvisTerrain(String terrainId) async {
    try {
      print('⭐ Récupération avis pour terrain: $terrainId');

      final snapshot = await _firestore
          .collection('avis')
          .where('terrainId', isEqualTo: terrainId)
          .orderBy('dateCreation', descending: true)
          .get();

      final avis = snapshot.docs.map((doc) => _avisFromFirestore(doc)).toList();
      print('⭐ ${avis.length} avis trouvés');

      return avis;
    } catch (e) {
      print('❌ Erreur getAvisTerrain: $e');
      // Si la collection n'existe pas encore, retourner liste vide
      return [];
    }
  }

  /// ➕ Ajoute un avis pour un terrain
  Future<AvisResult> addAvis(Avis avis) async {
    try {
      print('➕ Ajout avis pour terrain: ${avis.terrainId}');

      // Ajouter l'avis
      final avisData = avis.toFirestore();
      avisData['dateCreation'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.collection('avis').add(avisData);

      // Mettre à jour la note moyenne du terrain
      await _updateTerrainRating(avis.terrainId);

      print('✅ Avis ajouté avec ID: ${docRef.id}');

      return AvisResult(
        success: true,
        message: 'Avis ajouté avec succès',
        avis: avis.copyWith(id: docRef.id),
      );
    } catch (e) {
      print('❌ Erreur addAvis: $e');
      return AvisResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
    }
  }

  /// 📊 Met à jour la note moyenne d'un terrain
  Future<void> _updateTerrainRating(String terrainId) async {
    try {
      print('📊 Mise à jour note moyenne terrain: $terrainId');

      final avisSnapshot = await _firestore
          .collection('avis')
          .where('terrainId', isEqualTo: terrainId)
          .get();

      if (avisSnapshot.docs.isEmpty) {
        print('ℹ️ Aucun avis trouvé pour le terrain');
        return;
      }

      final totalNotes = avisSnapshot.docs.fold<int>(
          0,
              (sum, doc) => sum + (doc.data()['note'] as int? ?? 0)
      );

      final moyenne = totalNotes / avisSnapshot.docs.length;
      final nombreAvis = avisSnapshot.docs.length;

      await _firestore.collection('terrains').doc(terrainId).update({
        'notemoyenne': moyenne,
        'nombreAvis': nombreAvis,
      });

      print('✅ Note mise à jour: ${moyenne.toStringAsFixed(1)} ($nombreAvis avis)');
    } catch (e) {
      print('❌ Erreur _updateTerrainRating: $e');
    }
  }

  /// 🏢 Récupère les terrains d'un gérant
  Future<List<Terrain>> getTerrainsByGerant(String gerantId) async {
    try {
      print('🏢 Terrains du gérant: $gerantId');

      final snapshot = await _firestore
          .collection('terrains')
          .where('gerantId', isEqualTo: gerantId)
          .where('isActive', isEqualTo: true)
          .orderBy('dateCreation', descending: true)
          .get();

      final terrains = snapshot.docs.map((doc) => _terrainFromFirestore(doc)).toList();
      print('🏢 ${terrains.length} terrains gérés');

      return terrains;
    } catch (e) {
      print('❌ Erreur getTerrainsByGerant: $e');
      rethrow;
    }
  }

  /// 🔄 Convertit un document Firestore en Terrain (QueryDocumentSnapshot)
  Terrain _terrainFromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _createTerrainFromData(doc.id, doc.data());
  }

  /// 🔄 Convertit un document Firestore en Terrain (DocumentSnapshot)
  Terrain _terrainFromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _createTerrainFromData(doc.id, doc.data()!);
  }

  /// 🔄 Méthode helper pour créer un Terrain à partir des données
  Terrain _createTerrainFromData(String id, Map<String, dynamic> data) {
    return Terrain(
      id: id,
      nom: data['nom'] ?? '',
      description: data['description'] ?? '',
      ville: data['ville'] ?? '',
      adresse: data['adresse'] ?? '',
      latitude: (data['geolocation'] as GeoPoint?)?.latitude ?? 0.0,
      longitude: (data['geolocation'] as GeoPoint?)?.longitude ?? 0.0,
      gerantId: data['gerantId'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      equipements: List<String>.from(data['equipements'] ?? []),
      prixHeure: (data['prixHeure'] as num?)?.toDouble() ?? 0.0,
      disponibilites: Map<String, List<String>>.from(
        data['disponibilites']?.map(
              (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ) ?? {},
      ),
      notemoyenne: (data['notemoyenne'] as num?)?.toDouble() ?? 0.0,
      nombreAvis: data['nombreAvis'] ?? 0,
      dateCreation: (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// 🔄 Convertit un document Firestore en Avis (QueryDocumentSnapshot)
  Avis _avisFromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _createAvisFromData(doc.id, doc.data());
  }

  /// 🔄 Convertit un document Firestore en Avis (DocumentSnapshot)
  Avis _avisFromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _createAvisFromData(doc.id, doc.data()!);
  }

  /// 🔄 Méthode helper pour créer un Avis à partir des données
  Avis _createAvisFromData(String id, Map<String, dynamic> data) {
    return Avis(
      id: id,
      joueurId: data['joueurId'] ?? '',
      terrainId: data['terrainId'] ?? '',
      reservationId: data['reservationId'] ?? '',
      note: data['note'] ?? 0,
      commentaire: data['commentaire'],
      dateCreation: (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// 📊 Extensions pour le modèle Terrain
extension TerrainFirestore on Terrain {
  Map<String, dynamic> toFirestore() {
    return {
      'nom': nom,
      'description': description,
      'ville': ville,
      'adresse': adresse,
      'geolocation': GeoPoint(latitude, longitude),
      'gerantId': gerantId,
      'photos': photos,
      'equipements': equipements,
      'prixHeure': prixHeure,
      'disponibilites': disponibilites,
      'notemoyenne': notemoyenne,
      'nombreAvis': nombreAvis,
      // dateCreation géré séparément
    };
  }
}

// 📊 Extensions pour le modèle Avis
extension AvisFirestore on Avis {
  Map<String, dynamic> toFirestore() {
    return {
      'joueurId': joueurId,
      'terrainId': terrainId,
      'reservationId': reservationId,
      'note': note,
      'commentaire': commentaire,
      // dateCreation géré séparément
    };
  }
}

// 📊 Classes de résultat (inchangées)
class TerrainResult {
  final bool success;
  final String message;
  final Terrain? terrain;

  TerrainResult({
    required this.success,
    required this.message,
    this.terrain,
  });
}

class AvisResult {
  final bool success;
  final String message;
  final Avis? avis;

  AvisResult({
    required this.success,
    required this.message,
    this.avis,
  });
}
