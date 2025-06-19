import '../models/terrain.dart';
import '../models/avis.dart';

class TerrainService {
  // Singleton pattern
  static final TerrainService _instance = TerrainService._internal();
  factory TerrainService() => _instance;
  TerrainService._internal();
  
  // Données de test (à remplacer par des appels API)
  final List<Terrain> _terrains = [];
  final List<Avis> _avis = [];
  
  /// Récupère tous les terrains
  Future<List<Terrain>> getAllTerrains() async {
    await Future.delayed(Duration(seconds: 1)); // Simuler la latence
    
    if (_terrains.isEmpty) {
      _initializeTestData();
    }
    
    return _terrains;
  }
  
  /// Récupère les terrains par ville
  Future<List<Terrain>> getTerrainsByVille(String ville) async {
    await Future.delayed(Duration(seconds: 1));
    
    if (_terrains.isEmpty) {
      _initializeTestData();
    }
    
    return _terrains.where((terrain) => terrain.ville == ville).toList();
  }
  
  /// Récupère un terrain par ID
  Future<Terrain?> getTerrainById(String id) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    try {
      return _terrains.firstWhere((terrain) => terrain.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Ajoute un nouveau terrain (pour les gérants)
  Future<TerrainResult> addTerrain(Terrain terrain) async {
    try {
      await Future.delayed(Duration(seconds: 2));
      
      _terrains.add(terrain);
      
      return TerrainResult(
        success: true,
        message: 'Terrain ajouté avec succès',
        terrain: terrain,
      );
    } catch (e) {
      return TerrainResult(
        success: false,
        message: 'Erreur lors de l\'ajout du terrain: ${e.toString()}',
      );
    }
  }
  
  /// Met à jour un terrain
  Future<TerrainResult> updateTerrain(Terrain terrain) async {
    try {
      await Future.delayed(Duration(seconds: 1));
      
      final index = _terrains.indexWhere((t) => t.id == terrain.id);
      if (index != -1) {
        _terrains[index] = terrain;
        
        return TerrainResult(
          success: true,
          message: 'Terrain mis à jour',
          terrain: terrain,
        );
      } else {
        return TerrainResult(
          success: false,
          message: 'Terrain non trouvé',
        );
      }
    } catch (e) {
      return TerrainResult(
        success: false,
        message: 'Erreur lors de la mise à jour: ${e.toString()}',
      );
    }
  }
  
  /// Récupère les avis d'un terrain
  Future<List<Avis>> getAvisTerrain(String terrainId) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    return _avis.where((avis) => avis.terrainId == terrainId).toList();
  }
  
  /// Ajoute un avis pour un terrain
  Future<AvisResult> addAvis(Avis avis) async {
    try {
      await Future.delayed(Duration(seconds: 1));
      
      _avis.add(avis);
      
      // Mettre à jour la note moyenne du terrain
      await _updateTerrainRating(avis.terrainId);
      
      return AvisResult(
        success: true,
        message: 'Avis ajouté avec succès',
        avis: avis,
      );
    } catch (e) {
      return AvisResult(
        success: false,
        message: 'Erreur lors de l\'ajout de l\'avis: ${e.toString()}',
      );
    }
  }
  
  /// Met à jour la note moyenne d'un terrain
  Future<void> _updateTerrainRating(String terrainId) async {
    final avisTerrain = _avis.where((avis) => avis.terrainId == terrainId).toList();
    
    if (avisTerrain.isNotEmpty) {
      final totalNotes = avisTerrain.fold(0, (sum, avis) => sum + avis.note);
      final moyenne = totalNotes / avisTerrain.length;
      
      final terrainIndex = _terrains.indexWhere((t) => t.id == terrainId);
      if (terrainIndex != -1) {
        _terrains[terrainIndex] = _terrains[terrainIndex].copyWith(
          notemoyenne: moyenne,
          nombreAvis: avisTerrain.length,
        );
      }
    }
  }
  
  /// Recherche de terrains par nom ou description
  Future<List<Terrain>> searchTerrains(String query) async {
    await Future.delayed(Duration(milliseconds: 800));
    
    if (_terrains.isEmpty) {
      _initializeTestData();
    }
    
    final queryLower = query.toLowerCase();
    return _terrains.where((terrain) =>
      terrain.nom.toLowerCase().contains(queryLower) ||
      terrain.description.toLowerCase().contains(queryLower) ||
      terrain.ville.toLowerCase().contains(queryLower)
    ).toList();
  }
  
  /// Initialise des données de test
  void _initializeTestData() {
    _terrains.addAll([
      Terrain(
        id: '1',
        nom: 'Terrain Excellence Dakar',
        description: 'Terrain de minifoot moderne avec éclairage LED et vestiaires',
        ville: 'Dakar',
        adresse: 'Plateau, Dakar',
        latitude: 14.6937,
        longitude: -17.4441,
        gerantId: 'gerant1',
        photos: ['https://example.com/terrain1.jpg'],
        equipements: ['Éclairage', 'Vestiaires', 'Parking', 'Sécurité'],
        prixHeure: 15000,
        disponibilites: {
          'lundi': ['08:00-09:00', '09:00-10:00', '16:00-17:00'],
          'mardi': ['08:00-09:00', '10:00-11:00', '17:00-18:00'],
        },
        notemoyenne: 4.5,
        nombreAvis: 12,
        dateCreation: DateTime.now().subtract(Duration(days: 30)),
      ),
      Terrain(
        id: '2',
        nom: 'Stade Municipal Thiès',
        description: 'Terrain communautaire avec gradins pour les spectateurs',
        ville: 'Thiès',
        adresse: 'Centre-ville, Thiès',
        latitude: 14.7886,
        longitude: -16.9361,
        gerantId: 'gerant2',
        photos: ['https://example.com/terrain2.jpg'],
        equipements: ['Gradins', 'Toilettes', 'Buvette', 'Terrain naturel'],
        prixHeure: 12000,
        disponibilites: {
          'mercredi': ['07:00-08:00', '18:00-19:00', '19:00-20:00'],
          'jeudi': ['16:00-17:00', '17:00-18:00', '20:00-21:00'],
        },
        notemoyenne: 4.2,
        nombreAvis: 8,
        dateCreation: DateTime.now().subtract(Duration(days: 45)),
      ),
      Terrain(
        id: '3',
        nom: 'Arena Saint-Louis',
        description: 'Terrain synthétique de haute qualité avec douches',
        ville: 'Saint-Louis',
        adresse: 'Sor, Saint-Louis',
        latitude: 16.0402,
        longitude: -16.4897,
        gerantId: 'gerant3',
        photos: ['https://example.com/terrain3.jpg'],
        equipements: ['Terrain synthétique', 'Douches', 'Vestiaires', 'Éclairage'],
        prixHeure: 18000,
        disponibilites: {
          'vendredi': ['15:00-16:00', '16:00-17:00', '19:00-20:00'],
          'samedi': ['09:00-10:00', '10:00-11:00', '14:00-15:00'],
        },
        notemoyenne: 4.8,
        nombreAvis: 15,
        dateCreation: DateTime.now().subtract(Duration(days: 20)),
      ),
    ]);
    
    // Ajouter quelques avis de test
    _avis.addAll([
      Avis(
        id: 'avis1',
        joueurId: 'joueur1',
        terrainId: '1',
        reservationId: 'res1',
        note: 5,
        commentaire: 'Excellent terrain, très bien entretenu !',
        dateCreation: DateTime.now().subtract(Duration(days: 5)),
      ),
      Avis(
        id: 'avis2',
        joueurId: 'joueur2',
        terrainId: '1',
        reservationId: 'res2',
        note: 4,
        commentaire: 'Bon terrain mais un peu cher.',
        dateCreation: DateTime.now().subtract(Duration(days: 10)),
      ),
    ]);
  }
}

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