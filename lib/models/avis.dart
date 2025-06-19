class Avis {
  final String id;
  final String joueurId;
  final String terrainId;
  final String reservationId;
  final int note;
  final String? commentaire;
  final DateTime dateCreation;

  Avis({
    required this.id,
    required this.joueurId,
    required this.terrainId,
    required this.reservationId,
    required this.note,
    this.commentaire,
    required this.dateCreation,
  });

  factory Avis.fromJson(Map<String, dynamic> json) {
    return Avis(
      id: json['id'],
      joueurId: json['joueurId'],
      terrainId: json['terrainId'],
      reservationId: json['reservationId'],
      note: json['note'],
      commentaire: json['commentaire'],
      dateCreation: DateTime.parse(json['dateCreation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'joueurId': joueurId,
      'terrainId': terrainId,
      'reservationId': reservationId,
      'note': note,
      'commentaire': commentaire,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  Avis copyWith({
    String? id,
    String? joueurId,
    String? terrainId,
    String? reservationId,
    int? note,
    String? commentaire,
    DateTime? dateCreation,
  }) {
    return Avis(
      id: id ?? this.id,
      joueurId: joueurId ?? this.joueurId,
      terrainId: terrainId ?? this.terrainId,
      reservationId: reservationId ?? this.reservationId,
      note: note ?? this.note,
      commentaire: commentaire ?? this.commentaire,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}