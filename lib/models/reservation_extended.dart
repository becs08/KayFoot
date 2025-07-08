import 'reservation.dart';
import '../services/user/user_service.dart';
import 'user.dart';

extension ReservationExtended on Reservation {
  // Alias pour la compatibilité
  DateTime get dateReservation => date;
  double get montantTotal => montant;
  
  /// Récupère les informations de l'utilisateur de façon asynchrone
  Future<User?> getUser() async {
    final userService = UserService();
    return await userService.getUserById(joueurId);
  }
  
  // Propriétés synchrones qui utilisent le cache du UserService
  String get nomUtilisateur {
    final userService = UserService();
    final user = userService.getCachedUser(joueurId);
    return user?.nom ?? 'Chargement...';
  }
  
  String? get telephoneUtilisateur {
    final userService = UserService();
    final user = userService.getCachedUser(joueurId);
    return user?.telephone;
  }
  
  String? get emailUtilisateur {
    final userService = UserService();
    final user = userService.getCachedUser(joueurId);
    return user?.email;
  }
  
  String? get villeUtilisateur {
    final userService = UserService();
    final user = userService.getCachedUser(joueurId);
    return user?.ville;
  }
  
  // Durée en heures
  int get dureeHeures {
    try {
      final debut = int.parse(heureDebut.split(':')[0]);
      final fin = int.parse(heureFin.split(':')[0]);
      return fin - debut;
    } catch (e) {
      return 1; // Par défaut 1 heure
    }
  }
  
  // Formatage de l'heure de début
  String get heureDebutFormatted {
    return heureDebut.contains(':') ? heureDebut : '${heureDebut}:00';
  }
  
  // Formatage de l'heure de fin
  String get heureFinFormatted {
    return heureFin.contains(':') ? heureFin : '${heureFin}:00';
  }
  
  // Formatage complet des horaires (09:00-10:00)
  String get horairesFormatted {
    return '${heureDebutFormatted}-${heureFinFormatted}';
  }
  
  // Vérifier si la réservation est aujourd'hui
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
  
  // Vérifier si la réservation est dans le passé
  bool get isPast {
    return date.isBefore(DateTime.now());
  }
  
  // Vérifier si la réservation est dans le futur
  bool get isFuture {
    return date.isAfter(DateTime.now());
  }
}