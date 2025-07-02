import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../models/reservation.dart';
import '../../models/terrain.dart';
import '../../services/reservation/pdf_receipt_service.dart';
import '../../services/reservation/receipt_download_service.dart';
import '../home/home_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Reservation reservation;
  final Terrain terrain;

  const PaymentScreen({
    Key? key,
    required this.reservation,
    required this.terrain,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Services pour la gestion des reçus
  final PdfReceiptService _receiptService = PdfReceiptService();
  final ReceiptDownloadService _downloadService = ReceiptDownloadService();

  // États pour les actions de téléchargement/partage
  bool _isDownloading = false;
  bool _isSharing = false;
  bool _isCopying = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomeScreen()),
      (route) => false,
    );
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
    setState(() {
      _isDownloading = true;
    });

    try {
      final filePath = await _downloadService.downloadReceiptPDF(
        reservation: widget.reservation,
        terrain: widget.terrain,
      );

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reçu PDF téléchargé avec succès'),
            backgroundColor: AppConstants.successColor,
            action: filePath.contains('navigateur') ? null : SnackBarAction(
              label: 'Voir',
              onPressed: () {
                // Optionnel: ouvrir le fichier
              },
            ),
          ),
        );
      } else {
        _showError('Erreur lors du téléchargement du reçu PDF');
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
    setState(() {
      _isSharing = true;
    });

    try {
      final success = await _downloadService.shareReceiptPDF(
        reservation: widget.reservation,
        terrain: widget.terrain,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
    setState(() {
      _isCopying = true;
    });

    try {
      final success = await _downloadService.copyReservationDetails(
        reservation: widget.reservation,
        terrain: widget.terrain,
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
    try {
      final success = await _downloadService.shareReservationDetails(
        reservation: widget.reservation,
        terrain: widget.terrain,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Options de reçu',
                style: AppConstants.subHeadingStyle.copyWith(fontSize: 18),
              ),
              SizedBox(height: AppConstants.mediumPadding),

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Paiement confirmé'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: _navigateToHome,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          children: [
            // Animation de succès
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppConstants.successColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

            SizedBox(height: AppConstants.largePadding),

            Text(
              'Réservation confirmée !',
              style: AppConstants.headingStyle.copyWith(
                color: AppConstants.successColor,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppConstants.smallPadding),

            Text(
              'Votre paiement a été traité avec succès',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppConstants.largePadding),

            // Reçu de réservation
            SlideTransition(
              position: _slideAnimation,
              child: _buildReceipt(),
            ),

            SizedBox(height: AppConstants.largePadding),

            // QR Code
            _buildQRCode(),

            SizedBox(height: AppConstants.largePadding),

            // Boutons d'action
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceipt() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du reçu
            Center(
              child: Column(
                children: [
                  Text(
                    'REÇU DE RÉSERVATION',
                    style: AppConstants.subHeadingStyle.copyWith(
                      fontSize: 18,
                      color: AppConstants.primaryColor,
                    ),
                  ),

                  SizedBox(height: AppConstants.smallPadding),

                  Text(
                    'N° ${widget.reservation.id}',
                    style: AppConstants.bodyStyle.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppConstants.largePadding),

            Divider(),

            SizedBox(height: AppConstants.mediumPadding),

            // Détails de la réservation
            _buildReceiptRow('Terrain', widget.terrain.nom),
            _buildReceiptRow('Adresse', '${widget.terrain.adresse}, ${widget.terrain.ville}'),
            _buildReceiptRow('Date', _formatDate(widget.reservation.date)),
            _buildReceiptRow('Créneau', '${widget.reservation.heureDebut} - ${widget.reservation.heureFin}'),
            _buildReceiptRow('Durée', '1 heure'),

            SizedBox(height: AppConstants.mediumPadding),

            Divider(),

            SizedBox(height: AppConstants.mediumPadding),

            // Détails du paiement
            _buildReceiptRow('Mode de paiement', _getPaymentMethodName(widget.reservation.modePaiement)),
            if (widget.reservation.transactionId != null)
              _buildReceiptRow('ID Transaction', widget.reservation.transactionId!),
            _buildReceiptRow('Date de paiement', _formatDateTime(widget.reservation.dateCreation)),

            SizedBox(height: AppConstants.mediumPadding),

            Divider(),

            SizedBox(height: AppConstants.mediumPadding),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL PAYÉ',
                  style: AppConstants.subHeadingStyle.copyWith(
                    fontSize: 16,
                    color: AppConstants.primaryColor,
                  ),
                ),
                Text(
                  '${widget.reservation.montant.toInt()} FCFA',
                  style: AppConstants.subHeadingStyle.copyWith(
                    fontSize: 18,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.largePadding),

            // Note importante
            Container(
              padding: const EdgeInsets.all(AppConstants.mediumPadding),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                border: Border.all(
                  color: AppConstants.accentColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info,
                    color: AppConstants.accentColor,
                    size: 20,
                  ),
                  SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Présentez ce QR code à l\'entrée du terrain pour confirmer votre réservation.',
                      style: AppConstants.bodyStyle.copyWith(
                        fontSize: 12,
                        color: AppConstants.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.mediumPadding),

            // Indicateur d'action disponible
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.mediumPadding,
                vertical: AppConstants.smallPadding,
              ),
              decoration: BoxDecoration(
                color: AppConstants.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                border: Border.all(
                  color: AppConstants.successColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: AppConstants.successColor,
                    size: 16,
                  ),
                  //SizedBox(width: AppConstants.smallPadding),
                  Text(
                    'Téléchargez ou partagez votre reçu ci-dessous',
                    style: AppConstants.bodyStyle.copyWith(
                      fontSize: 10,
                      color: AppConstants.successColor,
                      fontWeight: FontWeight.w500,
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

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          children: [
            Text(
              'QR Code de réservation',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            const SizedBox(height: AppConstants.mediumPadding),

            Container(
              padding: const EdgeInsets.all(16),
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

            const SizedBox(height: AppConstants.mediumPadding),

            Text(
              'Code: ${widget.reservation.qrCode}',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [

        // Boutons d'action rapide
        Row(
          children: [
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
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),

            const SizedBox(width: AppConstants.smallPadding),

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
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppConstants.mediumPadding),

        // Lien vers les réservations
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
            // TODO: Naviguer vers l'écran de mes réservations
          },
          icon: const Icon(Icons.list_alt, size: 16),
          label: const Text('Voir mes réservations'),
        ),

        const SizedBox(height: AppConstants.mediumPadding),

        // Bouton principal de retour à l'accueil
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _navigateToHome,
            icon: const Icon(Icons.home),
            label: const Text(
              'Retour à l\'accueil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

      ],
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
