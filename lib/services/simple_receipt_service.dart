import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reservation.dart';
import '../models/terrain.dart';
import '../constants/app_constants.dart';

class SimpleReceiptService {
  static final SimpleReceiptService _instance = SimpleReceiptService._internal();
  factory SimpleReceiptService() => _instance;
  SimpleReceiptService._internal();

  /// Génère et partage le reçu de réservation en texte
  Future<bool> shareReceipt({
    required Reservation reservation,
    required Terrain terrain,
    required BuildContext context,
  }) async {
    try {
      final receiptText = _generateReceiptText(reservation, terrain);

      // Copier dans le presse-papier
      await Clipboard.setData(ClipboardData(text: receiptText));

      // Afficher un dialog avec le reçu
      await _showReceiptDialog(context, receiptText, reservation, terrain);

      return true;
    } catch (e) {
      print('❌ Erreur génération reçu: $e');
      return false;
    }
  }

  /// Génère le texte du reçu
  String _generateReceiptText(Reservation reservation, Terrain terrain) {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('           ${AppConstants.appName.toUpperCase()}');
    buffer.writeln('      REÇU DE RÉSERVATION');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();

    // Informations de base
    buffer.writeln('N° de réservation: ${reservation.id}');
    buffer.writeln("Date d\\'émission: ${_formatDate(DateTime.now())}");
    buffer.writeln('Statut: ${_getStatusText(reservation.statut)}');
    buffer.writeln();

    // Terrain
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('TERRAIN RÉSERVÉ');
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('Nom: ${terrain.nom}');
    buffer.writeln('Adresse: ${terrain.adresse}, ${terrain.ville}');
    buffer.writeln('Prix: ${terrain.prixHeure.toInt()} FCFA/heure');
    buffer.writeln();

    // Détails réservation
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('DÉTAILS DE LA RÉSERVATION');
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('Date: ${_formatDate(reservation.date)}');
    buffer.writeln('Créneau: ${reservation.heureDebut} - ${reservation.heureFin}');
    buffer.writeln('Durée: 1 heure');
    buffer.writeln('Réservé le: ${_formatDate(reservation.dateCreation)}');
    buffer.writeln();

    // Paiement
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('INFORMATIONS DE PAIEMENT');
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('Mode de paiement: ${_getPaymentMethodName(reservation.modePaiement)}');
    buffer.writeln('MONTANT TOTAL: ${reservation.montant.toInt()} FCFA');

    if (reservation.transactionId != null) {
      buffer.writeln('ID Transaction: ${reservation.transactionId}');
    }
    buffer.writeln();

    // QR Code
    if (reservation.statut == StatutReservation.payee ||
        reservation.statut == StatutReservation.confirmee) {
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln("QR CODE D\\'ACCÈS");
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln('Code: ${reservation.qrCode}');
      buffer.writeln("Présentez ce code à l\\'entrée du terrain");
      buffer.writeln();
    }

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln("Merci d\\'avoir choisi ${AppConstants.appName} !");
    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
  }

  /// Affiche le dialog avec le reçu
  Future<void> _showReceiptDialog(
    BuildContext context,
    String receiptText,
    Reservation reservation,
    Terrain terrain,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.receipt,
                color: AppConstants.primaryColor,
              ),
              SizedBox(width: 8),
              Text('Reçu de réservation'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      receiptText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.accentColor.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: AppConstants.accentColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Le reçu a été copié dans votre presse-papier. Vous pouvez le coller dans n\\'importe quelle application.",
                            style: TextStyle(
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
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Copier à nouveau'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: receiptText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reçu copié dans le presse-papier'),
                    backgroundColor: AppConstants.successColor,
                  ),
                );
              },
            ),
            ElevatedButton(
              child: const Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Formate une date
  String _formatDate(DateTime date) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Texte du statut
  String _getStatusText(StatutReservation statut) {
    switch (statut) {
      case StatutReservation.enAttente:
        return 'EN ATTENTE';
      case StatutReservation.confirmee:
        return 'CONFIRMÉE';
      case StatutReservation.payee:
        return 'PAYÉE';
      case StatutReservation.annulee:
        return 'ANNULÉE';
      case StatutReservation.terminee:
        return 'TERMINÉE';
    }
  }

  /// Nom du mode de paiement
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
