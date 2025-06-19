import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/terrain.dart';
import '../../models/avis.dart';
import '../../models/reservation.dart';
import '../../services/terrain_service.dart';
import '../../services/reservation_service.dart';
import '../../services/auth_service.dart';
import '../booking/booking_screen.dart';

class TerrainDetailScreen extends StatefulWidget {
  final Terrain terrain;

  const TerrainDetailScreen({Key? key, required this.terrain}) : super(key: key);

  @override
  _TerrainDetailScreenState createState() => _TerrainDetailScreenState();
}

class _TerrainDetailScreenState extends State<TerrainDetailScreen> {
  final PageController _pageController = PageController();
  List<Avis> _avis = [];
  bool _isLoadingAvis = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAvis();
  }

  Future<void> _loadAvis() async {
    try {
      final avis = await TerrainService().getAvisTerrain(widget.terrain.id);
      setState(() {
        _avis = avis;
        _isLoadingAvis = false;
      });
    } catch (e) {
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
          
          // Note et avis
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < widget.terrain.notemoyenne.floor()
                        ? Icons.star
                        : index < widget.terrain.notemoyenne
                            ? Icons.star_half
                            : Icons.star_border,
                    color: AppConstants.accentColor,
                    size: 20,
                  );
                }),
              ),
              
              SizedBox(width: AppConstants.smallPadding),
              
              Text(
                '${widget.terrain.notemoyenne.toStringAsFixed(1)} (${widget.terrain.nombreAvis} avis)',
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
                margin: EdgeInsets.only(bottom: AppConstants.smallPadding),
                padding: EdgeInsets.all(AppConstants.mediumPadding),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
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
    return Padding(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Avis (${widget.terrain.nombreAvis})',
                style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
              ),
              
              if (_avis.length > 3)
                TextButton(
                  onPressed: () {
                    // TODO: Voir tous les avis
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Voir tous les avis à venir')),
                    );
                  },
                  child: Text('Voir tout'),
                ),
            ],
          ),
          
          SizedBox(height: AppConstants.mediumPadding),
          
          _isLoadingAvis
              ? Center(child: CircularProgressIndicator())
              : _avis.isEmpty
                  ? Text(
                      'Aucun avis pour le moment',
                      style: AppConstants.bodyStyle.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    )
                  : Column(
                      children: _avis.take(3).map((avis) {
                        return _buildAvisCard(avis);
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildAvisCard(Avis avis) {
    return Container(
      margin: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.person,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              
              SizedBox(width: AppConstants.smallPadding),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Utilisateur', // TODO: Récupérer le nom de l'utilisateur
                      style: AppConstants.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < avis.note ? Icons.star : Icons.star_border,
                              color: AppConstants.accentColor,
                              size: 14,
                            );
                          }),
                        ),
                        
                        SizedBox(width: AppConstants.smallPadding),
                        
                        Text(
                          _formatDate(avis.dateCreation),
                          style: AppConstants.bodyStyle.copyWith(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (avis.commentaire != null && avis.commentaire!.isNotEmpty) ...[
            SizedBox(height: AppConstants.smallPadding),
            
            Text(
              avis.commentaire!,
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
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