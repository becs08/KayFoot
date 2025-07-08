import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/reservation/reservation_service.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/Authentification/auth_service.dart';
import '../../models/reservation.dart';
import '../../models/reservation_extended.dart';
import '../../models/terrain.dart';
import '../../models/enums.dart';
import '../../utils/date_utils.dart';

class PlanningReservationsScreen extends StatefulWidget {
  @override
  _PlanningReservationsScreenState createState() => _PlanningReservationsScreenState();
}

class _PlanningReservationsScreenState extends State<PlanningReservationsScreen>
    with SingleTickerProviderStateMixin {
  final ReservationService _reservationService = ReservationService();
  final TerrainService _terrainService = TerrainService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  List<Reservation> _allReservations = [];
  List<Terrain> _terrains = [];
  bool _isLoading = true;

  // Filtres
  String? _selectedTerrainId;
  StatutReservation? _selectedStatut;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      print('🎯 Chargement planning gérant: ${user.id}');

      setState(() {
        _isLoading = true;
      });

      // Charger les terrains et réservations en parallèle
      final results = await Future.wait([
        _terrainService.getTerrainsByGerant(user.id),
        _reservationService.getGerantReservations(user.id),
      ]);

      final terrains = results[0] as List<Terrain>;
      final reservations = results[1] as List<Reservation>;

      print('🎯 Terrains: ${terrains.length}, Réservations: ${reservations.length}');

      // Debug: vérifier si les noms d'utilisateurs sont bien chargés
      for (var reservation in reservations.take(3)) {
        print('🧪 Debug réservation ${reservation.id}: ${reservation.nomUtilisateur}');
      }

      if (mounted) {
        setState(() {
          _terrains = terrains;
          _allReservations = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement planning: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Reservation> get _filteredReservations {
    var reservations = _allReservations;

    // Filtre par terrain
    if (_selectedTerrainId != null) {
      reservations = reservations.where((r) => r.terrainId == _selectedTerrainId).toList();
    }

    // Filtre par statut
    if (_selectedStatut != null) {
      reservations = reservations.where((r) => r.statut == _selectedStatut).toList();
    }

    // Filtre par date
    if (_selectedDate != null) {
      reservations = reservations.where((r) =>
        r.date.year == _selectedDate!.year &&
        r.date.month == _selectedDate!.month &&
        r.date.day == _selectedDate!.day
      ).toList();
    }

    return reservations;
  }

  List<Reservation> _getReservationsByStatus(StatutReservation status) {
    return _filteredReservations.where((r) => r.statut == status).toList()
      ..sort((a, b) => b.dateReservation.compareTo(a.dateReservation));
  }

  List<Reservation> _getTodayReservations() {
    final today = DateTime.now();
    return _filteredReservations.where((r) =>
      r.date.year == today.year &&
      r.date.month == today.month &&
      r.date.day == today.day
    ).toList()
      ..sort((a, b) => a.heureDebut.compareTo(b.heureDebut));
  }

  List<Reservation> _getFutureReservations() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _filteredReservations.where((r) {
      final reservationDate = DateTime(r.date.year, r.date.month, r.date.day);
      return reservationDate.isAfter(today);
    }).toList()
      ..sort((a, b) {
        // Trier d'abord par date, puis par heure
        final dateComparison = a.date.compareTo(b.date);
        if (dateComparison != 0) return dateComparison;
        return a.heureDebut.compareTo(b.heureDebut);
      });
  }

  Map<String, dynamic> get _statistiques {
    final reservations = _filteredReservations;
    final today = DateTime.now();
    
    return {
      'total': reservations.length,
      'enAttente': reservations.where((r) => r.statut == StatutReservation.enAttente).length,
      'confirmees': reservations.where((r) => r.statut == StatutReservation.confirmee).length,
      'payees': reservations.where((r) => r.statut == StatutReservation.payee).length,
      'avances': reservations.where((r) => r.statut == StatutReservation.avance).length,
      'aujourdhui': reservations.where((r) =>
        r.date.year == today.year &&
        r.date.month == today.month &&
        r.date.day == today.day
      ).length,
      'futures': reservations.where((r) {
        final reservationDate = DateTime(r.date.year, r.date.month, r.date.day);
        final todayDate = DateTime(today.year, today.month, today.day);
        return reservationDate.isAfter(todayDate);
      }).length,
      'chiffreAffaires': _calculateChiffreAffaires(reservations),
    };
  }

  /// Calcule le chiffre d'affaires avec la même logique que le dashboard
  /// Filtre automatiquement les réservations du mois courant
  double _calculateChiffreAffaires(List<Reservation> reservations) {
    final now = DateTime.now();
    final debutMois = DateTime(now.year, now.month, 1);
    
    // Filtrer les réservations du mois courant seulement (comme le dashboard)
    final reservationsMois = reservations.where((r) => 
      r.date.isAfter(debutMois)
    ).toList();
    
    double chiffreAffaires = 0;
    
    for (var reservation in reservationsMois) {
      // Inclure toutes les réservations où de l'argent a été encaissé
      if (reservation.statut == StatutReservation.payee) {
        // Réservation entièrement payée
        chiffreAffaires += reservation.montant;
      } else if (reservation.statut == StatutReservation.avance) {
        // Réservation avec avance payée - utiliser le montant de l'avance
        chiffreAffaires += reservation.montantAvance;
      } else if (reservation.statut == StatutReservation.terminee) {
        // Réservation terminée (supposée payée)
        chiffreAffaires += reservation.montant;
      }
    }
    
    return chiffreAffaires;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Planning des Réservations'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showFilters,
            icon: Icon(Icons.filter_list),
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

          // Filtres actifs
          if (_hasActiveFilters()) _buildActiveFilters(),

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
                Tab(text: 'À venir'),
                Tab(text: 'En attente'),
                Tab(text: 'Confirmées'),
                Tab(text: 'Payées'),
                Tab(text: 'Avances'),
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
                _buildFutureTab(),
                _buildStatusTab(StatutReservation.enAttente),
                _buildStatusTab(StatutReservation.confirmee),
                _buildStatusTab(StatutReservation.payee),
                _buildStatusTab(StatutReservation.avance),
                _buildAllReservationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedTerrainId != null || _selectedStatut != null || _selectedDate != null;
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppConstants.mediumPadding, vertical: 8),
      color: AppConstants.primaryColor.withOpacity(0.1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Filtres actifs: ', style: TextStyle(fontWeight: FontWeight.w600)),
            if (_selectedTerrainId != null) ...[
              _buildFilterChip(
                'Terrain: ${_getTerrainName(_selectedTerrainId!)}',
                () => setState(() => _selectedTerrainId = null),
              ),
              SizedBox(width: 8),
            ],
            if (_selectedStatut != null) ...[
              _buildFilterChip(
                'Statut: ${_selectedStatut!.name}',
                () => setState(() => _selectedStatut = null),
              ),
              SizedBox(width: 8),
            ],
            if (_selectedDate != null) ...[
              _buildFilterChip(
                'Date: ${AppDateUtils.formatDate(_selectedDate!)}',
                () => setState(() => _selectedDate = null),
              ),
              SizedBox(width: 8),
            ],
            TextButton(
              onPressed: () => setState(() {
                _selectedTerrainId = null;
                _selectedStatut = null;
                _selectedDate = null;
              }),
              child: Text('Effacer tout'),
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      deleteIcon: Icon(Icons.close, size: 16),
      onDeleted: onDelete,
      backgroundColor: Colors.white,
      side: BorderSide(color: AppConstants.primaryColor),
    );
  }

  String _getTerrainName(String terrainId) {
    final terrain = _terrains.firstWhere(
      (t) => t.id == terrainId,
      orElse: () => Terrain(
        id: '',
        nom: 'Inconnu',
        gerantId: '',
        adresse: '',
        ville: '',
        description: '',
        latitude: 0.0,
        longitude: 0.0,
        prixHeure: 0,
        dateCreation: DateTime.now(),
      ),
    );
    return terrain.nom;
  }

  Widget _buildQuickStats() {
    final stats = _statistiques;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.today,
                title: 'Aujourd\'hui',
                value: '${stats['aujourdhui']}',
                color: AppConstants.primaryColor,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                icon: Icons.event,
                title: 'À venir',
                value: '${stats['futures']}',
                color: Colors.indigo,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                icon: Icons.schedule,
                title: 'En attente',
                value: '${stats['enAttente']}',
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                icon: Icons.check_circle,
                title: 'Confirmées',
                value: '${stats['confirmees']}',
                color: Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.account_balance_wallet,
                title: 'Avances',
                value: '${stats['avances']}',
                color: Colors.purple,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                icon: Icons.list,
                title: 'Total',
                value: '${stats['total']}',
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildStatItem(
                icon: Icons.monetization_on,
                title: 'CA du mois',
                value: '${(stats['chiffreAffaires'] as double).toInt()} FCFA',
                color: Colors.green.shade700,
              ),
            ),
          ],
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
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: TextStyle(
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
    final reservationsAujourdhui = _getTodayReservations();

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (reservationsAujourdhui.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'Aucune réservation aujourd\'hui',
        subtitle: 'Tous vos terrains sont libres',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: reservationsAujourdhui.length,
        itemBuilder: (context, index) {
          return _buildReservationCard(reservationsAujourdhui[index]);
        },
      ),
    );
  }

  Widget _buildFutureTab() {
    final reservationsFutures = _getFutureReservations();

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (reservationsFutures.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event,
        title: 'Aucune réservation à venir',
        subtitle: _hasActiveFilters() 
            ? 'Aucune réservation future ne correspond aux filtres'
            : 'Aucune réservation programmée pour les prochains jours',
      );
    }

    // Grouper par date
    Map<String, List<Reservation>> groupedReservations = {};
    for (var reservation in reservationsFutures) {
      final dateKey = AppDateUtils.formatDate(reservation.dateReservation);
      groupedReservations.putIfAbsent(dateKey, () => []);
      groupedReservations[dateKey]!.add(reservation);
    }

    final sortedDates = groupedReservations.keys.toList()
      ..sort((a, b) => a.compareTo(b)); // Plus proches en premier pour les futures

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final reservations = groupedReservations[date]!;
          
          // Trier les réservations par heure pour chaque jour
          reservations.sort((a, b) => a.heureDebut.compareTo(b.heureDebut));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête de date avec nombre de réservations
              Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.indigo, size: 18),
                    SizedBox(width: 8),
                    Text(
                      date,
                      style: AppConstants.subHeadingStyle.copyWith(
                        color: Colors.indigo,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${reservations.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildStatusTab(StatutReservation status) {
    final reservations = _getReservationsByStatus(status);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (reservations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        title: 'Aucune réservation ${status.name}',
        subtitle: '',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
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
    final reservations = _filteredReservations;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (reservations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        title: 'Aucune réservation',
        subtitle: _hasActiveFilters() 
            ? 'Aucune réservation ne correspond aux filtres'
            : 'Aucune réservation trouvée',
      );
    }

    // Grouper par date
    Map<String, List<Reservation>> groupedReservations = {};
    for (var reservation in reservations) {
      final dateKey = AppDateUtils.formatDate(reservation.dateReservation);
      groupedReservations.putIfAbsent(dateKey, () => []);
      groupedReservations[dateKey]!.add(reservation);
    }

    final sortedDates = groupedReservations.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final reservations = groupedReservations[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  date,
                  style: AppConstants.subHeadingStyle.copyWith(
                    color: AppConstants.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
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
            Icon(icon, size: 80, color: Colors.grey.shade400),
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
                      Text(
                        _getTerrainName(reservation.terrainId),
                        style: AppConstants.bodyStyle.copyWith(
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(reservation.statut),
              ],
            ),

            SizedBox(height: AppConstants.mediumPadding),

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
                if (reservation.telephoneUtilisateur != null)
                  Expanded(
                    child: _buildInfoRow(
                      icon: Icons.phone,
                      label: reservation.telephoneUtilisateur!,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StatutReservation statut) {
    Color color = Colors.grey;
    String text = 'Inconnu';
    IconData icon = Icons.help;

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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFiltersSheet(),
    );
  }

  Widget _buildFiltersSheet() {
    return Container(
      padding: EdgeInsets.all(AppConstants.largePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrer les réservations',
            style: AppConstants.subHeadingStyle,
          ),
          SizedBox(height: AppConstants.largePadding),

          // Filtre par terrain
          Text('Terrain', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTerrainId,
            hint: Text('Tous les terrains'),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Tous les terrains'),
              ),
              ..._terrains.map((terrain) => DropdownMenuItem<String>(
                value: terrain.id,
                child: Text(terrain.nom),
              )),
            ],
            onChanged: (value) => setState(() => _selectedTerrainId = value),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

          SizedBox(height: AppConstants.mediumPadding),

          // Filtre par statut
          Text('Statut', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          DropdownButtonFormField<StatutReservation>(
            value: _selectedStatut,
            hint: Text('Tous les statuts'),
            items: [
              DropdownMenuItem<StatutReservation>(
                value: null,
                child: Text('Tous les statuts'),
              ),
              ...StatutReservation.values.map((statut) => DropdownMenuItem<StatutReservation>(
                value: statut,
                child: Text(statut.name),
              )),
            ],
            onChanged: (value) => setState(() => _selectedStatut = value),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

          SizedBox(height: AppConstants.mediumPadding),

          // Filtre par date
          Text('Date', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(Duration(days: 365)),
                lastDate: DateTime.now().add(Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    _selectedDate != null 
                        ? AppDateUtils.formatDate(_selectedDate!)
                        : 'Toutes les dates',
                  ),
                  Spacer(),
                  if (_selectedDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = null),
                      child: Icon(Icons.clear, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: AppConstants.largePadding),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTerrainId = null;
                      _selectedStatut = null;
                      _selectedDate = null;
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Effacer'),
                ),
              ),
              SizedBox(width: AppConstants.mediumPadding),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Appliquer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}