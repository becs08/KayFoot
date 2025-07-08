import 'terrain.dart';
import 'enums.dart';

extension TerrainExtended on Terrain {
  // Type de terrain (par défaut football)
  TypeTerrain get type {
    // On peut déduire le type depuis les équipements ou le nom
    final nomLower = nom.toLowerCase();
    if (nomLower.contains('basket')) return TypeTerrain.basketball;
    if (nomLower.contains('tennis')) return TypeTerrain.tennis;
    if (nomLower.contains('volley')) return TypeTerrain.volleyball;
    if (nomLower.contains('futsal')) return TypeTerrain.futsal;
    return TypeTerrain.football; // Par défaut
  }

  // Disponibilité (dérivée des disponibilités)
  bool get disponible {
    return disponibilites.isNotEmpty;
  }

  // Heure d'ouverture (première heure des disponibilités)
  int get heureOuverture {
    if (disponibilites.isEmpty) return 8; // Par défaut 8h
    
    int minHeure = 24;
    for (var slots in disponibilites.values) {
      for (var slot in slots) {
        try {
          final heure = int.parse(slot.split(':')[0]);
          if (heure < minHeure) minHeure = heure;
        } catch (e) {
          // Ignore les erreurs de parsing
        }
      }
    }
    return minHeure == 24 ? 8 : minHeure;
  }

  // Heure de fermeture (dernière heure des disponibilités)
  int get heureFermeture {
    if (disponibilites.isEmpty) return 22; // Par défaut 22h
    
    int maxHeure = 0;
    for (var slots in disponibilites.values) {
      for (var slot in slots) {
        try {
          final heure = int.parse(slot.split(':')[0]);
          if (heure > maxHeure) maxHeure = heure;
        } catch (e) {
          // Ignore les erreurs de parsing
        }
      }
    }
    return maxHeure == 0 ? 22 : maxHeure + 1; // +1 pour l'heure de fin
  }

  // Téléphone (peut être null)
  String? get telephone {
    // Pour l'instant, on retourne null car cette info n'est pas stockée
    // Dans une version future, on pourrait l'ajouter au modèle
    return null;
  }

  // Équipements sous forme de Map<String, bool>
  Map<String, bool> get equipementsMap {
    return {
      'eclairage': equipements.contains('Éclairage') || equipements.contains('eclairage'),
      'vestiaires': equipements.contains('Vestiaires') || equipements.contains('vestiaires'),
      'parking': equipements.contains('Parking') || equipements.contains('parking'),
      'securite': equipements.contains('Sécurité') || equipements.contains('securite'),
    };
  }

  // Vérifier si le terrain est plein (pour compatibilité)
  bool get isFull {
    return false; // Pour l'instant, on considère qu'aucun terrain n'est plein
  }
}