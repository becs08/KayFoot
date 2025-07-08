import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../services/reservation/reservation_service.dart';
import '../../services/Authentification/auth_service.dart';
import '../../models/reservation.dart';
import '../../models/reservation_extended.dart';
import '../../models/enums.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final ReservationService _reservationService = ReservationService();
  final AuthService _authService = AuthService();
  final TextEditingController _qrCodeController = TextEditingController();

  bool _isScanning = false;
  bool _isValidating = false;
  Reservation? _currentReservation;

  // Pour cette version, on simule le scanner QR avec un champ de saisie
  // En production, on utiliserait un package comme qr_code_scanner

  Future<void> _validateQRCode(String qrCode) async {
    if (qrCode.isEmpty) return;

    setState(() {
      _isValidating = true;
      _currentReservation = null;
    });

    try {
      // Le QR code contient l'ID de la réservation
      final reservation = await _reservationService.getReservationById(qrCode);

      if (reservation == null) {
        _showError('Code QR invalide ou réservation non trouvée');
        return;
      }

      // Vérifier si c'est une réservation du gérant
      final user = _authService.currentUser;
      if (user == null) {
        _showError('Erreur d\'authentification');
        return;
      }

      // Vérifier si le gérant est propriétaire du terrain
      // (Cette vérification devrait être dans le service)

      setState(() {
        _currentReservation = reservation;
      });

      _showReservationDialog(reservation);

    } catch (e) {
      _showError('Erreur lors de la validation: $e');
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showReservationDialog(Reservation reservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réservation trouvée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Client', reservation.nomUtilisateur),
            _buildInfoRow('Téléphone', reservation.telephoneUtilisateur ?? 'Non renseigné'),
            _buildInfoRow('Date', '${reservation.dateReservation.day}/${reservation.dateReservation.month}/${reservation.dateReservation.year}'),
            _buildInfoRow('Heure', reservation.horairesFormatted),
            _buildInfoRow('Montant', '${reservation.montantTotal.toInt()} FCFA'),
            _buildInfoRow('Statut', _getStatutText(reservation.statut)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer'),
          ),
          if (reservation.statut == StatutReservation.confirmee)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _validerReservation(reservation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Valider entrée'),
            ),
          if (reservation.statut == StatutReservation.enAttente)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmerReservation(reservation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Confirmer'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getStatutText(StatutReservation statut) {
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

  Future<void> _confirmerReservation(Reservation reservation) async {
    try {
      await _reservationService.updateReservationStatus(
        reservation.id,
        StatutReservation.confirmee,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation confirmée'),
          backgroundColor: Colors.green,
        ),
      );

      _qrCodeController.clear();
    } catch (e) {
      _showError('Erreur lors de la confirmation: $e');
    }
  }

  Future<void> _validerReservation(Reservation reservation) async {
    try {
      await _reservationService.updateReservationStatus(
        reservation.id,
        StatutReservation.terminee,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrée validée'),
          backgroundColor: Colors.green,
        ),
      );

      _qrCodeController.clear();
    } catch (e) {
      _showError('Erreur lors de la validation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Scanner QR'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          children: [
            // Instructions
            Container(
              padding: EdgeInsets.all(AppConstants.mediumPadding),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppConstants.primaryColor,
                  ),
                  SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Scannez le code QR de la réservation pour valider l\'entrée du client',
                      style: AppConstants.bodyStyle.copyWith(
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppConstants.largePadding),

            // Zone de scan simulée
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Zone de scan visuelle
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppConstants.primaryColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 60,
                              color: AppConstants.primaryColor,
                            ),
                            SizedBox(height: AppConstants.mediumPadding),
                            Text(
                              _isValidating
                                  ? 'Validation en cours...'
                                  : 'Placez le QR code ici',
                              style: AppConstants.bodyStyle.copyWith(
                                color: AppConstants.primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.largePadding),

                    // Pour les tests - Saisie manuelle
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppConstants.largePadding,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Pour les tests - Saisie manuelle',
                            style: AppConstants.bodyStyle.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: AppConstants.mediumPadding),
                          TextField(
                            controller: _qrCodeController,
                            decoration: InputDecoration(
                              hintText: 'ID de la réservation',
                              prefixIcon: Icon(Icons.qr_code),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                                borderSide: BorderSide(color: AppConstants.primaryColor),
                              ),
                            ),
                            onSubmitted: _validateQRCode,
                          ),
                          SizedBox(height: AppConstants.mediumPadding),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isValidating
                                  ? null
                                  : () => _validateQRCode(_qrCodeController.text),
                              icon: _isValidating
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(Icons.search),
                              label: Text(_isValidating ? 'Validation...' : 'Valider le code'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppConstants.largePadding),

            // Actions rapides
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Simuler un scan
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Scanner QR activé (simulation)'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text('Activer caméra'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryColor,
                      side: BorderSide(color: AppConstants.primaryColor),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: AppConstants.mediumPadding),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _qrCodeController.clear();
                      setState(() {
                        _currentReservation = null;
                      });
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Réinitialiser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _qrCodeController.dispose();
    super.dispose();
  }
}
