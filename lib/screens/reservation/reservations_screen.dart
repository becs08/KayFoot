import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/reservation.dart';
import '../../services/reservation/reservation_service.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/Authentification/auth_service.dart';
import '../../models/terrain.dart';
import '../terrain/list_screen.dart';
import 'reservation_detail_screen.dart';

class ReservationsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTerrains;

  const ReservationsScreen({Key? key, this.onNavigateToTerrains}) : super(key: key);

  @override
  _ReservationsScreenState createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Reservation> _allReservations = [];
  List<Reservation> _activeReservations = [];
  List<Reservation> _pastReservations = [];
  List<Reservation> _cancelledReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final reservations = await ReservationService().getUserReservations(user.id);
        final now = DateTime.now();

        setState(() {
          _allReservations = reservations;

          _activeReservations = reservations.where((reservation) {
            final reservationDateTime = DateTime(
              reservation.date.year,
              reservation.date.month,
              reservation.date.day,
              int.parse(reservation.heureDebut.split(':')[0]),
              int.parse(reservation.heureDebut.split(':')[1]),
            );

            return reservationDateTime.isAfter(now) &&
                   reservation.statut != StatutReservation.annulee;
          }).toList();

          _pastReservations = reservations.where((reservation) {
            final reservationDateTime = DateTime(
              reservation.date.year,
              reservation.date.month,
              reservation.date.day,
              int.parse(reservation.heureDebut.split(':')[0]),
              int.parse(reservation.heureDebut.split(':')[1]),
            );

            return reservationDateTime.isBefore(now) &&
                   reservation.statut != StatutReservation.annulee &&
                   reservation.statut != StatutReservation.terminee;
          }).toList();

          _cancelledReservations = reservations.where((reservation) {
            return reservation.statut == StatutReservation.annulee;
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Erreur lors du chargement des réservations');
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

  void _navigateToTerrains() {
    if (widget.onNavigateToTerrains != null) {
      // Utiliser le callback du parent pour changer d'onglet
      widget.onNavigateToTerrains!();
    } else {
      // Fallback : naviguer directement vers la liste des terrains
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TerrainListScreen(),
        ),
      );
    }
  }

  /// Vérifie si une réservation est passée
  bool _isPastReservation(Reservation reservation) {
    final now = DateTime.now();
    final reservationDateTime = DateTime(
      reservation.date.year,
      reservation.date.month,
      reservation.date.day,
      int.parse(reservation.heureDebut.split(':')[0]),
      int.parse(reservation.heureDebut.split(':')[1]),
    );

    return reservationDateTime.isBefore(now) ||
           reservation.statut == StatutReservation.annulee ||
           reservation.statut == StatutReservation.terminee;
  }

  /// Supprimer une réservation de l'historique
  Future<void> _deleteReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer de l\'historique'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Êtes-vous sûr de vouloir supprimer cette réservation de votre historique ?'),
            SizedBox(height: AppConstants.smallPadding),
            Text(
              'Cette action est irréversible.',
              style: TextStyle(
                color: AppConstants.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await ReservationService().deleteReservation(reservation.id);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Réservation supprimée de l\'historique'),
              backgroundColor: AppConstants.successColor,
            ),
          );
          _loadReservations(); // Recharger les réservations
        } else {
          _showError(result.message);
        }
      } catch (e) {
        _showError('Erreur lors de la suppression');
      }
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler la réservation'),
        content: Text('Êtes-vous sûr de vouloir annuler cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Oui, annuler'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await ReservationService().cancelReservation(reservation.id);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppConstants.successColor,
            ),
          );
          _loadReservations(); // Recharger les réservations
        } else {
          _showError(result.message);
        }
      } catch (e) {
        _showError('Erreur lors de l\'annulation');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes réservations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Actives (${_activeReservations.length})',
              icon: Icon(Icons.schedule),
            ),
            Tab(
              text: 'Historique (${_pastReservations.length})',
              icon: Icon(Icons.history),
            ),
            Tab(
              text: 'Annulées (${_cancelledReservations.length})',
              icon: Icon(Icons.cancel),
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReservationsList(_activeReservations),
                _buildReservationsList(_pastReservations, showPast: true),
                _buildReservationsList(_cancelledReservations, showCancelled: true),
              ],
            ),
    );
  }

  Widget _buildReservationsList(
    List<Reservation> reservations, {
    bool showPast = false,
    bool showCancelled = false,
  }) {
    if (reservations.isEmpty) {
      return _buildEmptyState(showPast: showPast, showCancelled: showCancelled);
    }

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          return _buildReservationCard(
            reservations[index],
            showPast: showPast,
            showCancelled: showCancelled,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({bool showPast = false, bool showCancelled = false}) {
    String title;
    String subtitle;
    IconData icon;

    if (showCancelled) {
      title = 'Aucune réservation annulée';
      subtitle = 'Aucune réservation annulée trouvée';
      icon = Icons.cancel;
    } else if (showPast) {
      title = 'Aucun historique';
      subtitle = 'Aucune réservation passée trouvée';
      icon = Icons.history;
    } else {
      title = 'Aucune réservation active';
      subtitle = 'Vous n\'avez pas de réservations à venir';
      icon = Icons.schedule;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: AppConstants.mediumPadding),

          Text(
            title,
            style: AppConstants.subHeadingStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: AppConstants.smallPadding),

          Text(
            subtitle,
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),

          if (!showPast) ...[
            const SizedBox(height: AppConstants.largePadding),

            ElevatedButton(
              onPressed: _navigateToTerrains,
              child: const Text('Réserver un terrain'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation, {bool showPast = false, bool showCancelled = false}) {
    // Déterminer si la réservation est expirée
    final now = DateTime.now();
    final reservationDateTime = DateTime(
      reservation.date.year,
      reservation.date.month,
      reservation.date.day,
      int.parse(reservation.heureDebut.split(':')[0]),
      int.parse(reservation.heureDebut.split(':')[1]),
    );
    final isExpired = reservationDateTime.isBefore(now);

    return Card(
      margin: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      // Assombrir légèrement les cartes des réservations passées
      color: showPast ? Colors.grey.shade50 : Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReservationDetailScreen(reservation: reservation),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        child: Container(
          // Ajouter une bordure pour différencier visuellement
          decoration: showPast ? BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ) : null,
          child: Padding(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<Terrain?>(
                        future: TerrainService().getTerrainById(reservation.terrainId),
                        builder: (context, snapshot) {
                          final terrain = snapshot.data;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                terrain?.nom ?? 'Terrain inconnu',
                                style: AppConstants.subHeadingStyle.copyWith(
                                  fontSize: 16,
                                  // Texte plus clair pour les réservations passées
                                  color: showPast ? Colors.grey.shade600 : null,
                                ),
                              ),

                              SizedBox(height: 4),

                              if (terrain != null)
                                Text(
                                  terrain.ville,
                                  style: AppConstants.bodyStyle.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    _buildStatusChip(reservation.statut),
                  ],
                ),

              SizedBox(height: AppConstants.mediumPadding),

              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _formatDate(reservation.date),
                    style: AppConstants.bodyStyle.copyWith(fontSize: 13),
                  ),

                  SizedBox(width: AppConstants.mediumPadding),

                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${reservation.heureDebut} - ${reservation.heureFin}',
                    style: AppConstants.bodyStyle.copyWith(fontSize: 13),
                  ),
                ],
              ),

              SizedBox(height: AppConstants.smallPadding),

              // Informations de paiement selon le type
              if (reservation.isPaiementAvance) ...[
                Row(
                  children: [
                    Icon(
                      Icons.payment,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Payé: ${reservation.montantAvance.toInt()} FCFA',
                      style: AppConstants.bodyStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reste: ${reservation.montantRestant.toInt()} FCFA',
                      style: AppConstants.bodyStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppConstants.smallPadding),

                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getPaymentMethodName(reservation.modePaiement),
                      style: AppConstants.bodyStyle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      Icons.payment,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${reservation.montant.toInt()} FCFA',
                      style: AppConstants.bodyStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(width: AppConstants.mediumPadding),

                    Icon(
                      Icons.account_balance_wallet,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getPaymentMethodName(reservation.modePaiement),
                      style: AppConstants.bodyStyle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ],

              if (!showPast && (reservation.statut == StatutReservation.payee || reservation.statut == StatutReservation.avance)) ...[
                const SizedBox(height: AppConstants.mediumPadding),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ReservationDetailScreen(
                            reservation: reservation,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 16),
                    label: const Text('Voir les détails'),
                  ),
                ),
              ],

              // Bouton voir détails pour les réservations passées et annulées
              if ((showPast && _isPastReservation(reservation)) || showCancelled) ...[
                const SizedBox(height: AppConstants.mediumPadding),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ReservationDetailScreen(
                            reservation: reservation,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Voir détails'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStatusChip(StatutReservation statut) {
    Color color;
    String label;
    IconData icon;

    switch (statut) {
      case StatutReservation.enAttente:
        color = AppConstants.warningColor;
        label = 'En attente';
        icon = Icons.schedule;
        break;
      case StatutReservation.confirmee:
        color = Colors.blue;
        label = 'Confirmée';
        icon = Icons.check_circle_outline;
        break;
      case StatutReservation.avance:
        color = Colors.orange;
        label = 'Avance payée';
        icon = Icons.payment;
        break;
      case StatutReservation.payee:
        color = AppConstants.successColor;
        label = 'Payée';
        icon = Icons.check_circle;
        break;
      case StatutReservation.annulee:
        color = AppConstants.errorColor;
        label = 'Annulée';
        icon = Icons.cancel;
        break;
      case StatutReservation.terminee:
        color = Colors.grey;
        label = 'Terminée';
        icon = Icons.done_all;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: AppConstants.bodyStyle.copyWith(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
/*    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Aujourd\'hui';
    } else if (difference == 1) {
      return 'Demain';
    } else if (difference == -1) {
      return 'Hier';
    } else {*/
      const months = [
        'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
        'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
      ];

      return '${date.day} ${months[date.month - 1]} ${date.year}';

  }

  String _getPaymentMethodName(ModePaiement method) {
    switch (method) {
      case ModePaiement.orange:
        return 'Orange Money';
      case ModePaiement.wave:
        return 'Wave';
    }
  }
}
