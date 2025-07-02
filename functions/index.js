const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Firebase Function pour servir les reçus via QR code
exports.getReceipt = functions.https.onRequest(async (req, res) => {
  try {
    // Configurer CORS
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    // Traiter les requêtes OPTIONS (preflight)
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // Extraire le code de réservation de l'URL
    const urlPath = req.path;
    const pathParts = urlPath.split('/');
    
    // URL format: /receipt/[RESERVATION_CODE]
    if (pathParts.length < 3 || pathParts[1] !== 'receipt') {
      res.status(400).send(generateErrorHTML('URL invalide'));
      return;
    }

    const reservationCode = pathParts[2];
    console.log('🔍 Recherche réservation avec code:', reservationCode);

    if (!reservationCode || reservationCode.length < 8) {
      res.status(400).send(generateErrorHTML('Code de réservation invalide'));
      return;
    }

    // Rechercher la réservation dans Firestore
    const reservationQuery = await db.collection('reservations')
      .where('reservationCode', '==', reservationCode)
      .limit(1)
      .get();

    if (reservationQuery.empty) {
      res.status(404).send(generateErrorHTML('Réservation non trouvée'));
      return;
    }

    const reservationDoc = reservationQuery.docs[0];
    const reservationData = reservationDoc.data();

    console.log('📋 Réservation trouvée:', reservationDoc.id);

    // Récupérer les informations du terrain
    const terrainDoc = await db.collection('terrains').doc(reservationData.terrainId).get();
    
    if (!terrainDoc.exists) {
      res.status(404).send(generateErrorHTML('Terrain non trouvé'));
      return;
    }

    const terrainData = terrainDoc.data();

    // Récupérer les informations de l'utilisateur
    const userDoc = await db.collection('users').doc(reservationData.joueurId).get();
    const userData = userDoc.exists ? userDoc.data() : { nom: 'Utilisateur' };

    // Générer le HTML du reçu
    const receiptHTML = generateReceiptHTML(reservationData, terrainData, userData, reservationDoc.id);
    
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.status(200).send(receiptHTML);

  } catch (error) {
    console.error('❌ Erreur Firebase Function:', error);
    res.status(500).send(generateErrorHTML('Erreur serveur'));
  }
});

// Génère le HTML du reçu
function generateReceiptHTML(reservation, terrain, user, reservationId) {
  const userName = user.nom || 'Utilisateur';
  const userPhone = user.telephone || '';
  const isPaiementAvance = reservation.isPaiementAvance || false;
  
  // Formatter la date
  const reservationDate = reservation.date.toDate();
  const dateStr = formatDate(reservationDate);
  
  return `
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
            border: none;
            cursor: pointer;
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
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; border: 1px solid #ddd; }
            .actions { display: none; }
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
            <div class="status-badge ${isPaiementAvance ? 'status-avance' : 'status-payee'}">
                ${isPaiementAvance ? '🟠 Paiement en Avance' : '🟢 Paiement Complet'}
            </div>
            
            <div class="info-section">
                <div class="info-title">📋 Informations de la Réservation</div>
                <div class="info-row">
                    <span class="info-label">N° de réservation</span>
                    <span class="info-value">${reservationId}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Date</span>
                    <span class="info-value">${dateStr}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Créneau</span>
                    <span class="info-value">${reservation.heureDebut} - ${reservation.heureFin}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Statut</span>
                    <span class="info-value">${getStatusText(reservation.statut)}</span>
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
                    <span class="info-value">${Math.round(terrain.prixHeure)} FCFA</span>
                </div>
            </div>

            <div class="info-section">
                <div class="info-title">👤 Client</div>
                <div class="info-row">
                    <span class="info-label">Nom</span>
                    <span class="info-value">${userName}</span>
                </div>
                ${userPhone ? `
                <div class="info-row">
                    <span class="info-label">Téléphone</span>
                    <span class="info-value">${userPhone}</span>
                </div>
                ` : ''}
            </div>

            <div class="financial-summary">
                <div class="info-title">💰 Résumé Financier</div>
                ${isPaiementAvance ? `
                <div class="info-row">
                    <span class="info-label">Total réservation</span>
                    <span class="info-value">${Math.round(reservation.montant)} FCFA</span>
                </div>
                <div class="info-row">
                    <span class="info-label">✅ Avance payée</span>
                    <span class="info-value" style="color: #4caf50;">${Math.round(reservation.montantAvance || reservation.montant * 0.5)} FCFA</span>
                </div>
                <div class="info-row">
                    <span class="info-label">🕐 Reste à payer</span>
                    <span class="info-value" style="color: #ff9800;">${Math.round(reservation.montantRestant || reservation.montant * 0.5)} FCFA</span>
                </div>
                <div class="total-amount">
                    💳 Avance Payée: ${Math.round(reservation.montantAvance || reservation.montant * 0.5)} FCFA
                </div>
                ` : `
                <div class="total-amount">
                    💳 Total Payé: ${Math.round(reservation.montant)} FCFA
                </div>
                `}
                <div class="info-row">
                    <span class="info-label">Mode de paiement</span>
                    <span class="info-value">${getPaymentMethodName(reservation.modePaiement)}</span>
                </div>
            </div>

            <div class="actions">
                <button class="btn" onclick="window.print()">🖨️ Imprimer</button>
                <button class="btn btn-secondary" onclick="downloadPDF()">📄 Télécharger PDF</button>
            </div>
        </div>

        <div class="footer">
            <p>📅 Émis le ${formatDateTime(new Date())}</p>
            <p>Merci d'avoir choisi KayFoot ! ⚽</p>
            <p style="font-size: 0.9em; color: #999;">
                Présentez ce reçu à l'entrée du terrain
            </p>
        </div>
    </div>

    <script>
        function downloadPDF() {
            alert('Fonctionnalité PDF en cours de développement');
        }
    </script>
</body>
</html>
  `;
}

// Génère une page d'erreur
function generateErrorHTML(message) {
  return `
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Erreur - KayFoot</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
        }
        .error-container {
            background: white;
            padding: 40px;
            border-radius: 15px;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            max-width: 400px;
        }
        .error-icon {
            font-size: 4em;
            margin-bottom: 20px;
        }
        .error-title {
            color: #e74c3c;
            font-size: 1.5em;
            margin-bottom: 15px;
        }
        .error-message {
            color: #666;
            margin-bottom: 30px;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="error-icon">❌</div>
        <div class="error-title">Erreur</div>
        <div class="error-message">${message}</div>
    </div>
</body>
</html>
  `;
}

// Utilitaires de formatage
function formatDate(date) {
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  const days = [
    'lundi', 'mardi', 'mercredi', 'jeudi',
    'vendredi', 'samedi', 'dimanche'
  ];
  const dayName = days[date.getDay()];
  const monthName = months[date.getMonth()];
  return `${dayName.charAt(0).toUpperCase() + dayName.slice(1)} ${date.getDate()} ${monthName} ${date.getFullYear()}`;
}

function formatDateTime(dateTime) {
  return `${dateTime.getDate().toString().padStart(2, '0')}/${(dateTime.getMonth() + 1).toString().padStart(2, '0')}/${dateTime.getFullYear()} à ${dateTime.getHours().toString().padStart(2, '0')}:${dateTime.getMinutes().toString().padStart(2, '0')}`;
}

function getStatusText(statut) {
  switch (statut) {
    case 'enAttente':
      return 'En attente';
    case 'confirmee':
      return 'Confirmée';
    case 'avance':
      return 'Avance payée';
    case 'payee':
      return 'Payée';
    case 'annulee':
      return 'Annulée';
    case 'terminee':
      return 'Terminée';
    default:
      return 'Inconnu';
  }
}

function getPaymentMethodName(method) {
  switch (method) {
    case 'orange':
      return 'Orange Money';
    case 'wave':
      return 'Wave';
    default:
      return 'Orange Money';
  }
}