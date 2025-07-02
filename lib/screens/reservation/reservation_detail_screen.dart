import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_constants.dart';
import '../../models/reservation.dart';
import '../../models/terrain.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/terrain/terrain_image_service.dart';
import '../../services/reservation/reservation_service.dart';
import '../../services/profil/statistics_service.dart';
import '../../services/reservation/pdf_receipt_service.dart';
import '../../services/reservation/receipt_download_service.dart';
import 'package:flutter/services.dart';

class ReservationDetailScreen extends StatefulWidget {
  final Reservation reservation;

  const ReservationDetailScreen({super.key, required this.reservation});

  @override
  _ReservationDetailScreenState createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  Terrain? _terrain;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isSharing = false;
  bool _isCopying = false;
  final StatisticsService _statsService = StatisticsService();
  final TerrainImageService _imageService = TerrainImageService();
  final PdfReceiptService _receiptService = PdfReceiptService();
  final ReceiptDownloadService _downloadService = ReceiptDownloadService();

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
        title: const Text('Annuler la réservation'),
        content: const Column(
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
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: const Text('Oui, annuler'),
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
          const SnackBar(
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


  Future<void> _shareReceipt() async {
    if (_terrain == null) {
      _showError('Informations du terrain non disponibles');
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      final success = await _downloadService.shareReceiptPDF(
        reservation: widget.reservation,
        terrain: _terrain!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reçu PDF partagé avec succès'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } else {
        _showError('Erreur lors du partage du reçu PDF');
      }
    } catch (e) {
      _showError('Erreur lors du partage du reçu PDF');
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _copyReservationDetails() async {
    if (_terrain == null) {
      _showError('Informations du terrain non disponibles');
      return;
    }

    setState(() {
      _isCopying = true;
    });

    try {
      final success = await _downloadService.copyReservationDetails(
        reservation: widget.reservation,
        terrain: _terrain!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.copy, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Détails copiés dans le presse-papiers'),
              ],
            ),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } else {
        _showError('Erreur lors de la copie des détails');
      }
    } catch (e) {
      _showError('Erreur lors de la copie des détails');
    } finally {
      setState(() {
        _isCopying = false;
      });
    }
  }

  Future<void> _shareReservationDetails() async {
    if (_terrain == null) {
      _showError('Informations du terrain non disponibles');
      return;
    }

    try {
      final success = await _downloadService.shareReservationDetails(
        reservation: widget.reservation,
        terrain: _terrain!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.text_fields, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Détails complets copiés'),
              ],
            ),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } else {
        _showError('Erreur lors de la copie des détails');
      }
    } catch (e) {
      _showError('Erreur lors de la copie des détails');
    }
  }

  void _showReceiptOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Options de reçu',
                style: AppConstants.subHeadingStyle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: AppConstants.mediumPadding),

              // Télécharger PDF
              ListTile(
                leading: Icon(Icons.download, color: AppConstants.primaryColor),
                title: Text('Télécharger PDF'),
                subtitle: Text('Sauvegarder le reçu sur votre appareil'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadReceipt();
                },
              ),

              // Partager PDF
              ListTile(
                leading: Icon(Icons.share, color: AppConstants.primaryColor),
                title: Text('Partager PDF'),
                subtitle: Text('Partager le reçu PDF via vos applications'),
                onTap: () {
                  Navigator.pop(context);
                  _shareReceipt();
                },
              ),

              // Copier détails
              ListTile(
                leading: Icon(Icons.copy, color: AppConstants.primaryColor),
                title: Text('Copier les détails'),
                subtitle: Text('Copier les informations dans le presse-papiers'),
                onTap: () {
                  Navigator.pop(context);
                  _copyReservationDetails();
                },
              ),

              // Copier détails complets
              ListTile(
                leading: Icon(Icons.text_fields, color: AppConstants.primaryColor),
                title: Text('Copier le format complet'),
                subtitle: Text('Copier tous les détails sous forme de texte'),
                onTap: () {
                  Navigator.pop(context);
                  _shareReservationDetails();
                },
              ),

              SizedBox(height: AppConstants.smallPadding),
            ],
          ),
        );
      },
    );
  }

  bool _canCancelReservation() {
    if (widget.reservation.statut != StatutReservation.payee && 
        widget.reservation.statut != StatutReservation.avance) {
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
    // Une réservation est considérée comme active si elle est payée, confirmée ou en avance
    // et qu'elle n'est pas annulée ou terminée
    return widget.reservation.statut == StatutReservation.payee ||
           widget.reservation.statut == StatutReservation.confirmee ||
           widget.reservation.statut == StatutReservation.avance;
  }

  /// Calcule la durée de la réservation en heures
  String _calculateDuration() {
    try {
      final heureDebut = widget.reservation.heureDebut;
      final heureFin = widget.reservation.heureFin;

      // Parser les heures (format "HH:mm")
      final debutParts = heureDebut.split(':');
      final finParts = heureFin.split(':');

      final debutHeure = int.parse(debutParts[0]);
      final debutMinute = int.parse(debutParts[1]);
      final finHeure = int.parse(finParts[0]);
      final finMinute = int.parse(finParts[1]);

      // Convertir en minutes depuis minuit
      final debutTotalMinutes = debutHeure * 60 + debutMinute;
      final finTotalMinutes = finHeure * 60 + finMinute;

      // Calculer la différence
      final dureeMinutes = finTotalMinutes - debutTotalMinutes;

      // Convertir en format lisible
      if (dureeMinutes < 60) {
        return '$dureeMinutes minutes';
      } else {
        final heures = dureeMinutes ~/ 60;
        final minutes = dureeMinutes % 60;

        if (minutes == 0) {
          return heures == 1 ? '1 heure' : '$heures heures';
        } else {
          return heures == 1
              ? '1h${minutes.toString().padLeft(2, '0')}'
              : '${heures}h${minutes.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      print('❌ Erreur calcul durée: $e');
      return '1 heure'; // Valeur par défaut
    }
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

                  const SizedBox(height: AppConstants.mediumPadding),

                  // Informations du terrain
                  _buildTerrainInfo(),

                  const SizedBox(height: AppConstants.mediumPadding),

                  // Détails de la réservation
                  _buildReservationDetails(),

                  const SizedBox(height: AppConstants.mediumPadding),

                  // Informations de paiement
                  _buildPaymentInfo(),

                  const SizedBox(height: AppConstants.mediumPadding),

                  // QR Code (si applicable)
                  if (widget.reservation.statut == StatutReservation.payee ||
                      widget.reservation.statut == StatutReservation.confirmee ||
                      widget.reservation.statut == StatutReservation.avance)
                    _buildQRCode(),

                  const SizedBox(height: AppConstants.largePadding),

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
        message = 'Avance payée - Reste à payer le jour du match';
        icon = Icons.payment;
        break;
      case StatutReservation.confirmee:
        color = Colors.blue;
        message = 'Votre réservation est confirmée';
        icon = Icons.check_circle_outline;
        break;
      case StatutReservation.avance:
        color = Colors.orange;
        message = 'Avance payée - Reste à payer le jour du match';
        icon = Icons.payment;
        break;
      case StatutReservation.payee:
        color = AppConstants.successColor;
        message = 'Réservation confirmée';
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
        padding: const EdgeInsets.all(AppConstants.mediumPadding),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),

            const SizedBox(width: AppConstants.mediumPadding),

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

                  const SizedBox(height: 4),

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

  Widget _buildPaymentStatusBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.largePadding,
          vertical: AppConstants.mediumPadding,
        ),
        decoration: BoxDecoration(
          color: widget.reservation.isPaiementAvance
              ? Colors.orange.shade100
              : Colors.green.shade100,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: widget.reservation.isPaiementAvance
                ? Colors.orange.shade300
                : Colors.green.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildTerrainInfo() {
    if (_terrain == null) {
      return const Card(
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
                _buildTerrainThumbnail(),

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
              value: _calculateDuration(),
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

            // Affichage selon le type de paiement
            if (widget.reservation.isPaiementAvance) ...[
              _buildDetailRow(
                icon: Icons.account_balance,
                label: 'Total réservation',
                value: '${widget.reservation.montant.toInt()} FCFA',
              ),
              _buildDetailRow(
                icon: Icons.payment,
                label: 'Avance payée',
                value: '${widget.reservation.montantAvance.toInt()} FCFA',
                valueColor: Colors.green.shade600,
              ),
              _buildDetailRow(
                icon: Icons.schedule_outlined,
                label: 'Reste à payer',
                value: '${widget.reservation.montantRestant.toInt()} FCFA',
                valueColor: Colors.orange.shade600,
              ),

              // Note sur le paiement restant
              Container(
                margin: EdgeInsets.only(top: AppConstants.smallPadding),
                padding: EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600, size: 16),
                    SizedBox(width: AppConstants.smallPadding),
                    Expanded(
                      child: Text(
                        'Le montant restant sera à régler le jour du match',
                        style: AppConstants.bodyStyle.copyWith(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildDetailRow(
                icon: Icons.attach_money,
                label: 'Montant total payé',
                value: '${widget.reservation.montant.toInt()} FCFA',
                valueColor: Colors.green.shade600,
              ),
            ],

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

        if (canCancel) SizedBox(height: AppConstants.mediumPadding),

        // Boutons de reçu pour les réservations actives
        if (isActiveReservation) ...[
          // Bouton principal de téléchargement/partage
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isDownloading || _isSharing || _isCopying) ? null : _showReceiptOptions,
              icon: (_isDownloading || _isSharing || _isCopying)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.receipt_long),
              label: Text(
                _isDownloading ? 'Téléchargement...' :
                _isSharing ? 'Partage...' :
                _isCopying ? 'Copie...' :
                'Options de reçu'
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          SizedBox(height: AppConstants.smallPadding),

          // Boutons d'action rapide
          Row(
            children: [
              // Téléchargement rapide
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isDownloading || _isSharing || _isCopying) ? null : _downloadReceipt,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    _isDownloading ? 'Téléch...' : 'Télécharger',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              SizedBox(width: AppConstants.smallPadding),

              // Partage rapide
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isDownloading || _isSharing || _isCopying) ? null : _shareReceipt,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                          ),
                        )
                      : const Icon(Icons.share, size: 18),
                  label: Text(
                    _isSharing ? 'Partage...' : 'Partager',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              SizedBox(width: AppConstants.smallPadding),

              // Copie rapide
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isDownloading || _isSharing || _isCopying) ? null : _copyReservationDetails,
                  icon: _isCopying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                          ),
                        )
                      : const Icon(Icons.copy, size: 18),
                  label: Text(
                    _isCopying ? 'Copie...' : 'Copier',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],

        if (!canCancel && (widget.reservation.statut == StatutReservation.payee || 
                          widget.reservation.statut == StatutReservation.avance)) ...[
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
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),

          const SizedBox(width: AppConstants.mediumPadding),

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
                    color: valueColor,
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
        return 'Avance payée';
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

  String _getPaymentMethodName(ModePaiement method) {
    switch (method) {
      case ModePaiement.orange:
        return 'Orange Money';
      case ModePaiement.wave:
        return 'Wave';
    }
  }

  /// 🖼️ Widget pour afficher la miniature du terrain dans les détails de réservation
  Widget _buildTerrainThumbnail() {
    if (_terrain == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        ),
        child: const Icon(
          Icons.sports_soccer,
          color: AppConstants.primaryColor,
          size: 30,
        ),
      );
    }

    final thumbnailUrl = _imageService.getThumbnailUrl(_terrain!.photos);

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        child: thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                width: 60,
                height: 60,
                placeholder: (context, url) => Container(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  child: const Icon(
                    Icons.sports_soccer,
                    color: AppConstants.primaryColor,
                    size: 30,
                  ),
                ),
              )
            : Container(
                color: AppConstants.primaryColor.withOpacity(0.1),
                child: const Icon(
                  Icons.sports_soccer,
                  color: AppConstants.primaryColor,
                  size: 30,
                ),
              ),
      ),
    );
  }
}
