import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../constants/app_constants.dart';
import '../../models/reservation.dart';
import '../../models/terrain.dart';
import '../../services/terrain_service.dart';
import '../../services/reservation_service.dart';
import '../../services/statistics_service.dart';
import '../../services/pdf_receipt_service.dart';

class ReservationDetailScreen extends StatefulWidget {
  final Reservation reservation;

  const ReservationDetailScreen({Key? key, required this.reservation}) : super(key: key);

  @override
  _ReservationDetailScreenState createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  Terrain? _terrain;
  bool _isLoading = true;
  bool _isDownloading = false;
  final StatisticsService _statsService = StatisticsService();
  final PdfReceiptService _receiptService = PdfReceiptService();

  @override
  void initState() {
    super.initState();
    _loadTerrain();
  }

  Future<void> _loadTerrain() async {
    try {
      final terrain = await TerrainService().getTerrainById(widget.reservation.terrainId);
      setState(() {
        _terrain = terrain;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelReservation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler la réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Êtes-vous sûr de vouloir annuler cette réservation ?'),
            SizedBox(height: AppConstants.smallPadding),
            Text(
              'Cette action est irréversible.',
              style: TextStyle(
                color: AppConstants.errorColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Oui, annuler'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await ReservationService().cancelReservation(widget.reservation.id);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppConstants.successColor,
            ),
          );
          Navigator.of(context).pop(); // Retourner à la liste
        } else {
          _showError(result.message);
        }
      } catch (e) {
        _showError('Erreur lors de l\'annulation');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  Future<void> _downloadReceipt() async {
    if (_terrain == null) {
      _showError('Informations du terrain non disponibles');
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final success = await _receiptService.shareReceiptPDF(
        reservation: widget.reservation,
        terrain: _terrain!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reçu PDF partagé avec succès'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } else {
        _showError('Erreur lors de la génération du reçu PDF');
      }
    } catch (e) {
      _showError('Erreur lors du téléchargement du reçu PDF');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }


  bool _canCancelReservation() {
    if (widget.reservation.statut != StatutReservation.payee) {
      return false;
    }

    final now = DateTime.now();
    final reservationDateTime = DateTime(
      widget.reservation.date.year,
      widget.reservation.date.month,
      widget.reservation.date.day,
      int.parse(widget.reservation.heureDebut.split(':')[0]),
      int.parse(widget.reservation.heureDebut.split(':')[1]),
    );

    return reservationDateTime.difference(now).inHours >= 2;
  }

  bool _isReservationActive() {
    // Une réservation est considérée comme active si elle est payée ou confirmée
    // et qu'elle n'est pas annulée ou terminée
    return widget.reservation.statut == StatutReservation.payee ||
           widget.reservation.statut == StatutReservation.confirmee;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails de la réservation'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppConstants.mediumPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statut de la réservation
                  _buildStatusCard(),

                  SizedBox(height: AppConstants.mediumPadding),

                  // Informations du terrain
                  _buildTerrainInfo(),

                  SizedBox(height: AppConstants.mediumPadding),

                  // Détails de la réservation
                  _buildReservationDetails(),

                  SizedBox(height: AppConstants.mediumPadding),

                  // Informations de paiement
                  _buildPaymentInfo(),

                  SizedBox(height: AppConstants.mediumPadding),

                  // QR Code (si applicable)
                  if (widget.reservation.statut == StatutReservation.payee ||
                      widget.reservation.statut == StatutReservation.confirmee)
                    _buildQRCode(),

                  SizedBox(height: AppConstants.largePadding),

                  // Boutons d'action
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    Color color;
    String message;
    IconData icon;

    switch (widget.reservation.statut) {
      case StatutReservation.enAttente:
        color = AppConstants.warningColor;
        message = 'Votre réservation est en attente de confirmation';
        icon = Icons.schedule;
        break;
      case StatutReservation.confirmee:
        color = Colors.blue;
        message = 'Votre réservation est confirmée';
        icon = Icons.check_circle_outline;
        break;
      case StatutReservation.payee:
        color = AppConstants.successColor;
        message = 'Réservation payée et confirmée';
        icon = Icons.check_circle;
        break;
      case StatutReservation.annulee:
        color = AppConstants.errorColor;
        message = 'Cette réservation a été annulée';
        icon = Icons.cancel;
        break;
      case StatutReservation.terminee:
        color = Colors.grey;
        message = 'Match terminé';
        icon = Icons.done_all;
        break;
    }

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),

            SizedBox(width: AppConstants.mediumPadding),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(widget.reservation.statut),
                    style: AppConstants.subHeadingStyle.copyWith(
                      color: color,
                      fontSize: 16,
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    message,
                    style: AppConstants.bodyStyle.copyWith(
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerrainInfo() {
    if (_terrain == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          child: Text('Informations du terrain non disponibles'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terrain',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            SizedBox(height: AppConstants.mediumPadding),

            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                  ),
                  child: Icon(
                    Icons.sports_soccer,
                    color: AppConstants.primaryColor,
                    size: 30,
                  ),
                ),

                SizedBox(width: AppConstants.mediumPadding),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _terrain!.nom,
                        style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
                      ),

                      SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_terrain!.adresse}, ${_terrain!.ville}',
                              style: AppConstants.bodyStyle.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      FutureBuilder<Map<String, dynamic>>(
                        future: _statsService.calculateTerrainStats(_terrain!.id),
                        builder: (context, snapshot) {
                          final noteMoyenne = snapshot.hasData && snapshot.data!['noteMoyenne'] != null && snapshot.data!['noteMoyenne'] > 0
                              ? snapshot.data!['noteMoyenne'] as double
                              : 0.0;
                          final nombreAvis = snapshot.hasData && snapshot.data!['nombreAvis'] != null
                              ? snapshot.data!['nombreAvis'] as int
                              : 0;

                          return Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: noteMoyenne > 0 ? AppConstants.accentColor : Colors.grey.shade400,
                              ),
                              SizedBox(width: 4),
                              Text(
                                noteMoyenne > 0
                                    ? '${noteMoyenne.toStringAsFixed(1)} ($nombreAvis avis)'
                                    : 'Aucun avis',
                                style: AppConstants.bodyStyle.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationDetails() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails de la réservation',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            SizedBox(height: AppConstants.mediumPadding),

            _buildDetailRow(
              icon: Icons.confirmation_number,
              label: 'N° de réservation',
              value: widget.reservation.id,
            ),

            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: _formatDate(widget.reservation.date),
            ),

            _buildDetailRow(
              icon: Icons.access_time,
              label: 'Créneau',
              value: '${widget.reservation.heureDebut} - ${widget.reservation.heureFin}',
            ),

            _buildDetailRow(
              icon: Icons.schedule,
              label: 'Durée',
              value: '1 heure',
            ),

            _buildDetailRow(
              icon: Icons.event_available,
              label: 'Réservé le',
              value: _formatDateTime(widget.reservation.dateCreation),
            ),

            if (widget.reservation.dateAnnulation != null)
              _buildDetailRow(
                icon: Icons.cancel,
                label: 'Annulé le',
                value: _formatDateTime(widget.reservation.dateAnnulation!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations de paiement',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            const SizedBox(height: AppConstants.mediumPadding),

            _buildDetailRow(
              icon: Icons.account_balance_wallet,
              label: 'Mode de paiement',
              value: _getPaymentMethodName(widget.reservation.modePaiement),
            ),

            _buildDetailRow(
              icon: Icons.attach_money,
              label: 'Montant',
              value: '${widget.reservation.montant.toInt()} FCFA',
            ),

            if (widget.reservation.transactionId != null)
              _buildDetailRow(
                icon: Icons.receipt,
                label: 'ID Transaction',
                value: widget.reservation.transactionId!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCode() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          children: [
            Text(
              'QR Code d\'accès',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            SizedBox(height: AppConstants.mediumPadding),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: widget.reservation.qrCode,
                version: QrVersions.auto,
                size: 200.0,
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
              ),
            ),

            SizedBox(height: AppConstants.mediumPadding),

            Container(
              padding: EdgeInsets.all(AppConstants.mediumPadding),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.smallRadius),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info,
                    color: AppConstants.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Présentez ce QR code à l\'entrée du terrain pour confirmer votre accès.',
                      style: AppConstants.bodyStyle.copyWith(
                        fontSize: 12,
                        color: AppConstants.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'Code: ${widget.reservation.qrCode}',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final canCancel = _canCancelReservation();
    final isActiveReservation = _isReservationActive();

    return Column(
      children: [
        if (canCancel)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelReservation,
              icon: Icon(Icons.cancel),
              label: Text('Annuler la réservation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.errorColor,
                side: BorderSide(color: AppConstants.errorColor),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

        if (canCancel) SizedBox(height: AppConstants.smallPadding),

        // Bouton de partage uniquement pour les réservations actives
        if (isActiveReservation)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadReceipt,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.share),
              label: Text(_isDownloading ? 'Génération...' : 'Partager le reçu'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

        if (!canCancel && widget.reservation.statut == StatutReservation.payee) ...[
          const SizedBox(height: AppConstants.smallPadding),

          Text(
            'Annulation impossible moins de 2h avant le match',
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),

          SizedBox(width: AppConstants.mediumPadding),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                Text(
                  value,
                  style: AppConstants.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusText(StatutReservation statut) {
    switch (statut) {
      case StatutReservation.enAttente:
        return 'En attente';
      case StatutReservation.confirmee:
        return 'Confirmée';
      case StatutReservation.payee:
        return 'Payée';
      case StatutReservation.annulee:
        return 'Annulée';
      case StatutReservation.terminee:
        return 'Terminée';
    }
  }

  String _getPaymentMethodName(ModePaiement method) {
    switch (method) {
      case ModePaiement.orange:
        return 'Orange Money';
      case ModePaiement.wave:
        return 'Wave';
      case ModePaiement.free:
        return 'Free Money';
      case ModePaiement.especes:
        return 'Espèces';
    }
  }
}
