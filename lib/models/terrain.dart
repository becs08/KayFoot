class Terrain {
  final String id;
  final String nom;
  final String description;
  final String ville;
  final String adresse;
  final double latitude;
  final double longitude;
  final String gerantId;
  final List<String> photos;
  final List<String> equipements;
  final double prixHeure;
  final Map<String, List<String>> disponibilites;
  final double notemoyenne;
  final int nombreAvis;
  final DateTime dateCreation;

  Terrain({
    required this.id,
    required this.nom,
    required this.description,
    required this.ville,
    required this.adresse,
    required this.latitude,
    required this.longitude,
    required this.gerantId,
    this.photos = const [],
    this.equipements = const [],
    required this.prixHeure,
    this.disponibilites = const {},
    this.notemoyenne = 0.0,
    this.nombreAvis = 0,
    required this.dateCreation,
  });

  factory Terrain.fromJson(Map<String, dynamic> json) {
    return Terrain(
      id: json['id'],
      nom: json['nom'],
      description: json['description'],
      ville: json['ville'],
      adresse: json['adresse'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      gerantId: json['gerantId'],
      photos: List<String>.from(json['photos'] ?? []),
      equipements: List<String>.from(json['equipements'] ?? []),
      prixHeure: json['prixHeure'].toDouble(),
      disponibilites: Map<String, List<String>>.from(
        json['disponibilites']?.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ) ?? {},
      ),
      notemoyenne: json['notemoyenne']?.toDouble() ?? 0.0,
      nombreAvis: json['nombreAvis'] ?? 0,
      dateCreation: DateTime.parse(json['dateCreation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'ville': ville,
      'adresse': adresse,
      'latitude': latitude,
      'longitude': longitude,
      'gerantId': gerantId,
      'photos': photos,
      'equipements': equipements,
      'prixHeure': prixHeure,
      'disponibilites': disponibilites,
      'notemoyenne': notemoyenne,
      'nombreAvis': nombreAvis,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  Terrain copyWith({
    String? id,
    String? nom,
    String? description,
    String? ville,
    String? adresse,
    double? latitude,
    double? longitude,
    String? gerantId,
    List<String>? photos,
    List<String>? equipements,
    double? prixHeure,
    Map<String, List<String>>? disponibilites,
    double? notemoyenne,
    int? nombreAvis,
    DateTime? dateCreation,
  }) {
    return Terrain(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      ville: ville ?? this.ville,
      adresse: adresse ?? this.adresse,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gerantId: gerantId ?? this.gerantId,
      photos: photos ?? this.photos,
      equipements: equipements ?? this.equipements,
      prixHeure: prixHeure ?? this.prixHeure,
      disponibilites: disponibilites ?? this.disponibilites,
      notemoyenne: notemoyenne ?? this.notemoyenne,
      nombreAvis: nombreAvis ?? this.nombreAvis,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}