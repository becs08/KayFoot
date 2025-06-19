class User {
  final String id;
  final String nom;
  final String telephone;
  final String email;
  final String ville;
  final UserRole role;
  final String? photo;
  final DateTime dateCreation;
  final Map<String, dynamic> statistiques;

  User({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.email,
    required this.ville,
    required this.role,
    this.photo,
    required this.dateCreation,
    this.statistiques = const {},
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nom: json['nom'],
      telephone: json['telephone'],
      email: json['email'],
      ville: json['ville'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
      ),
      photo: json['photo'],
      dateCreation: DateTime.parse(json['dateCreation']),
      statistiques: json['statistiques'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'telephone': telephone,
      'email': email,
      'ville': ville,
      'role': role.toString().split('.').last,
      'photo': photo,
      'dateCreation': dateCreation.toIso8601String(),
      'statistiques': statistiques,
    };
  }

  User copyWith({
    String? id,
    String? nom,
    String? telephone,
    String? email,
    String? ville,
    UserRole? role,
    String? photo,
    DateTime? dateCreation,
    Map<String, dynamic>? statistiques,
  }) {
    return User(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      ville: ville ?? this.ville,
      role: role ?? this.role,
      photo: photo ?? this.photo,
      dateCreation: dateCreation ?? this.dateCreation,
      statistiques: statistiques ?? this.statistiques,
    );
  }
}

enum UserRole {
  joueur,
  gerant,
}