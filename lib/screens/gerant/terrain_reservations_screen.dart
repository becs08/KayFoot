import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/reservation/reservation_service.dart';
import '../../models/terrain.dart';
import '../../models/reservation.dart';
import '../../models/reservation_extended.dart';
import '../../models/enums.dart';
import '../../utils/date_utils.dart';

class TerrainReservationsScreen extends StatefulWidget {
  final Terrain terrain;

  const TerrainReservationsScreen({Key? key, required this.terrain}) : super(key: key);

  @override
  _TerrainReservationsScreenState createState() => _TerrainReservationsScreenState();
}

class _TerrainReservationsScreenState extends State<TerrainReservationsScreen>
    with SingleTickerProviderStateMixin {
  final ReservationService _reservationService = ReservationService();

  late TabController _tabController;
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      final reservations = await _reservationService.getTerrainReservations(widget.terrain.id);

      if (mounted) {
        setState(() {
          _reservations = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement réservations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Reservation> _getReservationsByStatus(StatutReservation status) {
    return _reservations.where((r) => r.statut == status).toList()
      ..sort((a, b) => b.dateReservation.compareTo(a.dateReservation));
  }

  List<Reservation> _getReservationsForDate(DateTime date) {
    return _reservations.where((r) =>
      r.dateReservation.year == date.year &&
      r.dateReservation.month == date.month &&
      r.dateReservation.day == date.day
    ).toList()
      ..sort((a, b) => a.heureDebut.compareTo(b.heureDebut));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réservations',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              widget.terrain.nom,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadReservations,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistiques rapides
          Container(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            color: Colors.white,
            child: _buildQuickStats(),
          ),

          // Onglets
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppConstants.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppConstants.primaryColor,
              isScrollable: true,
              tabs: [
                Tab(text: 'Aujourd\'hui'),
                Tab(text: 'En attente'),
                Tab(text: 'Confirmées'),
                Tab(text: 'Toutes'),
              ],
            ),
          ),

          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildStatusTab(StatutReservation.enAttente),
                _buildStatusTab(StatutReservation.confirmee),
                _buildAllReservationsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReservationDialog,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('Nouvelle réservation'),
      ),
    );
  }

  Widget _buildQuickStats() {
    final today = DateTime.now();
    final reservationsAujourdhui = _getReservationsForDate(today).length;
    final enAttente = _getReservationsByStatus(StatutReservation.enAttente).length;
    final confirmees = _getReservationsByStatus(StatutReservation.confirmee).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.today,
            title: 'Aujourd\'hui',
            value: '$reservationsAujourdhui',
            color: AppConstants.primaryColor,
          ),
        ),
        SizedBox(width: AppConstants.mediumPadding),
        Expanded(
          child: _buildStatItem(
            icon: Icons.schedule,
            title: 'En attente',
            value: '$enAttente',
            color: Colors.orange,
          ),
        ),
        SizedBox(width: AppConstants.mediumPadding),
        Expanded(
          child: _buildStatItem(
            icon: Icons.check_circle,
            title: 'Confirmées',
            value: '$confirmees',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: AppConstants.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: AppConstants.bodyStyle.copyWith(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    final today = DateTime.now();
    final reservationsAujourdhui = _getReservationsForDate(today);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (reservationsAujourdhui.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'Aucune réservation aujourd\'hui',
        subtitle: 'Le terrain est libre toute la journée',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: reservationsAujourdhui.length,
        itemBuilder: (context, index) {
          return _buildReservationCard(reservationsAujourdhui[index]);
        },
      ),
    );
  }

  Widget _buildStatusTab(StatutReservation status) {
    final reservations = _getReservationsByStatus(status);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (reservations.isEmpty) {
      String title, subtitle;
      switch (status) {
        case StatutReservation.enAttente:
          title = 'Aucune demande en attente';
          subtitle = 'Toutes les réservations sont traitées';
          break;
        case StatutReservation.confirmee:
          title = 'Aucune réservation confirmée';
          subtitle = 'Aucune réservation n\'est confirmée pour le moment';
          break;
        default:
          title = 'Aucune réservation';
          subtitle = '';
      }

      return _buildEmptyState(
        icon: Icons.event_note,
        title: title,
        subtitle: subtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          return _buildReservationCard(reservations[index]);
        },
      ),
    );
  }

  Widget _buildAllReservationsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_reservations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        title: 'Aucune réservation',
        subtitle: 'Ce terrain n\'a pas encore de réservations',
      );
    }

    // Grouper les réservations par date
    Map<String, List<Reservation>> groupedReservations = {};
    for (var reservation in _reservations) {
      final dateKey = AppDateUtils.formatDate(reservation.dateReservation);
      groupedReservations.putIfAbsent(dateKey, () => []);
      groupedReservations[dateKey]!.add(reservation);
    }

    // Trier les dates
    final sortedDates = groupedReservations.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Plus récentes en premier

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final reservations = groupedReservations[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête de date
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
                child: Text(
                  date,
                  style: AppConstants.subHeadingStyle.copyWith(
                    color: AppConstants.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),

              // Réservations de cette date
              ...reservations.map((reservation) => _buildReservationCard(reservation)),

              SizedBox(height: AppConstants.mediumPadding),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: AppConstants.largePadding),
            Text(
              title,
              style: AppConstants.subHeadingStyle.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              SizedBox(height: AppConstants.smallPadding),
              Text(
                subtitle,
                style: AppConstants.bodyStyle.copyWith(
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    return Card(
      margin: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statut
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.nomUtilisateur,
                        style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
                      ),
                      if (reservation.telephoneUtilisateur != null)
                        Text(
                          reservation.telephoneUtilisateur!,
                          style: AppConstants.bodyStyle.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(reservation.statut),
              ],
            ),

            SizedBox(height: AppConstants.mediumPadding),

            // Informations de la réservation
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: AppDateUtils.formatDate(reservation.dateReservation),
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.access_time,
                    label: reservation.horairesFormatted,
                  ),
                ),
              ],
            ),

            SizedBox(height: AppConstants.smallPadding),

            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.monetization_on,
                    label: '${reservation.montantTotal.toInt()} FCFA',
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.schedule,
                    label: '${reservation.dureeHeures}h',
                  ),
                ),
              ],
            ),

            // Actions selon le statut
            if (reservation.statut == StatutReservation.enAttente) ...[
              SizedBox(height: AppConstants.mediumPadding),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateReservationStatus(
                        reservation,
                        StatutReservation.annulee,
                      ),
                      icon: Icon(Icons.close, size: 16),
                      label: Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateReservationStatus(
                        reservation,
                        StatutReservation.confirmee,
                      ),
                      icon: Icon(Icons.check, size: 16),
                      label: Text('Confirmer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (reservation.statut == StatutReservation.confirmee) ...[
              SizedBox(height: AppConstants.mediumPadding),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _updateReservationStatus(
                    reservation,
                    StatutReservation.terminee,
                  ),
                  icon: Icon(Icons.done_all, size: 16),
                  label: Text('Marquer comme terminée'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryColor,
                    side: BorderSide(color: AppConstants.primaryColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StatutReservation statut) {
    Color color;
    String text;
    IconData icon;

    switch (statut) {
      case StatutReservation.enAttente:
        color = Colors.orange;
        text = 'En attente';
        icon = Icons.schedule;
        break;
      case StatutReservation.confirmee:
        color = Colors.green;
        text = 'Confirmée';
        icon = Icons.check_circle;
        break;
      case StatutReservation.avance:
        color = Colors.blue;
        text = 'Avance payée';
        icon = Icons.account_balance_wallet;
        break;
      case StatutReservation.payee:
        color = Colors.green;
        text = 'Payée';
        icon = Icons.payment;
        break;
      case StatutReservation.annulee:
        color = Colors.red;
        text = 'Annulée';
        icon = Icons.cancel;
        break;
      case StatutReservation.terminee:
        color = Colors.blue;
        text = 'Terminée';
        icon = Icons.done_all;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: AppConstants.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateReservationStatus(
    Reservation reservation,
    StatutReservation newStatus,
  ) async {
    try {
      await _reservationService.updateReservationStatus(reservation.id, newStatus);

      String message;
      switch (newStatus) {
        case StatutReservation.confirmee:
          message = 'Réservation confirmée';
          break;
        case StatutReservation.avance:
          message = 'Avance validée';
          break;
        case StatutReservation.payee:
          message = 'Paiement validé';
          break;
        case StatutReservation.annulee:
          message = 'Réservation annulée';
          break;
        case StatutReservation.terminee:
          message = 'Réservation terminée';
          break;
        default:
          message = 'Statut mis à jour';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );

      await _loadReservations();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddReservationDialog() {
    // TODO: Implémenter le dialogue pour ajouter une réservation manuelle
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité à venir...')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
