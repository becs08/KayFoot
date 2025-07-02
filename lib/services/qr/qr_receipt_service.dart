import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reservation.dart';
import '../../models/terrain.dart';
import '../terrain/terrain_service.dart';

/// Service pour générer des reçus via QR code
class QRReceiptService {
  static final QRReceiptService _instance = QRReceiptService._internal();
  factory QRReceiptService() => _instance;
  QRReceiptService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TerrainService _terrainService = TerrainService();

  /// Récupère une réservation par son code de réservation (extrait de l'URL)
  Future<QRReceiptResult> getReceiptByCode(String reservationCode) async {
    try {
      print('🔍 Recherche réservation avec code: $reservationCode');

      if (reservationCode.isEmpty || reservationCode.length < 8) {
        return QRReceiptResult(
          success: false,
          message: 'Code de réservation invalide',
        );
      }

      // Rechercher la réservation par code
      final reservationQuery = await _firestore
          .collection('reservations')
          .where('reservationCode', isEqualTo: reservationCode)
          .limit(1)
          .get();

      if (reservationQuery.docs.isEmpty) {
        return QRReceiptResult(
          success: false,
          message: 'Aucune réservation trouvée pour ce code',
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
        return QRReceiptResult(
          success: false,
          message: 'Terrain introuvable pour cette réservation',
        );
      }

      // Récupérer les informations de l'utilisateur
      final userInfo = await _getUserInfo(reservation.joueurId);

      print('🏟️ Terrain trouvé: ${terrain.nom}');

      return QRReceiptResult(
        success: true,
        message: 'Réservation trouvée avec succès',
        reservation: reservation,
        terrain: terrain,
        userInfo: userInfo,
      );

    } catch (e) {
      print('❌ Erreur récupération réservation: $e');
      return QRReceiptResult(
        success: false,
        message: 'Erreur lors de la récupération: ${e.toString()}',
      );
    }
  }

  /// Génère le HTML pour le reçu web
  String generateReceiptHTML(Reservation reservation, Terrain terrain, Map<String, dynamic>? userInfo) {
    final userName = userInfo?['nom'] ?? 'Utilisateur';
    final userPhone = userInfo?['telephone'] ?? '';

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reçu de Réservation - KayFoot</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: bold;
        }
        .header .subtitle {
            margin: 10px 0 0 0;
            opacity: 0.9;
            font-size: 1.1em;
        }
        .content {
            padding: 30px;
        }
        .status-badge {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: bold;
            text-transform: uppercase;
            font-size: 0.9em;
            margin-bottom: 20px;
        }
        .status-avance {
            background: rgba(255, 152, 0, 0.1);
            color: #ff9800;
            border: 2px solid #ff9800;
        }
        .status-payee {
            background: rgba(76, 175, 80, 0.1);
            color: #4caf50;
            border: 2px solid #4caf50;
        }
        .info-section {
            margin: 25px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 4px solid #4CAF50;
        }
        .info-title {
            font-weight: bold;
            color: #333;
            margin-bottom: 15px;
            font-size: 1.2em;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            color: #666;
            font-weight: 500;
        }
        .info-value {
            font-weight: bold;
            color: #333;
        }
        .financial-summary {
            background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%);
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
        }
        .total-amount {
            font-size: 1.5em;
            font-weight: bold;
            color: #1976d2;
            text-align: center;
            margin-top: 15px;
        }
        .actions {
            text-align: center;
            margin: 30px 0;
        }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            margin: 5px;
            background: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 25px;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        .btn:hover {
            background: #45a049;
            transform: translateY(-2px);
        }
        .btn-secondary {
            background: #2196F3;
        }
        .btn-secondary:hover {
            background: #1976D2;
        }
        .footer {
            background: #f5f5f5;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #eee;
        }
        @media (max-width: 600px) {
            body { padding: 10px; }
            .container { margin: 10px; }
            .header { padding: 20px; }
            .content { padding: 20px; }
            .info-row {
                flex-direction: column;
                gap: 5px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚽ KAYFOOT</h1>
            <div class="subtitle">Reçu de Réservation</div>
        </div>
        
        <div class="content">
            <div class="status-badge ${reservation.isPaiementAvance ? 'status-avance' : 'status-payee'}">
                ${reservation.isPaiementAvance ? '🟠 Paiement en Avance' : '🟢 Paiement Complet'}
            </div>
            
            <div class="info-section">
                <div class="info-title">📋 Informations de la Réservation</div>
                <div class="info-row">
                    <span class="info-label">N° de réservation</span>
                    <span class="info-value">${reservation.id}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Date</span>
                    <span class="info-value">${_formatDate(reservation.date)}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Créneau</span>
                    <span class="info-value">${reservation.heureDebut} - ${reservation.heureFin}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Statut</span>
                    <span class="info-value">${_getStatusText(reservation.statut)}</span>
                </div>
            </div>

            <div class="info-section">
                <div class="info-title">🏟️ Terrain</div>
                <div class="info-row">
                    <span class="info-label">Nom</span>
                    <span class="info-value">${terrain.nom}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Adresse</span>
                    <span class="info-value">${terrain.adresse}, ${terrain.ville}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Prix/heure</span>
                    <span class="info-value">${terrain.prixHeure.toInt()} FCFA</span>
                </div>
            </div>

            <div class="info-section">
                <div class="info-title">👤 Client</div>
                <div class="info-row">
                    <span class="info-label">Nom</span>
                    <span class="info-value">$userName</span>
                </div>
                ${userPhone.isNotEmpty ? '''
                <div class="info-row">
                    <span class="info-label">Téléphone</span>
                    <span class="info-value">$userPhone</span>
                </div>
                ''' : ''}
            </div>

            <div class="financial-summary">
                <div class="info-title">💰 Résumé Financier</div>
                ${reservation.isPaiementAvance ? '''
                <div class="info-row">
                    <span class="info-label">Total réservation</span>
                    <span class="info-value">${reservation.montant.toInt()} FCFA</span>
                </div>
                <div class="info-row">
                    <span class="info-label">✅ Avance payée</span>
                    <span class="info-value" style="color: #4caf50;">${reservation.montantAvance.toInt()} FCFA</span>
                </div>
                <div class="info-row">
                    <span class="info-label">🕐 Reste à payer</span>
                    <span class="info-value" style="color: #ff9800;">${reservation.montantRestant.toInt()} FCFA</span>
                </div>
                <div class="total-amount">
                    💳 Avance Payée: ${reservation.montantAvance.toInt()} FCFA
                </div>
                ''' : '''
                <div class="total-amount">
                    💳 Total Payé: ${reservation.montant.toInt()} FCFA
                </div>
                '''}
                <div class="info-row">
                    <span class="info-label">Mode de paiement</span>
                    <span class="info-value">${_getPaymentMethodName(reservation.modePaiement)}</span>
                </div>
            </div>

            <div class="actions">
                <a href="#" class="btn" onclick="window.print()">🖨️ Imprimer</a>
                <a href="#" class="btn btn-secondary" onclick="downloadPDF()">📄 Télécharger PDF</a>
            </div>
        </div>

        <div class="footer">
            <p>📅 Émis le ${_formatDateTime(DateTime.now())}</p>
            <p>Merci d'avoir choisi KayFoot ! ⚽</p>
            <p style="font-size: 0.9em; color: #999;">
                Présentez ce reçu à l'entrée du terrain
            </p>
        </div>
    </div>

    <script>
        function downloadPDF() {
            // Cette fonction pourrait déclencher la génération d'un PDF
            alert('Fonctionnalité PDF en cours de développement');
        }
    </script>
</body>
</html>
    ''';
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

  /// Récupère les informations d'un utilisateur
  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists ? userDoc.data() : null;
    } catch (e) {
      print('❌ Erreur récupération utilisateur: $e');
      return null;
    }
  }

  /// Formate une date
  String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    const days = [
      'lundi', 'mardi', 'mercredi', 'jeudi',
      'vendredi', 'samedi', 'dimanche'
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '${dayName.substring(0, 1).toUpperCase()}${dayName.substring(1)} ${date.day} $monthName ${date.year}';
  }

  /// Formate une date et heure
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Texte du statut
  String _getStatusText(StatutReservation statut) {
    switch (statut) {
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

  /// Nom du mode de paiement
  String _getPaymentMethodName(ModePaiement method) {
    switch (method) {
      case ModePaiement.orange:
        return 'Orange Money';
      case ModePaiement.wave:
        return 'Wave';
    }
  }
}

/// Résultat de la récupération de reçu par QR code
class QRReceiptResult {
  final bool success;
  final String message;
  final Reservation? reservation;
  final Terrain? terrain;
  final Map<String, dynamic>? userInfo;

  QRReceiptResult({
    required this.success,
    required this.message,
    this.reservation,
    this.terrain,
    this.userInfo,
  });
}