import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../constants/app_constants.dart';
import '../../models/reservation.dart';
import '../../models/terrain.dart';
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

  void _shareReceipt() {
    // TODO: Implémenter le partage du reçu
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité de partage à venir')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Paiement confirmé'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
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
            
            SizedBox(height: AppConstants.largePadding),
            
            // Note importante
            Container(
              padding: EdgeInsets.all(AppConstants.mediumPadding),
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
                  Icon(
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
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
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
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          children: [
            Text(
              'QR Code de réservation',
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
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _navigateToHome,
            icon: Icon(Icons.home),
            label: Text(
              'Retour à l\'accueil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareReceipt,
                icon: Icon(Icons.share),
                label: Text('Partager'),
              ),
            ),
            
            SizedBox(width: AppConstants.mediumPadding),
            
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Télécharger le reçu en PDF
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Téléchargement à venir')),
                  );
                },
                icon: Icon(Icons.download),
                label: Text('Télécharger'),
              ),
            ),
          ],
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
            // TODO: Naviguer vers l'écran de mes réservations
          },
          child: Text('Voir mes réservations'),
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