import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reservation.dart';
import '../../models/terrain.dart';
import '../terrain/terrain_service.dart';

/// Service pour gérer les réservations via QR code
class QRReservationService {
  static final QRReservationService _instance = QRReservationService._internal();
  factory QRReservationService() => _instance;
  QRReservationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TerrainService _terrainService = TerrainService();

  /// Récupère une réservation par son QR code
  Future<QRReservationResult> getReservationByQRCode(String qrCode) async {
    try {
      print('🔍 Recherche réservation avec QR: $qrCode');

      if (qrCode.isEmpty) {
        return QRReservationResult(
          success: false,
          message: 'QR code invalide',
        );
      }

      // Rechercher la réservation par QR code
      final reservationQuery = await _firestore
          .collection('reservations')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (reservationQuery.docs.isEmpty) {
        return QRReservationResult(
          success: false,
          message: 'Aucune réservation trouvée pour ce QR code',
        );
      }

      final reservationDoc = reservationQuery.docs.first;
      final reservationData = reservationDoc.data();

      print('📋 Réservation trouvée: ${reservationDoc.id}');

      // Créer l'objet Reservation
      final montant = reservationData['montant'].toDouble();
      final isPaiementAvance = reservationData['isPaiementAvance'] ?? false;
      
      final reservation = Reservation(
        id: reservationDoc.id,
        joueurId: reservationData['joueurId'],
        terrainId: reservationData['terrainId'],
        date: (reservationData['date'] as Timestamp).toDate(),
        heureDebut: reservationData['heureDebut'],
        heureFin: reservationData['heureFin'],
        montant: montant,
        montantAvance: reservationData['montantAvance']?.toDouble() ?? 
                      (isPaiementAvance ? montant * 0.5 : montant),
        montantRestant: reservationData['montantRestant']?.toDouble() ?? 
                       (isPaiementAvance ? montant * 0.5 : 0.0),
        isPaiementAvance: isPaiementAvance,
        statut: _parseStatut(reservationData['statut']),
        modePaiement: _parseModePaiement(reservationData['modePaiement']),
        transactionId: reservationData['transactionId'],
        qrCode: reservationData['qrCode'],
        dateCreation: (reservationData['dateCreation'] as Timestamp).toDate(),
        dateAnnulation: reservationData['dateAnnulation'] != null
            ? (reservationData['dateAnnulation'] as Timestamp).toDate()
            : null,
      );

      // Récupérer les informations du terrain
      final terrain = await _terrainService.getTerrainById(reservation.terrainId);
      
      if (terrain == null) {
        return QRReservationResult(
          success: false,
          message: 'Terrain introuvable pour cette réservation',
        );
      }

      print('🏟️ Terrain trouvé: ${terrain.nom}');

      return QRReservationResult(
        success: true,
        message: 'Réservation trouvée avec succès',
        reservation: reservation,
        terrain: terrain,
      );

    } catch (e) {
      print('❌ Erreur récupération réservation QR: $e');
      return QRReservationResult(
        success: false,
        message: 'Erreur lors de la récupération: ${e.toString()}',
      );
    }
  }

  /// Valide si un QR code est au bon format
  bool isValidQRCode(String qrCode) {
    // Les QR codes de réservation sont généralement alphanumériques
    // Format attendu: lettres majuscules et chiffres (ex: A4I9VTHQZ3LQ)
    final qrPattern = RegExp(r'^[A-Z0-9]{8,16}$');
    return qrPattern.hasMatch(qrCode);
  }

  /// Parse le statut depuis Firestore
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

  /// Parse le mode de paiement depuis Firestore
  ModePaiement _parseModePaiement(String modePaiement) {
    switch (modePaiement) {
      case 'orange':
        return ModePaiement.orange;
      case 'wave':
        return ModePaiement.wave;
      default:
        return ModePaiement.orange;
    }
  }

  /// Récupère les informations d'un utilisateur par son ID
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists ? userDoc.data() : null;
    } catch (e) {
      print('❌ Erreur récupération utilisateur: $e');
      return null;
    }
  }
}

/// Résultat de la recherche de réservation par QR code
class QRReservationResult {
  final bool success;
  final String message;
  final Reservation? reservation;
  final Terrain? terrain;

  QRReservationResult({
    required this.success,
    required this.message,
    this.reservation,
    this.terrain,
  });
}