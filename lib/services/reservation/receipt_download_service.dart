import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
// Package share_plus à ajouter au pubspec.yaml si nécessaire
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/reservation.dart';
import '../../models/terrain.dart';
import '../../constants/app_constants.dart';
import 'pdf_receipt_service.dart';

class ReceiptDownloadService {
  static final ReceiptDownloadService _instance = ReceiptDownloadService._internal();
  factory ReceiptDownloadService() => _instance;
  ReceiptDownloadService._internal();

  final PdfReceiptService _pdfService = PdfReceiptService();

  /// Partage le reçu PDF via le système de partage natif
  Future<bool> shareReceiptPDF({
    required Reservation reservation,
    required Terrain terrain,
  }) async {
    try {
      return await _pdfService.shareReceiptPDF(
        reservation: reservation,
        terrain: terrain,
      );
    } catch (e) {
      print('❌ Erreur partage reçu PDF: $e');
      return false;
    }
  }

  /// Télécharge et sauvegarde le reçu PDF localement
  Future<String?> downloadReceiptPDF({
    required Reservation reservation,
    required Terrain terrain,
  }) async {
    try {
      // Demander les permissions si nécessaire
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Permission de stockage refusée');
        }
      }

      // Utiliser le service PDF pour générer le document
      // Nous créons une méthode temporaire pour générer le PDF ici
      final pdf = _generateReceiptPDF(reservation, terrain);
      final pdfBytes = await pdf.save();

      // Définir le chemin de sauvegarde
      String? filePath;
      if (kIsWeb) {
        // Pour le web, utiliser le système de téléchargement du navigateur
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Recu_${reservation.id}.pdf',
        );
        return 'Fichier téléchargé via le navigateur';
      } else {
        // Pour mobile, sauvegarder dans le dossier Documents
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'Recu_${reservation.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${directory.path}/$fileName');
        
        await file.writeAsBytes(pdfBytes);
        filePath = file.path;
      }

      return filePath;
    } catch (e) {
      print('❌ Erreur téléchargement reçu PDF: $e');
      return null;
    }
  }

  /// Copie les détails de la réservation dans le presse-papiers
  Future<bool> copyReservationDetails({
    required Reservation reservation,
    required Terrain terrain,
  }) async {
    try {
      final details = _formatReservationDetails(reservation, terrain);
      await Clipboard.setData(ClipboardData(text: details));
      return true;
    } catch (e) {
      print('❌ Erreur copie détails réservation: $e');
      return false;
    }
  }

  /// Partage les détails de la réservation sous forme de texte
  Future<bool> shareReservationDetails({
    required Reservation reservation,
    required Terrain terrain,
  }) async {
    try {
      final details = _formatReservationDetails(reservation, terrain);
      // Pour l'instant, nous copions dans le presse-papiers
      // Le package share_plus peut être ajouté plus tard pour un vrai partage
      await Clipboard.setData(ClipboardData(text: details));
      return true;
    } catch (e) {
      print('❌ Erreur partage détails réservation: $e');
      return false;
    }
  }

  /// Formate les détails de la réservation pour le partage/copie
  String _formatReservationDetails(Reservation reservation, Terrain terrain) {
    final buffer = StringBuffer();
    
    buffer.writeln('🏟️ DÉTAILS DE RÉSERVATION - KAYFOOT');
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln();
    
    // Informations générales
    buffer.writeln('📄 N° de réservation: ${reservation.id}');
    buffer.writeln('📅 Date: ${_formatDate(reservation.date)}');
    buffer.writeln('⏰ Créneau: ${reservation.heureDebut} - ${reservation.heureFin}');
    buffer.writeln('⏱️ Durée: ${_calculateDuration(reservation)}');
    buffer.writeln('📊 Statut: ${_getStatusText(reservation.statut)}');
    buffer.writeln();
    
    // Terrain
    buffer.writeln('🏟️ TERRAIN');
    buffer.writeln('Nom: ${terrain.nom}');
    buffer.writeln('Adresse: ${terrain.adresse}, ${terrain.ville}');
    buffer.writeln('Prix: ${terrain.prixHeure.toInt()} FCFA/heure');
    buffer.writeln();
    
    // Paiement
    buffer.writeln('💳 PAIEMENT');
    buffer.writeln('Montant: ${reservation.montant.toInt()} FCFA');
    buffer.writeln('Mode: ${_getPaymentMethodName(reservation.modePaiement)}');
    if (reservation.transactionId != null) {
      buffer.writeln('Transaction: ${reservation.transactionId}');
    }
    buffer.writeln();
    
    // QR Code si applicable
    if (reservation.statut == StatutReservation.payee || 
        reservation.statut == StatutReservation.confirmee) {
      buffer.writeln('🔐 CODE D\'ACCÈS');
      buffer.writeln('QR Code: ${reservation.qrCode}');
      buffer.writeln();
    }
    
    // Informations supplémentaires
    buffer.writeln('📋 INFORMATIONS SUPPLÉMENTAIRES');
    buffer.writeln('Réservé le: ${_formatDateTime(reservation.dateCreation)}');
    if (reservation.dateAnnulation != null) {
      buffer.writeln('Annulé le: ${_formatDateTime(reservation.dateAnnulation!)}');
    }
    buffer.writeln();
    
    buffer.writeln('─────────────────────────────────');
    buffer.writeln('Merci d\'avoir choisi KayFoot ! 🏆');
    buffer.writeln('Pour toute question, contactez-nous.');
    
    return buffer.toString();
  }

  /// Calcule la durée de la réservation
  String _calculateDuration(Reservation reservation) {
    try {
      final heureDebut = reservation.heureDebut;
      final heureFin = reservation.heureFin;

      final debutParts = heureDebut.split(':');
      final finParts = heureFin.split(':');

      final debutHeure = int.parse(debutParts[0]);
      final debutMinute = int.parse(debutParts[1]);
      final finHeure = int.parse(finParts[0]);
      final finMinute = int.parse(finParts[1]);

      final debutTotalMinutes = debutHeure * 60 + debutMinute;
      final finTotalMinutes = finHeure * 60 + finMinute;
      final dureeMinutes = finTotalMinutes - debutTotalMinutes;

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
      return '1 heure';
    }
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

  /// Génère le PDF du reçu (copie de la méthode du PdfReceiptService)
  pw.Document _generateReceiptPDF(Reservation reservation, Terrain terrain) {
    final pdf = pw.Document();

    // Utiliser des polices par défaut
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              _buildPDFHeader(font: fontBold),

              pw.SizedBox(height: 30),

              // Informations du reçu
              _buildReceiptInfo(reservation, font: font, fontBold: fontBold),

              pw.SizedBox(height: 20),

              // Informations du terrain
              _buildTerrainInfo(terrain, font: font, fontBold: fontBold),

              pw.SizedBox(height: 20),

              // Détails de la réservation
              _buildReservationDetails(reservation, font: font, fontBold: fontBold),

              pw.SizedBox(height: 20),

              // Résumé financier
              _buildFinancialSummary(reservation, font: font, fontBold: fontBold),

              pw.SizedBox(height: 20),

              // QR Code si applicable
              if (reservation.statut == StatutReservation.payee ||
                  reservation.statut == StatutReservation.confirmee)
                _buildQRCodeSection(reservation, font: font, fontBold: fontBold),

              pw.Spacer(),

              // Pied de page
              _buildPDFFooter(font: font),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// En-tête du PDF
  pw.Widget _buildPDFHeader({required pw.Font font}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          AppConstants.appName.toUpperCase(),
          style: pw.TextStyle(
            font: font,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green700,
          ),
        ),
        pw.Text(
          'Réservation de terrain de football',
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColors.green700,
        ),
      ],
    );
  }

  /// Informations du reçu
  pw.Widget _buildReceiptInfo(Reservation reservation, {required pw.Font font, required pw.Font fontBold}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'REÇU DE RÉSERVATION',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 18,
                color: PdfColors.green700,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'N° ${reservation.id}',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Date d\'émission',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              _formatDatePDF(DateTime.now()),
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 10),
            _buildStatusBadge(reservation.statut, font: font),
          ],
        ),
      ],
    );
  }

  /// Badge de statut
  pw.Widget _buildStatusBadge(StatutReservation statut, {required pw.Font font}) {
    PdfColor color;
    String text;

    switch (statut) {
      case StatutReservation.payee:
        color = PdfColors.green;
        text = 'PAYÉE';
        break;
      case StatutReservation.confirmee:
        color = PdfColors.blue;
        text = 'CONFIRMÉE';
        break;
      case StatutReservation.enAttente:
        color = PdfColors.orange;
        text = 'EN ATTENTE';
        break;
      case StatutReservation.annulee:
        color = PdfColors.red;
        text = 'ANNULÉE';
        break;
      case StatutReservation.terminee:
        color = PdfColors.grey;
        text = 'TERMINÉE';
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// Informations du terrain
  pw.Widget _buildTerrainInfo(Terrain terrain, {required pw.Font font, required pw.Font fontBold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TERRAIN RÉSERVÉ',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            terrain.nom,
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${terrain.adresse}, ${terrain.ville}',
            style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${terrain.prixHeure.toInt()} FCFA/heure',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Détails de la réservation
  pw.Widget _buildReservationDetails(Reservation reservation, {required pw.Font font, required pw.Font fontBold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DÉTAILS DE LA RÉSERVATION',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildDetailRowPDF('Date:', _formatDatePDF(reservation.date), font: font, fontBold: fontBold),
              ),
              pw.Expanded(
                child: _buildDetailRowPDF('Créneau:', '${reservation.heureDebut} - ${reservation.heureFin}', font: font, fontBold: fontBold),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildDetailRowPDF('Durée:', _calculateDuration(reservation), font: font, fontBold: fontBold),
              ),
              pw.Expanded(
                child: _buildDetailRowPDF('Réservé le:', _formatDatePDF(reservation.dateCreation), font: font, fontBold: fontBold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ligne de détail PDF
  pw.Widget _buildDetailRowPDF(String label, String value, {required pw.Font font, required pw.Font fontBold}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
      ],
    );
  }

  /// Résumé financier
  pw.Widget _buildFinancialSummary(Reservation reservation, {required pw.Font font, required pw.Font fontBold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Mode de paiement:',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Text(
                _getPaymentMethodName(reservation.modePaiement),
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            height: 1,
            color: PdfColors.grey400,
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MONTANT TOTAL:',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.green700,
                ),
              ),
              pw.Text(
                '${reservation.montant.toInt()} FCFA',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section QR Code
  pw.Widget _buildQRCodeSection(Reservation reservation, {required pw.Font font, required pw.Font fontBold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'QR CODE D\'ACCÈS',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 14,
                    color: PdfColors.green700,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Présentez ce QR code à l\'entrée du terrain pour confirmer votre accès.',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Code: ${reservation.qrCode}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: reservation.qrCode,
            width: 80,
            height: 80,
          ),
        ],
      ),
    );
  }

  /// Pied de page
  pw.Widget _buildPDFFooter({required pw.Font font}) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          height: 1,
          color: PdfColors.grey400,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Merci d\'avoir choisi ${AppConstants.appName} pour votre réservation !',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'Pour toute question, contactez-nous.',
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Formate une date pour PDF
  String _formatDatePDF(DateTime date) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}