import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/reservation.dart';
import '../models/terrain.dart';
import '../constants/app_constants.dart';

class PdfReceiptService {
  static final PdfReceiptService _instance = PdfReceiptService._internal();
  factory PdfReceiptService() => _instance;
  PdfReceiptService._internal();

  /// Génère et partage le reçu PDF
  Future<bool> shareReceiptPDF({
    required Reservation reservation,
    required Terrain terrain,
  }) async {
    try {
      // Générer le PDF
      final pdf = await _generateReceiptPDF(reservation, terrain);
      final pdfBytes = await pdf.save();
      
      // Utiliser le système de partage natif
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Recu_${reservation.id}.pdf',
      );
      
      return true;
    } catch (e) {
      print('❌ Erreur génération reçu PDF: $e');
      return false;
    }
  }

  /// Génère le PDF du reçu
  Future<pw.Document> _generateReceiptPDF(Reservation reservation, Terrain terrain) async {
    final pdf = pw.Document();
    
    // Utiliser des polices par défaut pour éviter les erreurs de chargement
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

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
          'Réservation de terrain de minifoot',
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
              _formatDate(DateTime.now()),
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
                child: _buildDetailRow('Date:', _formatDate(reservation.date), font: font, fontBold: fontBold),
              ),
              pw.Expanded(
                child: _buildDetailRow('Créneau:', '${reservation.heureDebut} - ${reservation.heureFin}', font: font, fontBold: fontBold),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildDetailRow('Durée:', '1 heure', font: font, fontBold: fontBold),
              ),
              pw.Expanded(
                child: _buildDetailRow('Réservé le:', _formatDate(reservation.dateCreation), font: font, fontBold: fontBold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ligne de détail
  pw.Widget _buildDetailRow(String label, String value, {required pw.Font font, required pw.Font fontBold}) {
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

  /// Formate une date
  String _formatDate(DateTime date) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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