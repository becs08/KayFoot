class Reservation {
  final String id;
  final String joueurId;
  final String terrainId;
  final DateTime date;
  final String heureDebut;
  final String heureFin;
  final double montant;
  final StatutReservation statut;
  final ModePaiement modePaiement;
  final String? transactionId;
  final String qrCode;
  final DateTime dateCreation;
  final DateTime? dateAnnulation;

  Reservation({
    required this.id,
    required this.joueurId,
    required this.terrainId,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.montant,
    required this.statut,
    required this.modePaiement,
    this.transactionId,
    required this.qrCode,
    required this.dateCreation,
    this.dateAnnulation,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'],
      joueurId: json['joueurId'],
      terrainId: json['terrainId'],
      date: DateTime.parse(json['date']),
      heureDebut: json['heureDebut'],
      heureFin: json['heureFin'],
      montant: json['montant'].toDouble(),
      statut: StatutReservation.values.firstWhere(
        (e) => e.toString() == 'StatutReservation.${json['statut']}',
      ),
      modePaiement: ModePaiement.values.firstWhere(
        (e) => e.toString() == 'ModePaiement.${json['modePaiement']}',
      ),
      transactionId: json['transactionId'],
      qrCode: json['qrCode'],
      dateCreation: DateTime.parse(json['dateCreation']),
      dateAnnulation: json['dateAnnulation'] != null
          ? DateTime.parse(json['dateAnnulation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'joueurId': joueurId,
      'terrainId': terrainId,
      'date': date.toIso8601String(),
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'montant': montant,
      'statut': statut.toString().split('.').last,
      'modePaiement': modePaiement.toString().split('.').last,
      'transactionId': transactionId,
      'qrCode': qrCode,
      'dateCreation': dateCreation.toIso8601String(),
      'dateAnnulation': dateAnnulation?.toIso8601String(),
    };
  }

  Reservation copyWith({
    String? id,
    String? joueurId,
    String? terrainId,
    DateTime? date,
    String? heureDebut,
    String? heureFin,
    double? montant,
    StatutReservation? statut,
    ModePaiement? modePaiement,
    String? transactionId,
    String? qrCode,
    DateTime? dateCreation,
    DateTime? dateAnnulation,
  }) {
    return Reservation(
      id: id ?? this.id,
      joueurId: joueurId ?? this.joueurId,
      terrainId: terrainId ?? this.terrainId,
      date: date ?? this.date,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      montant: montant ?? this.montant,
      statut: statut ?? this.statut,
      modePaiement: modePaiement ?? this.modePaiement,
      transactionId: transactionId ?? this.transactionId,
      qrCode: qrCode ?? this.qrCode,
      dateCreation: dateCreation ?? this.dateCreation,
      dateAnnulation: dateAnnulation ?? this.dateAnnulation,
    );
  }
}

enum StatutReservation {
  enAttente,
  confirmee,
  payee,
  annulee,
  terminee,
}

enum ModePaiement {
  orange,
  wave,
  free,
  especes,
}