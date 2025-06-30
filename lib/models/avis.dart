import 'package:cloud_firestore/cloud_firestore.dart';

class Avis {
  final String id;
  final String utilisateurId;
  final String utilisateurNom;
  final String terrainId;
  final int note; // 1 à 5 étoiles
  final String commentaire;
  final DateTime dateCreation;

  Avis({
    required this.id,
    required this.utilisateurId,
    required this.utilisateurNom,
    required this.terrainId,
    required this.note,
    required this.commentaire,
    required this.dateCreation,
  });

  /// Créer depuis Firestore
  factory Avis.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Avis(
      id: documentId,
      utilisateurId: data['utilisateurId'] ?? '',
      utilisateurNom: data['utilisateurNom'] ?? 'Utilisateur',
      terrainId: data['terrainId'] ?? '',
      note: data['note'] ?? 1,
      commentaire: data['commentaire'] ?? '',
      dateCreation: (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convertir pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'utilisateurId': utilisateurId,
      'utilisateurNom': utilisateurNom,
      'terrainId': terrainId,
      'note': note,
      'commentaire': commentaire,
      'dateCreation': Timestamp.fromDate(dateCreation),
    };
  }

  /// Obtenir les étoiles pleines
  int get etoilesPleine => note;
  
  /// Obtenir les étoiles vides
  int get etoilesVide => 5 - note;
}