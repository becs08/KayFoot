import 'dart:math';
import '../models/reservation.dart';
import '../services/auth_service.dart';

class ReservationService {
  // Singleton pattern
  static final ReservationService _instance = ReservationService._internal();
  factory ReservationService() => _instance;
  ReservationService._internal();
  
  final List<Reservation> _reservations = [];
  
  /// Crée une nouvelle réservation
  Future<ReservationResult> createReservation({
    required String terrainId,
    required DateTime date,
    required String heureDebut,
    required String heureFin,
    required double montant,
    required ModePaiement modePaiement,
  }) async {
    try {
      final authService = AuthService();
      if (!authService.isAuthenticated) {
        return ReservationResult(
          success: false,
          message: 'Vous devez être connecté pour réserver',
        );
      }
      
      // Vérifier la disponibilité du créneau
      final isAvailable = await _checkAvailability(terrainId, date, heureDebut, heureFin);
      if (!isAvailable) {
        return ReservationResult(
          success: false,
          message: 'Ce créneau n\'est plus disponible',
        );
      }
      
      // Simuler le traitement du paiement
      await Future.delayed(Duration(seconds: 3));
      
      // Générer un QR code unique
      final qrCode = _generateQRCode();
      
      final reservation = Reservation(
        id: _generateId(),
        joueurId: authService.currentUser!.id,
        terrainId: terrainId,
        date: date,
        heureDebut: heureDebut,
        heureFin: heureFin,
        montant: montant,
        statut: StatutReservation.payee,
        modePaiement: modePaiement,
        transactionId: _generateTransactionId(),
        qrCode: qrCode,
        dateCreation: DateTime.now(),
      );
      
      _reservations.add(reservation);
      
      return ReservationResult(
        success: true,
        message: 'Réservation confirmée avec succès',
        reservation: reservation,
      );
    } catch (e) {
      return ReservationResult(
        success: false,
        message: 'Erreur lors de la réservation: ${e.toString()}',
      );
    }
  }
  
  /// Récupère les réservations d'un utilisateur
  Future<List<Reservation>> getUserReservations(String userId) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    return _reservations
        .where((reservation) => reservation.joueurId == userId)
        .toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
  }
  
  /// Récupère une réservation par ID
  Future<Reservation?> getReservationById(String id) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    try {
      return _reservations.firstWhere((reservation) => reservation.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Annule une réservation
  Future<ReservationResult> cancelReservation(String reservationId) async {
    try {
      await Future.delayed(Duration(seconds: 1));
      
      final index = _reservations.indexWhere((r) => r.id == reservationId);
      if (index == -1) {
        return ReservationResult(
          success: false,
          message: 'Réservation non trouvée',
        );
      }
      
      final reservation = _reservations[index];
      
      // Vérifier si l'annulation est possible (ex: 2h avant le match)
      final now = DateTime.now();
      final reservationDateTime = DateTime(
        reservation.date.year,
        reservation.date.month,
        reservation.date.day,
        int.parse(reservation.heureDebut.split(':')[0]),
        int.parse(reservation.heureDebut.split(':')[1]),
      );
      
      if (reservationDateTime.difference(now).inHours < 2) {
        return ReservationResult(
          success: false,
          message: 'Impossible d\'annuler moins de 2h avant le match',
        );
      }
      
      // Annuler la réservation
      _reservations[index] = reservation.copyWith(
        statut: StatutReservation.annulee,
        dateAnnulation: DateTime.now(),
      );
      
      return ReservationResult(
        success: true,
        message: 'Réservation annulée avec succès',
        reservation: _reservations[index],
      );
    } catch (e) {
      return ReservationResult(
        success: false,
        message: 'Erreur lors de l\'annulation: ${e.toString()}',
      );
    }
  }
  
  /// Récupère les réservations d'un terrain (pour le gérant)
  Future<List<Reservation>> getTerrainReservations(String terrainId) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    return _reservations
        .where((reservation) => reservation.terrainId == terrainId)
        .toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
  }
  
  /// Vérifie la disponibilité d'un créneau
  Future<bool> _checkAvailability(
    String terrainId,
    DateTime date,
    String heureDebut,
    String heureFin,
  ) async {
    // Vérifier s'il y a déjà une réservation pour ce créneau
    final existingReservations = _reservations.where((reservation) =>
      reservation.terrainId == terrainId &&
      reservation.date.year == date.year &&
      reservation.date.month == date.month &&
      reservation.date.day == date.day &&
      reservation.statut != StatutReservation.annulee &&
      _isTimeOverlapping(
        reservation.heureDebut,
        reservation.heureFin,
        heureDebut,
        heureFin,
      )
    ).toList();
    
    return existingReservations.isEmpty;
  }
  
  /// Vérifie si deux créneaux horaires se chevauchent
  bool _isTimeOverlapping(
    String start1,
    String end1,
    String start2,
    String end2,
  ) {
    final startTime1 = _parseTime(start1);
    final endTime1 = _parseTime(end1);
    final startTime2 = _parseTime(start2);
    final endTime2 = _parseTime(end2);
    
    return startTime1 < endTime2 && startTime2 < endTime1;
  }
  
  /// Convertit une heure string en minutes depuis minuit
  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
  
  /// Génère un ID unique
  String _generateId() {
    return 'res_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Génère un ID de transaction
  String _generateTransactionId() {
    return 'tx_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }
  
  /// Génère un QR code unique
  String _generateQRCode() {
    final random = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// Simule le processus de paiement Mobile Money
  Future<PaymentResult> processPayment({
    required double montant,
    required ModePaiement modePaiement,
    required String numeroTelephone,
  }) async {
    try {
      // Simuler le processus de paiement
      await Future.delayed(Duration(seconds: 2));
      
      // Simuler différents résultats basés sur le mode de paiement
      final random = Random();
      final success = random.nextDouble() > 0.1; // 90% de succès
      
      if (success) {
        return PaymentResult(
          success: true,
          message: 'Paiement effectué avec succès',
          transactionId: _generateTransactionId(),
        );
      } else {
        return PaymentResult(
          success: false,
          message: 'Échec du paiement. Vérifiez votre solde.',
        );
      }
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Erreur lors du paiement: ${e.toString()}',
      );
    }
  }
}

class ReservationResult {
  final bool success;
  final String message;
  final Reservation? reservation;
  
  ReservationResult({
    required this.success,
    required this.message,
    this.reservation,
  });
}

class PaymentResult {
  final bool success;
  final String message;
  final String? transactionId;
  
  PaymentResult({
    required this.success,
    required this.message,
    this.transactionId,
  });
}