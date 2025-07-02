class Reservation {
  final String id;
  final String joueurId;
  final String terrainId;
  final DateTime date;
  final String heureDebut;
  final String heureFin;
  final double montant;
  final double montantAvance;
  final double montantRestant;
  final bool isPaiementAvance;
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
    required this.montantAvance,
    required this.montantRestant,
    required this.isPaiementAvance,
    required this.statut,
    required this.modePaiement,
    this.transactionId,
    required this.qrCode,
    required this.dateCreation,
    this.dateAnnulation,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final montant = json['montant'].toDouble();
    final isPaiementAvance = json['isPaiementAvance'] ?? false;
    return Reservation(
      id: json['id'],
      joueurId: json['joueurId'],
      terrainId: json['terrainId'],
      date: DateTime.parse(json['date']),
      heureDebut: json['heureDebut'],
      heureFin: json['heureFin'],
      montant: montant,
      montantAvance: json['montantAvance']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : montant),
      montantRestant: json['montantRestant']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : 0.0),
      isPaiementAvance: isPaiementAvance,
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
      'montantAvance': montantAvance,
      'montantRestant': montantRestant,
      'isPaiementAvance': isPaiementAvance,
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
    double? montantAvance,
    double? montantRestant,
    bool? isPaiementAvance,
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
      montantAvance: montantAvance ?? this.montantAvance,
      montantRestant: montantRestant ?? this.montantRestant,
      isPaiementAvance: isPaiementAvance ?? this.isPaiementAvance,
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
  avance,
  payee,
  annulee,
  terminee,
}

enum ModePaiement {
  orange,
  wave,
}