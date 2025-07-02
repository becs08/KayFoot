import 'package:cloud_firestore/cloud_firestore.dart';

class TerrainMapsUpdater {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🗺️ Forcer la mise à jour des terrains avec les liens Google Maps
  static Future<void> forceUpdateMapsLinks() async {
    try {
      print('🗺️ FORCE: Mise à jour des terrains avec les liens Google Maps...');

      // Mapping des noms de terrains vers les liens Google Maps
      final Map<String, String> terrainMapsLinks = {
        'Terrain Excellence Dakar': 'https://maps.app.goo.gl/sEZboQ4j2YD1geLv9',
        'Stade Municipal Thiès': 'https://maps.app.goo.gl/6Zm66duMopJ8yMJs5',
        'Arena Saint-Louis': 'https://maps.app.goo.gl/RhxgqrWnu9jkJHPE7',
        'VDN Foot': 'https://maps.app.goo.gl/APzQxB2qjg5BwaVk6',
      };

      final terrainsSnapshot = await _firestore.collection('terrains').get();
      int terrainsUpdated = 0;

      print('📊 ${terrainsSnapshot.docs.length} terrains trouvés');

      for (final terrainDoc in terrainsSnapshot.docs) {
        final data = terrainDoc.data();
        final nom = data['nom'] as String?;

        print('🔍 Vérification terrain: "$nom"');

        if (nom != null && terrainMapsLinks.containsKey(nom)) {
          // Forcer la mise à jour même si le champ existe
          await terrainDoc.reference.update({
            'googleMapsUrl': terrainMapsLinks[nom],
            'mapsLinkUpdated': FieldValue.serverTimestamp(),
          });

          print('✅ Terrain "$nom" mis à jour avec le lien: ${terrainMapsLinks[nom]}');
          terrainsUpdated++;
        } else {
          print('⚠️ Aucun lien Maps trouvé pour: "$nom"');
        }
      }

      print('🎉 FORCE UPDATE terminée: $terrainsUpdated terrain(s) mis à jour');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour forcée: $e');
      rethrow;
    }
  }

  /// 🔍 Vérifier les liens Google Maps des terrains
  static Future<void> verifyMapsLinks() async {
    try {
      print('🔍 Vérification des liens Google Maps...');

      final terrainsSnapshot = await _firestore.collection('terrains').get();

      for (final terrainDoc in terrainsSnapshot.docs) {
        final data = terrainDoc.data();
        final nom = data['nom'] as String?;
        final googleMapsUrl = data['googleMapsUrl'] as String?;

        print('📍 Terrain: "$nom"');
        print('   🔗 Google Maps URL: ${googleMapsUrl ?? "MANQUANT"}');
        print('   📊 Données complètes: ${data.keys.toList()}');
        print('---');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification: $e');
    }
  }
}
