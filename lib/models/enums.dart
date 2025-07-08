enum TypeTerrain {
  football,
  basketball,
  tennis,
  volleyball,
  futsal,
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

extension TypeTerrainExtension on TypeTerrain {
  String get displayName {
    switch (this) {
      case TypeTerrain.football:
        return 'Football';
      case TypeTerrain.basketball:
        return 'Basketball';
      case TypeTerrain.tennis:
        return 'Tennis';
      case TypeTerrain.volleyball:
        return 'Volleyball';
      case TypeTerrain.futsal:
        return 'Futsal';
    }
  }
}

extension StatutReservationExtension on StatutReservation {
  String get displayName {
    switch (this) {
      case StatutReservation.enAttente:
        return 'En attente';
      case StatutReservation.confirmee:
        return 'Confirmée';
      case StatutReservation.avance:
        return 'Avance payée';
      case StatutReservation.payee:
        return 'Payée';
      case StatutReservation.annulee:
        return 'Annulée';
      case StatutReservation.terminee:
        return 'Terminée';
    }
  }
}

extension ModePaiementExtension on ModePaiement {
  String get displayName {
    switch (this) {
      case ModePaiement.orange:
        return 'Orange Money';
      case ModePaiement.wave:
        return 'Wave';
    }
  }
}