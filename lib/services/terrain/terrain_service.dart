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
          .where('estValide', isEqualTo: true)  // Seulement les terrains validés
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
          .where('estValide', isEqualTo: true)
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
      final terrainData = terrain.toJson();
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

      final terrainData = terrain.toJson();
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

  /// 🏆 Récupère les terrains populaires basés sur le nombre de réservations
  Future<List<TerrainWithReservationCount>> getTerrainsPopulaires({int limit = 3}) async {
    try {
      print('🏆 Récupération des terrains populaires...');

      // Récupérer tous les terrains actifs
      final allTerrains = await getAllTerrains();
      
      // Pour chaque terrain, compter ses réservations
      final terrainsWithCount = <TerrainWithReservationCount>[];
      
      for (final terrain in allTerrains) {
        final reservationCount = await _getReservationCountForTerrain(terrain.id);
        terrainsWithCount.add(TerrainWithReservationCount(
          terrain: terrain,
          totalReservation: reservationCount,
        ));
      }

      // Trier par nombre de réservations (décroissant)
      terrainsWithCount.sort((a, b) => b.totalReservation.compareTo(a.totalReservation));

      // Prendre les N premiers terrains
      final result = terrainsWithCount.take(limit).toList();

      print('🏆 Top $limit terrains populaires:');
      for (var i = 0; i < result.length; i++) {
        print('  ${i + 1}. ${result[i].terrain.nom} - ${result[i].totalReservation} réservations');
      }

      return result;
    } catch (e) {
      print('❌ Erreur getTerrainsPopulaires: $e');
      rethrow;
    }
  }

  /// 📊 Compte le nombre de réservations pour un terrain
  Future<int> _getReservationCountForTerrain(String terrainId) async {
    try {
      final query = await _firestore
          .collection('reservations')
          .where('terrainId', isEqualTo: terrainId)
          .where('statut', whereIn: ['payee', 'terminee']) // Seulement les réservations confirmées
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      print('❌ Erreur _getReservationCountForTerrain: $e');
      return 0;
    }
  }

  /// 🗑️ Supprime (désactive) un terrain
  Future<TerrainResult> deleteTerrain(String terrainId) async {
    try {
      print('🗑️ Suppression terrain: $terrainId');

      // Soft delete - marquer comme non validé
      await _firestore.collection('terrains').doc(terrainId).update({
        'estValide': false,
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

  /// 🏢 Récupère tous les terrains d'un gérant (validés et non validés)
  Future<List<Terrain>> getTerrainsByGerant(String gerantId) async {
    try {
      print('🏢 Terrains du gérant: $gerantId');

      final snapshot = await _firestore
          .collection('terrains')
          .where('gerantId', isEqualTo: gerantId)
          .orderBy('dateCreation', descending: true)
          .get();

      final terrains = snapshot.docs.map((doc) => _terrainFromFirestore(doc)).toList();
      print('🏢 ${terrains.length} terrains gérés (validés: ${terrains.where((t) => t.estValide).length})');

      return terrains;
    } catch (e) {
      print('❌ Erreur getTerrainsByGerant: $e');
      rethrow;
    }
  }

  /// 🔧 Répare un terrain existant avec les nouveaux champs
  Future<TerrainResult> repairTerrain(String terrainId) async {
    try {
      print('🔧 Réparation terrain: $terrainId');

      final doc = await _firestore.collection('terrains').doc(terrainId).get();
      
      if (!doc.exists) {
        return TerrainResult(
          success: false,
          message: 'Terrain non trouvé',
        );
      }

      final data = doc.data()!;
      final updates = <String, dynamic>{};

      // Ajouter les champs manquants
      if (!data.containsKey('estValide')) {
        updates['estValide'] = false;
      }
      
      if (!data.containsKey('dateValidation')) {
        updates['dateValidation'] = null;
      }

      // Vérifier et réparer les disponibilités
      if (data['disponibilites'] == null || (data['disponibilites'] as Map).isEmpty) {
        // Créer des disponibilités par défaut au format "HH:MM-HH:MM"
        final defaultSchedule = {
          'lundi': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
          'mardi': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
          'mercredi': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
          'jeudi': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
          'vendredi': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
          'samedi': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
          'dimanche': ['08:00-09:00', '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00', '13:00-14:00', '14:00-15:00', '15:00-16:00', '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00', '20:00-21:00', '21:00-22:00'],
        };
        updates['disponibilites'] = defaultSchedule;
      } else {
        // Vérifier si les disponibilités existantes sont au bon format
        final existingDisponibilites = data['disponibilites'] as Map<String, dynamic>;
        final repairedDisponibilites = <String, List<String>>{};
        bool needsRepair = false;
        
        for (final entry in existingDisponibilites.entries) {
          final jour = entry.key;
          final creneaux = List<String>.from(entry.value ?? []);
          final nouveauxCreneaux = <String>[];
          
          for (final creneau in creneaux) {
            // Vérifier si le créneau est déjà au format "HH:MM-HH:MM"
            if (creneau.contains('-')) {
              // Créneau déjà au bon format
              nouveauxCreneaux.add(creneau);
            } else {
              // Convertir de "HH:MM" ou "HH" au format "HH:MM-HH:MM"
              needsRepair = true;
              String heureDebut;
              
              if (creneau.contains(':')) {
                heureDebut = creneau;
              } else {
                // Format "9" ou "09" -> "09:00"
                final heure = int.tryParse(creneau) ?? 0;
                heureDebut = '${heure.toString().padLeft(2, '0')}:00';
              }
              
              // Calculer l'heure de fin (1 heure après)
              final parts = heureDebut.split(':');
              final heureInt = int.parse(parts[0]);
              final heureFin = '${(heureInt + 1).toString().padLeft(2, '0')}:00';
              
              nouveauxCreneaux.add('$heureDebut-$heureFin');
            }
          }
          
          repairedDisponibilites[jour] = nouveauxCreneaux;
        }
        
        if (needsRepair) {
          updates['disponibilites'] = repairedDisponibilites;
          print('🔧 Disponibilités réparées avec nouveau format HH:MM-HH:MM');
        }
      }

      // Convertir geolocation en latitude/longitude si nécessaire
      if (data.containsKey('geolocation') && data['geolocation'] != null) {
        final geoPoint = data['geolocation'] as GeoPoint;
        if (!data.containsKey('latitude')) {
          updates['latitude'] = geoPoint.latitude;
        }
        if (!data.containsKey('longitude')) {
          updates['longitude'] = geoPoint.longitude;
        }
      }

      // Ajouter les photos vides si manquantes
      if (!data.containsKey('photos') || data['photos'] == null) {
        updates['photos'] = <String>[];
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('terrains').doc(terrainId).update(updates);
        print('✅ Terrain $terrainId réparé avec ${updates.length} champs');
      } else {
        print('ℹ️ Terrain $terrainId déjà à jour');
      }

      return TerrainResult(
        success: true,
        message: 'Terrain réparé avec succès',
      );
    } catch (e) {
      print('❌ Erreur repairTerrain: $e');
      return TerrainResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
      );
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
      
      // Support des deux formats: latitude/longitude directs ET geolocation GeoPoint
      double latitude = 0.0;
      double longitude = 0.0;
      
      if (data['latitude'] != null && data['longitude'] != null) {
        // Format direct latitude/longitude
        latitude = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        longitude = (data['longitude'] as num?)?.toDouble() ?? 0.0;
      } else if (data['geolocation'] != null) {
        // Format GeoPoint (ancien)
        final geoPoint = data['geolocation'] as GeoPoint?;
        latitude = geoPoint?.latitude ?? 0.0;
        longitude = geoPoint?.longitude ?? 0.0;
      }
      
      return Terrain(
        id: id,
        nom: data['nom'] ?? '',
        description: data['description'] ?? '',
        ville: data['ville'] ?? '',
        adresse: data['adresse'] ?? '',
        latitude: latitude,
        longitude: longitude,
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
        estValide: data['estValide'] ?? false,
        dateValidation: data['dateValidation'] != null 
            ? (data['dateValidation'] as Timestamp?)?.toDate()
            : null,
      );
    } catch (e) {
      print('❌ Erreur création terrain $id: $e');
      print('📊 Données reçues: $data');
      rethrow;
    }
  }

  // Méthodes d'avis supprimées - voir AvisService
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

// 🏆 Classe pour représenter un terrain avec son nombre de réservations
class TerrainWithReservationCount {
  final Terrain terrain;
  final int totalReservation;

  TerrainWithReservationCount({
    required this.terrain,
    required this.totalReservation,
  });
}
