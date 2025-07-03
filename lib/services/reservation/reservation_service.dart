import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reservation.dart';
import '../Authentification/auth_service.dart';
import '../profil/stats_update_service.dart';

class ReservationService {
  // Singleton pattern
  static final ReservationService _instance = ReservationService._internal();
  factory ReservationService() => _instance;
  ReservationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StatsUpdateService _statsService = StatsUpdateService();

  /// 📅 Crée une nouvelle réservation avec Firestore
  Future<ReservationResult> createReservation({
    required String terrainId,
    required DateTime date,
    required String heureDebut,
    required String heureFin,
    required double montant,
    required ModePaiement modePaiement,
    bool isPaiementAvance = false,
  }) async {
    try {
      print('📅 === CRÉATION RÉSERVATION ===');
      print('📅 Terrain: $terrainId');
      print('📅 Date: $date');
      print('📅 Créneau: $heureDebut - $heureFin');
      print('📅 Montant: ${montant.toInt()} FCFA');
      print('📅 Paiement: $modePaiement');

      final authService = AuthService();
      if (!authService.isAuthenticated) {
        return ReservationResult(
          success: false,
          message: 'Vous devez être connecté pour réserver',
        );
      }

      final user = authService.currentUser!;
      print('👤 Utilisateur: ${user.nom} (${user.id})');

      // 🔍 Vérifier la disponibilité du créneau avec Firestore
      print('🔍 Vérification de la disponibilité...');
      final isAvailable = await _checkAvailabilityFirestore(terrainId, date, heureDebut, heureFin);
      if (!isAvailable) {
        return ReservationResult(
          success: false,
          message: 'Ce créneau n\'est plus disponible',
        );
      }

      print('✅ Créneau disponible');

      // 💳 Simuler le traitement du paiement
      print('💳 Traitement du paiement...');
      await Future.delayed(Duration(seconds: 2));

      // 🎫 Générer un QR code unique et le code de réservation
      final reservationCode = _generateReservationCode();
      final qrCode = 'https://keen-genie-dbd23d.netlify.app/?code=$reservationCode';
      final transactionId = _generateTransactionId();

      print('🎫 QR Code généré: $qrCode');
      print('💰 Transaction ID: $transactionId');

      // 🔥 Calculer les montants selon le type de paiement
      final montantAvance = isPaiementAvance ? montant * 0.5 : montant;
      final montantRestant = isPaiementAvance ? montant * 0.5 : 0.0;

      print('💰 Montant total: ${montant.toInt()} FCFA');
      print('💰 Montant avance: ${montantAvance.toInt()} FCFA');
      print('💰 Montant restant: ${montantRestant.toInt()} FCFA');
      print('💰 Paiement en avance: $isPaiementAvance');

      // 🔥 Créer la réservation dans Firestore
      final reservationData = {
        'joueurId': user.id,
        'terrainId': terrainId,
        'date': Timestamp.fromDate(date),
        'heureDebut': heureDebut,
        'heureFin': heureFin,
        'montant': montant,
        'montantAvance': montantAvance,
        'montantRestant': montantRestant,
        'isPaiementAvance': isPaiementAvance,
        'statut': isPaiementAvance ? 'avance' : 'payee', // Avance ou payée selon le type de paiement
        'modePaiement': modePaiement.toString().split('.').last,
        'transactionId': transactionId,
        'qrCode': qrCode,
        'reservationCode': reservationCode,
        'dateCreation': FieldValue.serverTimestamp(),
        'dateModification': FieldValue.serverTimestamp(),
      };

      print('🔥 Sauvegarde dans Firestore...');
      final docRef = await _firestore.collection('reservations').add(reservationData);

      print('✅ Réservation créée avec ID: ${docRef.id}');

      // 📊 Mettre à jour les statistiques en arrière-plan
      _statsService.onReservationCreated(user.id, terrainId);

      // 📊 Construire l'objet Reservation pour la réponse
      final reservation = Reservation(
        id: docRef.id,
        joueurId: user.id,
        terrainId: terrainId,
        date: date,
        heureDebut: heureDebut,
        heureFin: heureFin,
        montant: montant,
        montantAvance: montantAvance,
        montantRestant: montantRestant,
        isPaiementAvance: isPaiementAvance,
        statut: isPaiementAvance ? StatutReservation.avance : StatutReservation.payee,
        modePaiement: modePaiement,
        transactionId: transactionId,
        qrCode: qrCode,
        dateCreation: DateTime.now(),
      );

      return ReservationResult(
        success: true,
        message: 'Réservation confirmée avec succès',
        reservation: reservation,
      );

    } catch (e) {
      print('❌ Erreur createReservation: $e');
      return ReservationResult(
        success: false,
        message: 'Erreur lors de la réservation: ${e.toString()}',
      );
    }
  }

  /// 🔍 Vérifier la disponibilité avec Firestore
  Future<bool> _checkAvailabilityFirestore(
      String terrainId,
      DateTime date,
      String heureDebut,
      String heureFin,
      ) async {
    try {
      // Créer une date de début et fin pour la journée
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      print('🔍 Recherche réservations existantes pour le ${date.day}/${date.month}/${date.year}');

      // Query pour les réservations existantes du même jour et terrain
      final query = await _firestore
          .collection('reservations')
          .where('terrainId', isEqualTo: terrainId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('statut', whereIn: ['confirmee', 'payee', 'avance']) // Exclure les annulées
          .get();

      print('📋 ${query.docs.length} réservation(s) trouvée(s) pour ce jour');

      // Vérifier les conflits de créneaux
      for (final doc in query.docs) {
        final data = doc.data();
        final existingDebut = data['heureDebut'] as String;
        final existingFin = data['heureFin'] as String;

        print('⏰ Réservation existante: $existingDebut - $existingFin');

        if (_isTimeOverlapping(existingDebut, existingFin, heureDebut, heureFin)) {
          print('❌ Conflit détecté avec réservation ${doc.id}');
          return false;
        }
      }

      print('✅ Aucun conflit détecté');
      return true;

    } catch (e) {
      print('❌ Erreur _checkAvailability: $e');
      return false; // En cas d'erreur, on refuse la réservation par sécurité
    }
  }

  /// 📋 Récupère les réservations d'un utilisateur depuis Firestore
  Future<List<Reservation>> getUserReservations(String userId) async {
    try {
      print('📋 Chargement réservations pour utilisateur: $userId');

      final query = await _firestore
          .collection('reservations')
          .where('joueurId', isEqualTo: userId)
          .orderBy('dateCreation', descending: true)
          .get();

      print('📋 ${query.docs.length} réservation(s) trouvée(s)');

      final reservations = query.docs.map((doc) {
        final data = doc.data();
        final montant = data['montant'].toDouble();
        final isPaiementAvance = data['isPaiementAvance'] ?? false;
        return Reservation(
          id: doc.id,
          joueurId: data['joueurId'],
          terrainId: data['terrainId'],
          date: (data['date'] as Timestamp).toDate(),
          heureDebut: data['heureDebut'],
          heureFin: data['heureFin'],
          montant: montant,
          montantAvance: data['montantAvance']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : montant),
          montantRestant: data['montantRestant']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : 0.0),
          isPaiementAvance: isPaiementAvance,
          statut: _parseStatut(data['statut']),
          modePaiement: _parseModePaiement(data['modePaiement']),
          transactionId: data['transactionId'],
          qrCode: data['qrCode'],
          dateCreation: data['dateCreation'] != null
              ? (data['dateCreation'] as Timestamp).toDate()
              : DateTime.now(),
          dateAnnulation: data['dateAnnulation'] != null
              ? (data['dateAnnulation'] as Timestamp).toDate()
              : null,
        );
      }).toList();

      return reservations;

    } catch (e) {
      print('❌ Erreur getUserReservations: $e');
      return [];
    }
  }

  /// 🔍 Récupère une réservation par ID depuis Firestore
  Future<Reservation?> getReservationById(String id) async {
    try {
      final doc = await _firestore.collection('reservations').doc(id).get();

      if (!doc.exists) {
        print('❌ Réservation $id non trouvée');
        return null;
      }

      final data = doc.data()!;
      final montant = data['montant'].toDouble();
      final isPaiementAvance = data['isPaiementAvance'] ?? false;
      return Reservation(
        id: doc.id,
        joueurId: data['joueurId'],
        terrainId: data['terrainId'],
        date: (data['date'] as Timestamp).toDate(),
        heureDebut: data['heureDebut'],
        heureFin: data['heureFin'],
        montant: montant,
        montantAvance: data['montantAvance']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : montant),
        montantRestant: data['montantRestant']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : 0.0),
        isPaiementAvance: isPaiementAvance,
        statut: _parseStatut(data['statut']),
        modePaiement: _parseModePaiement(data['modePaiement']),
        transactionId: data['transactionId'],
        qrCode: data['qrCode'],
        dateCreation: data['dateCreation'] != null
            ? (data['dateCreation'] as Timestamp).toDate()
            : DateTime.now(),
        dateAnnulation: data['dateAnnulation'] != null
            ? (data['dateAnnulation'] as Timestamp).toDate()
            : null,
      );

    } catch (e) {
      print('❌ Erreur getReservationById: $e');
      return null;
    }
  }

  /// ❌ Annule une réservation dans Firestore
  Future<ReservationResult> cancelReservation(String reservationId) async {
    try {
      print('❌ Annulation réservation: $reservationId');

      final docRef = _firestore.collection('reservations').doc(reservationId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return ReservationResult(
          success: false,
          message: 'Réservation non trouvée',
        );
      }

      final data = doc.data()!;
      final montant = data['montant'].toDouble();
      final isPaiementAvance = data['isPaiementAvance'] ?? false;
      final reservation = Reservation(
        id: doc.id,
        joueurId: data['joueurId'],
        terrainId: data['terrainId'],
        date: (data['date'] as Timestamp).toDate(),
        heureDebut: data['heureDebut'],
        heureFin: data['heureFin'],
        montant: montant,
        montantAvance: data['montantAvance']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : montant),
        montantRestant: data['montantRestant']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : 0.0),
        isPaiementAvance: isPaiementAvance,
        statut: _parseStatut(data['statut']),
        modePaiement: _parseModePaiement(data['modePaiement']),
        transactionId: data['transactionId'],
        qrCode: data['qrCode'],
        dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      );

      // Vérifier si l'annulation est possible (ex: 2h avant le match)
      final now = DateTime.now();
      final reservationDateTime = DateTime(
        reservation.date.year,
        reservation.date.month,
        reservation.date.day,
        int.parse(reservation.heureDebut.split(':')[0]),
        int.parse(reservation.heureDebut.split(':')[1]),
      );

      if (reservationDateTime.difference(now).inHours < 24) {
        return ReservationResult(
          success: false,
          message: 'Impossible d\'annuler moins de 24h avant le match',
        );
      }

      // Mettre à jour dans Firestore
      await docRef.update({
        'statut': 'annulee',
        'dateAnnulation': FieldValue.serverTimestamp(),
        'dateModification': FieldValue.serverTimestamp(),
      });

      print('✅ Réservation annulée avec succès');

      // 📊 Mettre à jour les statistiques (changement de statut)
      final oldStatus = _parseStatut(data['statut']).toString().split('.').last;
      _statsService.onReservationStatusChanged(
        reservation.joueurId, 
        reservation.terrainId, 
        oldStatus, 
        'annulee'
      );

      return ReservationResult(
        success: true,
        message: 'Réservation annulée avec succès',
        reservation: reservation.copyWith(
          statut: StatutReservation.annulee,
          dateAnnulation: DateTime.now(),
        ),
      );

    } catch (e) {
      print('❌ Erreur cancelReservation: $e');
      return ReservationResult(
        success: false,
        message: 'Erreur lors de l\'annulation: ${e.toString()}',
      );
    }
  }

  /// 🗑️ Supprime une réservation de l'historique
  Future<ReservationResult> deleteReservation(String reservationId) async {
    try {
      print('🗑️ Suppression réservation: $reservationId');

      final docRef = _firestore.collection('reservations').doc(reservationId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return ReservationResult(
          success: false,
          message: 'Réservation non trouvée',
        );
      }

      final data = doc.data()!;
      final montant = data['montant'].toDouble();
      final isPaiementAvance = data['isPaiementAvance'] ?? false;
      final reservation = Reservation(
        id: doc.id,
        joueurId: data['joueurId'],
        terrainId: data['terrainId'],
        date: (data['date'] as Timestamp).toDate(),
        heureDebut: data['heureDebut'],
        heureFin: data['heureFin'],
        montant: montant,
        montantAvance: data['montantAvance']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : montant),
        montantRestant: data['montantRestant']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : 0.0),
        isPaiementAvance: isPaiementAvance,
        statut: _parseStatut(data['statut']),
        modePaiement: _parseModePaiement(data['modePaiement']),
        transactionId: data['transactionId'],
        qrCode: data['qrCode'],
        dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      );

      // Vérifier que la réservation est bien passée
      final now = DateTime.now();
      final reservationDateTime = DateTime(
        reservation.date.year,
        reservation.date.month,
        reservation.date.day,
        int.parse(reservation.heureDebut.split(':')[0]),
        int.parse(reservation.heureDebut.split(':')[1]),
      );

      final isPastReservation = reservationDateTime.isBefore(now) ||
          reservation.statut == StatutReservation.annulee ||
          reservation.statut == StatutReservation.terminee;

      if (!isPastReservation) {
        return ReservationResult(
          success: false,
          message: 'Seules les réservations passées peuvent être supprimées',
        );
      }

      // Supprimer la réservation de Firestore
      await docRef.delete();

      print('✅ Réservation supprimée avec succès');

      return ReservationResult(
        success: true,
        message: 'Réservation supprimée de l\'historique',
        reservation: reservation,
      );

    } catch (e) {
      print('❌ Erreur deleteReservation: $e');
      return ReservationResult(
        success: false,
        message: 'Erreur lors de la suppression: ${e.toString()}',
      );
    }
  }

  /// 📊 Récupère les réservations d'un terrain (pour le gérant)
  Future<List<Reservation>> getTerrainReservations(String terrainId) async {
    try {
      final query = await _firestore
          .collection('reservations')
          .where('terrainId', isEqualTo: terrainId)
          .orderBy('dateCreation', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        final montant = data['montant'].toDouble();
        final isPaiementAvance = data['isPaiementAvance'] ?? false;
        return Reservation(
          id: doc.id,
          joueurId: data['joueurId'],
          terrainId: data['terrainId'],
          date: (data['date'] as Timestamp).toDate(),
          heureDebut: data['heureDebut'],
          heureFin: data['heureFin'],
          montant: montant,
          montantAvance: data['montantAvance']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : montant),
          montantRestant: data['montantRestant']?.toDouble() ?? (isPaiementAvance ? montant * 0.5 : 0.0),
          isPaiementAvance: isPaiementAvance,
          statut: _parseStatut(data['statut']),
          modePaiement: _parseModePaiement(data['modePaiement']),
          transactionId: data['transactionId'],
          qrCode: data['qrCode'],
          dateCreation: (data['dateCreation'] as Timestamp).toDate(),
          dateAnnulation: data['dateAnnulation'] != null
              ? (data['dateAnnulation'] as Timestamp).toDate()
              : null,
        );
      }).toList();

    } catch (e) {
      print('❌ Erreur getTerrainReservations: $e');
      return [];
    }
  }

  /// ⏰ Vérifie si deux créneaux horaires se chevauchent
  bool _isTimeOverlapping(String start1, String end1, String start2, String end2) {
    final startTime1 = _parseTime(start1);
    final endTime1 = _parseTime(end1);
    final startTime2 = _parseTime(start2);
    final endTime2 = _parseTime(end2);

    return startTime1 < endTime2 && startTime2 < endTime1;
  }

  /// 🕐 Convertit une heure string en minutes depuis minuit
  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 🎫 Génère un QR code unique (URL vers la page de reçu)
  String _generateQRCode() {
    final random = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final reservationCode = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
    
    // Créer une URL qui pointe vers la page de reçu
    // URL de votre site Netlify déployé
    return 'https://keen-genie-dbd23d.netlify.app/?code=$reservationCode';
  }

  /// 🎫 Génère seulement le code de réservation (pour stockage en DB)
  String _generateReservationCode() {
    final random = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// 💰 Génère un ID de transaction
  String _generateTransactionId() {
    return 'tx_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// 🔧 Parse le statut depuis Firestore
  StatutReservation _parseStatut(String statut) {
    switch (statut) {
      case 'enAttente':
        return StatutReservation.enAttente;
      case 'confirmee':
        return StatutReservation.confirmee;
      case 'avance':
        return StatutReservation.avance;
      case 'payee':
        return StatutReservation.payee;
      case 'annulee':
        return StatutReservation.annulee;
      case 'terminee':
        return StatutReservation.terminee;
      default:
        return StatutReservation.enAttente;
    }
  }

  /// 🔧 Parse le mode de paiement depuis Firestore
  ModePaiement _parseModePaiement(String modePaiement) {
    switch (modePaiement) {
      case 'orange':
        return ModePaiement.orange;
      case 'wave':
        return ModePaiement.wave;
      case 'free': // Fallback pour les anciennes données
      case 'especes': // Fallback pour les anciennes données
      default:
        return ModePaiement.orange; // Mode par défaut
    }
  }

  /// 🆕 RÉCUPÈRE LES CRÉNEAUX DÉJÀ RÉSERVÉS (Version Multi-créneaux)
  Future<Set<String>> getOccupiedSlots({
    required String terrainId,
    required DateTime date,
  }) async {
    try {
      print('🔍 Recherche créneaux occupés pour terrain $terrainId le ${date.day}/${date.month}/${date.year}');

      // Créer une date de début et fin pour la journée
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Query pour les réservations existantes du même jour et terrain
      final query = await _firestore
          .collection('reservations')
          .where('terrainId', isEqualTo: terrainId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('statut', whereIn: ['confirmee', 'payee', 'avance']) // Seulement les réservations actives
          .get();

      // Extraire les créneaux occupés
      final occupiedSlots = <String>{};

      for (final doc in query.docs) {
        final data = doc.data();
        final heureDebut = data['heureDebut'] as String;
        final heureFin = data['heureFin'] as String;

        print('📋 Réservation trouvée: $heureDebut - $heureFin (${doc.id})');

        // 🆕 GÉRER LES RÉSERVATIONS MULTI-CRÉNEAUX
        // Générer tous les créneaux horaires occupés dans cette plage
        final occupiedTimeSlots = _generateOccupiedSlots(heureDebut, heureFin);
        occupiedSlots.addAll(occupiedTimeSlots);
      }

      print('📊 Total créneaux occupés: ${occupiedSlots.length}');
      print('🚫 Créneaux: $occupiedSlots');
      return occupiedSlots;

    } catch (e) {
      print('❌ Erreur getOccupiedSlots: $e');
      return <String>{}; // Retourner un set vide en cas d'erreur
    }
  }

  /// 🆕 GÉNÈRE TOUS LES CRÉNEAUX OCCUPÉS DANS UNE PLAGE HORAIRE
  Set<String> _generateOccupiedSlots(String heureDebut, String heureFin) {
    final occupiedSlots = <String>{};

    // Parser les heures de début et fin
    final startParts = heureDebut.split(':');
    final endParts = heureFin.split(':');

    int startHour = int.parse(startParts[0]);
    int startMinute = int.parse(startParts[1]);

    int endHour = int.parse(endParts[0]);
    int endMinute = int.parse(endParts[1]);

    // Créer DateTime pour faciliter les calculs
    final now = DateTime.now();
    var currentTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
    final endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

    // Générer tous les créneaux d'1h dans cette plage
    while (currentTime.isBefore(endTime)) {
      final nextHour = currentTime.add(Duration(hours: 1));

      // Vérifier que le créneau ne dépasse pas l'heure de fin
      if (nextHour.isAfter(endTime)) break;

      final slotStart = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
      final slotEnd = '${nextHour.hour.toString().padLeft(2, '0')}:${nextHour.minute.toString().padLeft(2, '0')}';
      final slot = '$slotStart-$slotEnd';

      occupiedSlots.add(slot);
      print('🚫 Créneau occupé généré: $slot');

      currentTime = nextHour;
    }

    return occupiedSlots;
  }

  /// 💳 Simule le processus de paiement Mobile Money
  Future<PaymentResult> processPayment({
    required double montant,
    required ModePaiement modePaiement,
    required String numeroTelephone,
  }) async {
    try {
      print('💳 Traitement paiement ${modePaiement.toString().split('.').last}');
      print('💳 Montant: ${montant.toInt()} FCFA');
      print('💳 Téléphone: $numeroTelephone');

      // Simuler le processus de paiement
      await Future.delayed(Duration(seconds: 2));

      // Simuler différents résultats basés sur le mode de paiement
      final random = Random();
      final success = random.nextDouble() > 0.1; // 90% de succès

      if (success) {
        final transactionId = _generateTransactionId();
        print('✅ Paiement réussi: $transactionId');

        return PaymentResult(
          success: true,
          message: 'Paiement effectué avec succès',
          transactionId: transactionId,
        );
      } else {
        print('❌ Paiement échoué');
        return PaymentResult(
          success: false,
          message: 'Échec du paiement. Vérifiez votre solde.',
        );
      }
    } catch (e) {
      print('❌ Erreur processPayment: $e');
      return PaymentResult(
        success: false,
        message: 'Erreur lors du paiement: ${e.toString()}',
      );
    }
  }
}

// Classes de résultat (inchangées)
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
