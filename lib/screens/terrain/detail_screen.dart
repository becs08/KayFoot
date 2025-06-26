import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/terrain.dart';
import '../../models/avis.dart';
import '../../models/reservation.dart';
import '../../services/terrain_service.dart';
import '../../services/reservation_service.dart';
import '../../services/auth_service.dart';
import '../../services/avis_service.dart';
import '../booking/booking_screen.dart';
import '../avis/donner_avis_screen.dart';

class TerrainDetailScreen extends StatefulWidget {
  final Terrain terrain;

  const TerrainDetailScreen({Key? key, required this.terrain}) : super(key: key);

  @override
  _TerrainDetailScreenState createState() => _TerrainDetailScreenState();
}

class _TerrainDetailScreenState extends State<TerrainDetailScreen> {
  final PageController _pageController = PageController();
  final AvisService _avisService = AvisService();

  List<Avis> _avis = [];
  Map<String, dynamic> _statistiquesAvis = {};
  bool _isLoadingAvis = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAvis();
  }

  Future<void> _loadAvis() async {
    setState(() {
      _isLoadingAvis = true;
    });

    try {
      final avis = await _avisService.getAvisParTerrain(widget.terrain.id);
      final stats = await _avisService.getStatistiquesAvis(widget.terrain.id);

      setState(() {
        _avis = avis;
        _statistiquesAvis = stats;
        _isLoadingAvis = false;
      });
    } catch (e) {
      print('Erreur chargement avis: $e');
      setState(() {
        _isLoadingAvis = false;
      });
    }
  }

  void _navigateToBooking() {
    if (!AuthService().isAuthenticated) {
      _showLoginDialog();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookingScreen(terrain: widget.terrain),
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connexion requise'),
        content: Text('Vous devez vous connecter pour réserver un terrain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login screen
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar avec images
          _buildSliverAppBar(),

          // Contenu principal
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations principales
                _buildMainInfo(),

                Divider(),

                // Équipements
                _buildEquipements(),

                Divider(),

                // Disponibilités
                _buildDisponibilites(),

                Divider(),

                // Avis et commentaires
                _buildAvis(),

                // Espacement pour le bouton flottant
                SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),

      // Bouton de réservation
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToBooking,
        icon: Icon(Icons.event_available),
        label: Text('Réserver'),
        backgroundColor: AppConstants.primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: widget.terrain.photos.isNotEmpty
            ? PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemCount: widget.terrain.photos.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(widget.terrain.photos[index]),
                        fit: BoxFit.cover,
                        onError: (error, stackTrace) {},
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: AppConstants.primaryColor.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.share),
          onPressed: () {
            // TODO: Implémenter le partage
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fonctionnalité de partage à venir')),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.favorite_border),
          onPressed: () {
            // TODO: Ajouter aux favoris
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ajouté aux favoris')),
            );
          },
        ),
      ],
      bottom: widget.terrain.photos.length > 1
          ? PreferredSize(
              preferredSize: Size.fromHeight(20),
              child: Container(
                height: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.terrain.photos.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      width: _currentImageIndex == index ? 8 : 6,
                      height: _currentImageIndex == index ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildMainInfo() {
    return Padding(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom et prix
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.terrain.nom,
                      style: AppConstants.headingStyle.copyWith(fontSize: 22),
                    ),

                    SizedBox(height: AppConstants.smallPadding),

                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${widget.terrain.adresse}, ${widget.terrain.ville}',
                            style: AppConstants.bodyStyle.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.mediumPadding,
                  vertical: AppConstants.smallPadding,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                ),
                child: Text(
                  '${widget.terrain.prixHeure.toInt()} FCFA/h',
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppConstants.mediumPadding),

          // Note et avis dynamiques
          if (_isLoadingAvis)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Chargement des avis...',
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Row(
                  children: List.generate(5, (index) {
                    final noteMoyenne = _statistiquesAvis['noteMoyenne'] ?? 0.0;
                    return Icon(
                      index < noteMoyenne.floor()
                          ? Icons.star
                          : index < noteMoyenne
                              ? Icons.star_half
                              : Icons.star_border,
                      color: noteMoyenne > 0 ? AppConstants.accentColor : Colors.grey.shade400,
                      size: 20,
                    );
                  }),
                ),

                SizedBox(width: AppConstants.smallPadding),

                Text(
                  _statistiquesAvis['nombreAvis'] != null && _statistiquesAvis['nombreAvis'] > 0
                      ? '${(_statistiquesAvis['noteMoyenne'] ?? 0.0).toStringAsFixed(1)} (${_statistiquesAvis['nombreAvis']} avis)'
                      : 'Aucun avis',
                  style: AppConstants.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

          SizedBox(height: AppConstants.mediumPadding),

          // Description
          Text(
            'Description',
            style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
          ),

          SizedBox(height: AppConstants.smallPadding),

          Text(
            widget.terrain.description,
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipements() {
    if (widget.terrain.equipements.isEmpty) return SizedBox();

    return Padding(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Équipements',
            style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
          ),

          SizedBox(height: AppConstants.mediumPadding),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.terrain.equipements.map((equipement) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.mediumPadding,
                  vertical: AppConstants.smallPadding,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  border: Border.all(
                    color: AppConstants.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getEquipementIcon(equipement),
                      size: 16,
                      color: AppConstants.primaryColor,
                    ),
                    SizedBox(width: AppConstants.smallPadding),
                    Text(
                      equipement,
                      style: AppConstants.bodyStyle.copyWith(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisponibilites() {
    if (widget.terrain.disponibilites.isEmpty) return SizedBox();

    return Padding(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilités',
            style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
          ),

          SizedBox(height: AppConstants.mediumPadding),

          Column(
            children: widget.terrain.disponibilites.entries.map((entry) {
              final jour = entry.key;
              final creneaux = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
                padding: const EdgeInsets.all(AppConstants.mediumPadding),
                decoration: BoxDecoration(
                  // ToDO changer la couleur !!
                  //color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        jour.substring(0, 1).toUpperCase() + jour.substring(1),
                        style: AppConstants.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: creneaux.map((creneau) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppConstants.successColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              creneau,
                              style: AppConstants.bodyStyle.copyWith(
                                fontSize: 11,
                                color: AppConstants.successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvis() {
    if (_isLoadingAvis) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final nombreAvis = _statistiquesAvis['nombreAvis'] ?? 0;
    final noteMoyenne = _statistiquesAvis['noteMoyenne'] ?? 0.0;

    return Padding(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec bouton pour donner un avis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Avis et notes',
                style: AppConstants.subHeadingStyle.copyWith(fontSize: 18),
              ),
              ElevatedButton.icon(
                onPressed: _ouvrirDonnerAvis,
                icon: const Icon(Icons.rate_review, size: 16),
                label: const Text('Donner un avis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Résumé des notes
          if (nombreAvis > 0) ...[
            _buildResumeNotes(nombreAvis, noteMoyenne),
            const SizedBox(height: 20),
          ],

          // Liste des avis
          if (_avis.isEmpty)
            _buildAucunAvis()
          else ...[
            _buildListeAvis(),
            if (_avis.length > 3) _buildVoirTousAvis(),
          ],
        ],
      ),
    );
  }

  /// Ouvrir l'écran pour donner un avis
  Future<void> _ouvrirDonnerAvis() async {
    if (!AuthService().isAuthenticated) {
      _showLoginDialog();
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DonnerAvisScreen(terrain: widget.terrain),
      ),
    );

    // Recharger les avis si un avis a été ajouté/modifié
    if (result == true) {
      _loadAvis();
    }
  }

  /// Widget résumé des notes (type PlayStore)
  Widget _buildResumeNotes(int nombreAvis, double noteMoyenne) {
    final repartition = _statistiquesAvis['repartition'] ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Note moyenne et étoiles
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  noteMoyenne.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < noteMoyenne.floor() ? Icons.star : Icons.star_border,
                      color: AppConstants.primaryColor,
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$nombreAvis avis',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Répartition des notes
          Expanded(
            flex: 3,
            child: Column(
              children: [5, 4, 3, 2, 1].map((note) {
                final count = repartition[note] ?? 0;
                final percentage = nombreAvis > 0 ? (count / nombreAvis) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$note', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 12, color: AppConstants.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget aucun avis
  Widget _buildAucunAvis() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun avis pour le moment',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Soyez le premier à laisser un avis !',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget liste des avis
  Widget _buildListeAvis() {
    return Column(
      children: _avis.take(3).map((avis) => _buildAvisCard(avis)).toList(),
    );
  }

  /// Widget voir tous les avis
  Widget _buildVoirTousAvis() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextButton(
        onPressed: () {
          _voirTousLesAvis();
        },
        child: Text('Voir tous les ${_avis.length} avis'),
      ),
    );
  }

  /// Voir tous les avis (peut ouvrir une nouvelle page ou un bottom sheet)
  void _voirTousLesAvis() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Tous les avis (${_avis.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _avis.length,
                    itemBuilder: (context, index) {
                      return _buildAvisCard(_avis[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvisCard(Avis avis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                child: Text(
                  avis.utilisateurNom.isNotEmpty
                      ? avis.utilisateurNom[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avis.utilisateurNom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < avis.note ? Icons.star : Icons.star_border,
                              color: AppConstants.primaryColor,
                              size: 16,
                            );
                          }),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          _formatDateAvis(avis.dateCreation),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (avis.commentaire.isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              avis.commentaire,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Formater la date pour les avis
  String _formatDateAvis(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Aujourd'hui";
    } else if (difference.inDays == 1) {
      return "Hier";
    } else if (difference.inDays < 7) {
      return "Il y a ${difference.inDays} jours";
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return "Il y a $weeks semaine${weeks > 1 ? 's' : ''}";
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return "Il y a $months mois";
    } else {
      final years = (difference.inDays / 365).floor();
      return "Il y a $years an${years > 1 ? 's' : ''}";
    }
  }

  IconData _getEquipementIcon(String equipement) {
    switch (equipement.toLowerCase()) {
      case 'éclairage':
        return Icons.lightbulb;
      case 'vestiaires':
        return Icons.room_service;
      case 'douches':
        return Icons.shower;
      case 'parking':
        return Icons.local_parking;
      case 'sécurité':
        return Icons.security;
      case 'buvette':
        return Icons.local_cafe;
      case 'toilettes':
        return Icons.wc;
      case 'gradins':
        return Icons.event_seat;
      case 'terrain synthétique':
        return Icons.grass;
      case 'terrain naturel':
        return Icons.nature;
      default:
        return Icons.check_circle;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Il y a quelques minutes';
    }
  }
}
