import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/Authentification/auth_service.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/reservation/reservation_service.dart';
import '../../models/terrain.dart';
import '../../models/terrain_extended.dart';
import '../../models/user.dart';
import '../../models/reservation.dart';
import '../../models/reservation_extended.dart';
import '../../models/enums.dart';
import 'mes_terrains_screen.dart';
import 'add_terrain_screen.dart';
import 'terrain_reservations_screen.dart';
import 'planning_reservations_screen.dart';
import '../qr_scanner/qr_scanner_screen.dart';

class GerantDashboardScreen extends StatefulWidget {
  @override
  _GerantDashboardScreenState createState() => _GerantDashboardScreenState();
}

class _GerantDashboardScreenState extends State<GerantDashboardScreen> {
  final TerrainService _terrainService = TerrainService();
  final ReservationService _reservationService = ReservationService();
  final AuthService _authService = AuthService();

  List<Terrain> _mesTerrains = [];
  List<Reservation> _reservationsRecentes = [];
  Map<String, dynamic> _statistiques = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Charger les terrains du gérant
      final terrains = await _terrainService.getTerrainsByGerant(user.id);
      
      // Charger toutes les réservations du gérant
      final reservations = await _reservationService.getGerantReservations(user.id);
      
      // Trier par date et prendre les 5 plus récentes
      reservations.sort((a, b) => b.date.compareTo(a.date));
      final reservationsRecentes = reservations.take(5).toList();

      // Calculer les statistiques
      final stats = await _calculateStatistics(terrains, reservations);

      if (mounted) {
        setState(() {
          _mesTerrains = terrains;
          _reservationsRecentes = reservationsRecentes;
          _statistiques = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _calculateStatistics(List<Terrain> terrains, List<Reservation> reservations) async {
    final now = DateTime.now();
    final debutMois = DateTime(now.year, now.month, 1);
    
    // Gérer le cas où on est en janvier (mois précédent = décembre de l'année précédente)
    final debutMoisPrecedent = now.month == 1 
        ? DateTime(now.year - 1, 12, 1)
        : DateTime(now.year, now.month - 1, 1);
    final finMoisPrecedent = DateTime(now.year, now.month, 0, 23, 59, 59);
    
    // Réservations de ce mois
    final reservationsMois = reservations.where((r) => 
      r.date.isAfter(debutMois)
    ).toList();

    // Réservations du mois précédent (pour comparaison)
    final reservationsMoisPrecedent = reservations.where((r) => 
      r.date.isAfter(debutMoisPrecedent) && r.date.isBefore(finMoisPrecedent)
    ).toList();

    // Réservations confirmées de ce mois (pour les statistiques d'occupation)
    final reservationsConfirmees = reservationsMois.where((r) => 
      r.statut == StatutReservation.confirmee
    ).toList();

    // Calcul du chiffre d'affaires du mois (toutes les réservations payées)
    double chiffreAffaires = 0;
    double chiffreAffairePotentiel = 0; // CA total si toutes les réservations étaient payées
    int reservationsPayees = 0;
    int reservationsAvances = 0;
    
    for (var reservation in reservationsMois) {
      chiffreAffairePotentiel += reservation.montant;
      
      // Inclure toutes les réservations où de l'argent a été encaissé
      if (reservation.statut == StatutReservation.payee) {
        // Réservation entièrement payée
        chiffreAffaires += reservation.montant;
        reservationsPayees++;
      } else if (reservation.statut == StatutReservation.avance) {
        // Réservation avec avance payée
        chiffreAffaires += reservation.montantAvance;
        reservationsAvances++;
      } else if (reservation.statut == StatutReservation.terminee) {
        // Réservation terminée (supposée payée)
        chiffreAffaires += reservation.montant;
        reservationsPayees++;
      }
    }

    // Calcul du CA du mois précédent (pour comparaison)
    double chiffreAffairesPrecedent = 0;
    for (var reservation in reservationsMoisPrecedent) {
      if (reservation.statut == StatutReservation.payee || 
          reservation.statut == StatutReservation.terminee) {
        chiffreAffairesPrecedent += reservation.montant;
      } else if (reservation.statut == StatutReservation.avance) {
        chiffreAffairesPrecedent += reservation.montantAvance;
      }
    }

    // Calcul de l'évolution
    double evolutionCA = 0;
    if (chiffreAffairesPrecedent > 0) {
      evolutionCA = ((chiffreAffaires - chiffreAffairesPrecedent) / chiffreAffairesPrecedent) * 100;
    }

    print('💰 CA du mois: ${chiffreAffaires.toInt()} FCFA (${reservationsPayees} payées, ${reservationsAvances} avances)');
    print('📈 Évolution CA: ${evolutionCA.toStringAsFixed(1)}% par rapport au mois précédent');

    // Réservations aujourd'hui
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final demain = aujourdhui.add(Duration(days: 1));
    final reservationsAujourdhui = reservations.where((r) => 
      r.date.isAfter(aujourdhui) && 
      r.date.isBefore(demain)
    ).length;

    return {
      'nombreTerrains': terrains.length,
      'reservationsMois': reservationsMois.length,
      'chiffreAffairesMois': chiffreAffaires,
      'chiffreAffairePotentiel': chiffreAffairePotentiel,
      'chiffreAffairesPrecedent': chiffreAffairesPrecedent,
      'evolutionCA': evolutionCA,
      'reservationsPayees': reservationsPayees,
      'reservationsAvances': reservationsAvances,
      'reservationsAujourdhui': reservationsAujourdhui,
      'tauxOccupation': terrains.isNotEmpty ? (reservationsConfirmees.length / (terrains.length * 30 * 8)) * 100 : 0, // Approximation
      'tauxPaiement': reservationsMois.isNotEmpty ? ((reservationsPayees + reservationsAvances) / reservationsMois.length) * 100 : 0, // Pourcentage de réservations payées
    };
  }

  /// Formate les montants pour un affichage lisible
  String _formatMontant(double montant) {
    if (montant >= 1000000) {
      return '${(montant / 1000000).toStringAsFixed(1)}M';
    } else if (montant >= 1000) {
      return '${(montant / 1000).toStringAsFixed(0)}K';
    } else {
      return '${montant.toInt()}';
    }
  }

  /// Crée le texte d'évolution
  String _buildEvolutionText(double evolution) {
    if (evolution == 0) return '';
    return '${evolution > 0 ? '+' : ''}${evolution.toStringAsFixed(1)}%';
  }

  /// Crée l'icône d'évolution
  Widget _buildEvolutionIcon(double evolution) {
    if (evolution == 0) return SizedBox.shrink();
    
    return Icon(
      evolution > 0 ? Icons.trending_up : Icons.trending_down,
      size: 16,
      color: evolution > 0 ? Colors.green : Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec salutation
                _buildHeader(user),

                SizedBox(height: AppConstants.largePadding),

                // Actions rapides
                _buildQuickActions(),

                SizedBox(height: AppConstants.largePadding),

                // Statistiques
                _buildStatistiques(),

                SizedBox(height: AppConstants.largePadding),

                // Mes terrains
                _buildMesTerrains(),

                SizedBox(height: AppConstants.largePadding),

                // Réservations récentes
                _buildReservationsRecentes(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    return Container(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      decoration: BoxDecoration(
        gradient: AppConstants.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour ${user?.nom ?? 'Gérant'} !',
                  style: AppConstants.subHeadingStyle.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: AppConstants.smallPadding),
                Text(
                  'Gérez vos terrains facilement',
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.business,
            color: Colors.white,
            size: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: AppConstants.subHeadingStyle,
        ),
        SizedBox(height: AppConstants.mediumPadding),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_business,
                title: 'Ajouter terrain',
                subtitle: 'Nouveau terrain',
                color: AppConstants.primaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AddTerrainScreen()),
                  );
                },
              ),
            ),
            SizedBox(width: AppConstants.mediumPadding),
            Expanded(
              child: _buildActionCard(
                icon: Icons.qr_code_scanner,
                title: 'Scanner QR',
                subtitle: 'Valider réservation',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => QRScannerScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: AppConstants.mediumPadding),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.business_center,
                title: 'Mes terrains',
                subtitle: 'Gérer mes terrains',
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => MesTerrainsScreen()),
                  );
                },
              ),
            ),
            SizedBox(width: AppConstants.mediumPadding),
            Expanded(
              child: _buildActionCard(
                icon: Icons.event_note,
                title: 'Planning',
                subtitle: 'Toutes réservations',
                color: Colors.blue,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PlanningReservationsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(height: AppConstants.smallPadding),
            Text(
              title,
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: AppConstants.bodyStyle.copyWith(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistiques() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Statistiques du mois',
              style: AppConstants.subHeadingStyle,
            ),
            SizedBox(width: 8),
            Tooltip(
              message: 'CA = Réservations payées + Avances reçues',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: AppConstants.mediumPadding),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.business,
                title: 'Terrains',
                value: '${_statistiques['nombreTerrains'] ?? 0}',
                color: AppConstants.primaryColor,
              ),
            ),
            SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: _buildStatCard(
                icon: Icons.event_available,
                title: 'Réservations',
                value: '${_statistiques['reservationsMois'] ?? 0}',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        SizedBox(height: AppConstants.smallPadding),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.monetization_on,
                title: 'CA du mois',
                value: '${_formatMontant(_statistiques['chiffreAffairesMois'] ?? 0)} FCFA',
                color: Colors.green,
                subtitle: _buildEvolutionText(_statistiques['evolutionCA'] ?? 0),
                trailing: _buildEvolutionIcon(_statistiques['evolutionCA'] ?? 0),
              ),
            ),
            SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: _buildStatCard(
                icon: Icons.today,
                title: 'Aujourd\'hui',
                value: '${_statistiques['reservationsAujourdhui'] ?? 0}',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: AppConstants.smallPadding),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.payment,
                title: 'Payées',
                value: '${_statistiques['reservationsPayees'] ?? 0}',
                color: Colors.blue,
              ),
            ),
            SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: _buildStatCard(
                icon: Icons.account_balance_wallet,
                title: 'Avances',
                value: '${_statistiques['reservationsAvances'] ?? 0}',
                color: Colors.purple,
              ),
            ),
            SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: _buildStatCard(
                icon: Icons.trending_up,
                title: 'Taux paiement',
                value: '${(_statistiques['tauxPaiement'] ?? 0).toInt()}%',
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              if (trailing != null) ...[
                SizedBox(width: 4),
                trailing,
              ],
            ],
          ),
          SizedBox(height: AppConstants.smallPadding),
          Text(
            value,
            style: AppConstants.subHeadingStyle.copyWith(
              color: color,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: AppConstants.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) 
            Text(
              subtitle,
              style: AppConstants.bodyStyle.copyWith(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildMesTerrains() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mes terrains',
              style: AppConstants.subHeadingStyle,
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => MesTerrainsScreen()),
                );
              },
              child: Text('Voir tout'),
            ),
          ],
        ),
        SizedBox(height: AppConstants.mediumPadding),
        _isLoading
            ? Center(child: CircularProgressIndicator())
            : _mesTerrains.isEmpty
                ? _buildEmptyTerrains()
                : SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mesTerrains.take(3).length,
                      itemBuilder: (context, index) {
                        return _buildTerrainMiniCard(_mesTerrains[index]);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildEmptyTerrains() {
    return Container(
      padding: EdgeInsets.all(AppConstants.largePadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_business,
            size: 48,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: AppConstants.mediumPadding),
          Text(
            'Aucun terrain ajouté',
            style: AppConstants.subHeadingStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: AppConstants.smallPadding),
          Text(
            'Commencez par ajouter votre premier terrain',
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppConstants.mediumPadding),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AddTerrainScreen()),
              );
            },
            icon: Icon(Icons.add),
            label: Text('Ajouter un terrain'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainMiniCard(Terrain terrain) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TerrainReservationsScreen(terrain: terrain),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: AppConstants.mediumPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.smallPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      terrain.nom,
                      style: AppConstants.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                terrain.ville,
                style: AppConstants.bodyStyle.copyWith(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: terrain.disponible 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      terrain.disponible ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 8,
                        color: terrain.disponible ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${terrain.prixHeure.toInt()} FCFA/h',
                    style: AppConstants.bodyStyle.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationsRecentes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Réservations récentes',
          style: AppConstants.subHeadingStyle,
        ),
        SizedBox(height: AppConstants.mediumPadding),
        _isLoading
            ? Center(child: CircularProgressIndicator())
            : _reservationsRecentes.isEmpty
                ? Container(
                    padding: EdgeInsets.all(AppConstants.largePadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        'Aucune réservation récente',
                        style: AppConstants.bodyStyle.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: _reservationsRecentes.take(3).map((reservation) {
                      return _buildReservationCard(reservation);
                    }).toList(),
                  ),
      ],
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    return Container(
      margin: EdgeInsets.only(bottom: AppConstants.smallPadding),
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatutColor(reservation.statut).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatutIcon(reservation.statut),
              color: _getStatutColor(reservation.statut),
              size: 20,
            ),
          ),
          SizedBox(width: AppConstants.mediumPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.nomUtilisateur,
                  style: AppConstants.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${reservation.date.day}/${reservation.date.month} - ${reservation.horairesFormatted}',
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${reservation.montant.toInt()} FCFA',
            style: AppConstants.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatutColor(StatutReservation statut) {
    switch (statut) {
      case StatutReservation.confirmee:
        return Colors.green;
      case StatutReservation.enAttente:
        return Colors.orange;
      case StatutReservation.avance:
        return Colors.blue;
      case StatutReservation.payee:
        return Colors.green;
      case StatutReservation.annulee:
        return Colors.red;
      case StatutReservation.terminee:
        return Colors.blue;
    }
  }

  IconData _getStatutIcon(StatutReservation statut) {
    switch (statut) {
      case StatutReservation.confirmee:
        return Icons.check_circle;
      case StatutReservation.enAttente:
        return Icons.schedule;
      case StatutReservation.avance:
        return Icons.account_balance_wallet;
      case StatutReservation.payee:
        return Icons.payment;
      case StatutReservation.annulee:
        return Icons.cancel;
      case StatutReservation.terminee:
        return Icons.done_all;
    }
  }
}