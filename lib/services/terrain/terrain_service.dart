// 🔥 TERRAIN SERVICE MIGRÉ VERS FIRESTORE
// Fichier: lib/services/terrain_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/terrain.dart';
import '../location/location_service.dart';

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

  /// 📍 Récupère les terrains triés par distance (terrains proches)
  Future<List<TerrainWithDistance>> getTerrainsProches({int? limit}) async {
    try {
      print('📍 Récupération des terrains proches...');

      // Obtenir la position actuelle
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      
      if (position == null) {
        print('❌ Position non disponible');
        // Retourner tous les terrains sans distance
        final allTerrains = await getAllTerrains();
        return allTerrains.map((terrain) => TerrainWithDistance(
          terrain: terrain,
          distance: null,
          distanceFormatted: 'Position non disponible',
        )).toList();
      }

      // Récupérer tous les terrains
      final allTerrains = await getAllTerrains();
      
      // Calculer les distances et trier
      final terrainsWithDistance = allTerrains.map((terrain) {
        final distance = locationService.calculateDistance(
          position.latitude,
          position.longitude,
          terrain.latitude,
          terrain.longitude,
        );
        
        return TerrainWithDistance(
          terrain: terrain,
          distance: distance,
          distanceFormatted: locationService.formatDistance(distance),
        );
      }).toList();

      // Trier par distance
      terrainsWithDistance.sort((a, b) {
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      // Appliquer la limite si spécifiée
      final result = limit != null 
          ? terrainsWithDistance.take(limit).toList()
          : terrainsWithDistance;

      print('📍 ${result.length} terrains triés par distance');
      return result;
    } catch (e) {
      print('❌ Erreur getTerrainsProches: $e');
      rethrow;
    }
  }

  /// 🏙️ Récupère les terrains proches d'une ville spécifique
  Future<List<TerrainWithDistance>> getTerrainsProchesVille(String ville, {int? limit}) async {
    try {
      print('🏙️ Terrains proches de $ville...');

      // Obtenir la position actuelle
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      // Récupérer les terrains de la ville
      final terrainsVille = await getTerrainsByVille(ville);
      
      if (position == null) {
        // Retourner les terrains de la ville sans distance
        return terrainsVille.map((terrain) => TerrainWithDistance(
          terrain: terrain,
          distance: null,
          distanceFormatted: 'Position non disponible',
        )).toList();
      }

      // Calculer les distances et trier
      final terrainsWithDistance = terrainsVille.map((terrain) {
        final distance = locationService.calculateDistance(
          position.latitude,
          position.longitude,
          terrain.latitude,
          terrain.longitude,
        );
        
        return TerrainWithDistance(
          terrain: terrain,
          distance: distance,
          distanceFormatted: locationService.formatDistance(distance),
        );
      }).toList();

      // Trier par distance
      terrainsWithDistance.sort((a, b) {
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      // Appliquer la limite si spécifiée
      final result = limit != null 
          ? terrainsWithDistance.take(limit).toList()
          : terrainsWithDistance;

      print('🏙️ ${result.length} terrains proches dans $ville');
      return result;
    } catch (e) {
      print('❌ Erreur getTerrainsProchesVille: $e');
      rethrow;
    }
  }

  /// 🎯 Obtenir les terrains dans un rayon donné (en km)
  Future<List<TerrainWithDistance>> getTerrainsInRadius(double radiusKm) async {
    try {
      print('🎯 Terrains dans un rayon de ${radiusKm}km...');

      final terrainsProches = await getTerrainsProches();
      
      // Filtrer par rayon
      final terrainsInRadius = terrainsProches.where((terrainWithDistance) {
        return terrainWithDistance.distance != null && 
               terrainWithDistance.distance! <= radiusKm;
      }).toList();

      print('🎯 ${terrainsInRadius.length} terrains dans le rayon de ${radiusKm}km');
      return terrainsInRadius;
    } catch (e) {
      print('❌ Erreur getTerrainsInRadius: $e');
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

  // Les méthodes d'avis ont été déplacées vers AvisService pour une meilleure séparation des responsabilités

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
    try {
      print('📋 Création terrain depuis données: $id');
      
      return Terrain(
        id: id,
        nom: data['nom'] ?? '',
        description: data['description'] ?? '',
        ville: data['ville'] ?? '',
        adresse: data['adresse'] ?? '',
        latitude: (data['geolocation'] as GeoPoint?)?.latitude ?? 0.0,
        longitude: (data['geolocation'] as GeoPoint?)?.longitude ?? 0.0,
        googleMapsUrl: data['googleMapsUrl'],
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
    } catch (e) {
      print('❌ Erreur création terrain $id: $e');
      print('📊 Données reçues: $data');
      rethrow;
    }
  }

  // Méthodes d'avis supprimées - voir AvisService
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
      'googleMapsUrl': googleMapsUrl,
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

// 📊 Classes de résultat
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

// 📍 Classe pour représenter un terrain avec sa distance
class TerrainWithDistance {
  final Terrain terrain;
  final double? distance; // Distance en kilomètres
  final String distanceFormatted; // Distance formatée pour l'affichage

  TerrainWithDistance({
    required this.terrain,
    this.distance,
    required this.distanceFormatted,
  });
}
