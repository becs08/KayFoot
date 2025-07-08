import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_constants.dart';
import '../../services/Authentification/auth_service.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/terrain/terrain_image_service.dart';
import '../../services/reservation/reservation_service.dart';
import '../../models/terrain.dart';
import '../../models/terrain_extended.dart';
import '../../models/reservation.dart';
import 'add_terrain_screen.dart';
import 'edit_terrain_screen.dart';
import 'terrain_reservations_screen.dart';

class MesTerrainsScreen extends StatefulWidget {
  @override
  _MesTerrainsScreenState createState() => _MesTerrainsScreenState();
}

class _MesTerrainsScreenState extends State<MesTerrainsScreen> {
  final TerrainService _terrainService = TerrainService();
  final TerrainImageService _imageService = TerrainImageService();
  final ReservationService _reservationService = ReservationService();
  final AuthService _authService = AuthService();

  List<Terrain> _terrains = [];
  Map<String, int> _reservationCounts = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTerrains();
  }

  Future<void> _loadTerrains() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final terrains = await _terrainService.getTerrainsByGerant(user.id);

      // Charger le nombre de réservations pour chaque terrain
      Map<String, int> counts = {};
      for (var terrain in terrains) {
        final reservations = await _reservationService.getTerrainReservations(terrain.id);
        counts[terrain.id] = reservations.length;
      }

      if (mounted) {
        setState(() {
          _terrains = terrains;
          _reservationCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement terrains: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Terrain> get _filteredTerrains {
    if (_searchQuery.isEmpty) {
      return _terrains;
    }
    return _terrains.where((terrain) =>
      terrain.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      terrain.ville.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _toggleTerrainStatus(Terrain terrain) async {
    try {
      // Pour l'instant, on simule l'activation/désactivation
      // En réalité, il faudrait mettre à jour les disponibilités
      final newDisponibilites = terrain.disponible
          ? <String, List<String>>{} // Vider les disponibilités
          : {'lundi': ['09:00', '10:00', '11:00'], 'mardi': ['09:00', '10:00', '11:00']}; // Ajouter des créneaux

      await _terrainService.updateTerrain(
        terrain.copyWith(disponibilites: newDisponibilites),
      );

      // Recharger la liste
      await _loadTerrains();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            terrain.disponible
                ? 'Terrain désactivé'
                : 'Terrain activé'
          ),
          backgroundColor: terrain.disponible ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTerrain(Terrain terrain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le terrain'),
        content: Text('Êtes-vous sûr de vouloir supprimer \"${terrain.nom}\" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _terrainService.deleteTerrain(terrain.id);
        await _loadTerrains();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terrain supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _repairAllTerrains() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réparer les terrains'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cette action va réparer tous vos terrains :'),
            SizedBox(height: 8),
            Text('• Ajouter les champs manquants'),
            Text('• Convertir les horaires au format 09:00-10:00'),
            Text('• Ajouter les horaires par défaut si vides'),
            Text('• Corriger les données de validation'),
            SizedBox(height: 12),
            Text('Continuer ?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppConstants.primaryColor),
            child: Text('Réparer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        int repairedCount = 0;
        int totalCount = _terrains.length;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Réparation en cours...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        for (var terrain in _terrains) {
          final result = await _terrainService.repairTerrain(terrain.id);
          if (result.success) {
            repairedCount++;
            print('✅ Terrain "${terrain.nom}" réparé');
          } else {
            print('❌ Échec réparation terrain "${terrain.nom}"');
          }
        }

        await _loadTerrains();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('$repairedCount/$totalCount terrain(s) réparé(s) avec succès'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la réparation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Mes terrains'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _repairAllTerrains,
            icon: Icon(Icons.build),
            tooltip: 'Réparer les terrains',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AddTerrainScreen()),
              ).then((_) => _loadTerrains());
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            color: Colors.white,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un terrain...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  borderSide: BorderSide(color: AppConstants.primaryColor),
                ),
              ),
            ),
          ),

          // Statistiques rapides
          Container(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStat(
                        icon: Icons.business,
                        title: 'Total',
                        value: '${_terrains.length}',
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    SizedBox(width: AppConstants.mediumPadding),
                    Expanded(
                      child: _buildQuickStat(
                        icon: Icons.check_circle,
                        title: 'Actifs',
                        value: '${_terrains.where((t) => t.disponible).length}',
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(width: AppConstants.mediumPadding),
                    Expanded(
                      child: _buildQuickStat(
                        icon: Icons.pause_circle,
                        title: 'Inactifs',
                        value: '${_terrains.where((t) => !t.disponible).length}',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppConstants.mediumPadding),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStat(
                        icon: Icons.verified,
                        title: 'Validés',
                        value: '${_terrains.where((t) => t.estValide).length}',
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: AppConstants.mediumPadding),
                    Expanded(
                      child: _buildQuickStat(
                        icon: Icons.pending,
                        title: 'En attente',
                        value: '${_terrains.where((t) => !t.estValide).length}',
                        color: Colors.amber,
                      ),
                    ),
                    SizedBox(width: AppConstants.mediumPadding),
                    Expanded(
                      child: _buildQuickStat(
                        icon: Icons.event,
                        title: 'Réservations',
                        value: '${_reservationCounts.values.fold<int>(0, (sum, count) => sum + count)}',
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Liste des terrains
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredTerrains.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTerrains,
                        child: ListView.builder(
                          padding: EdgeInsets.all(AppConstants.mediumPadding),
                          itemCount: _filteredTerrains.length,
                          itemBuilder: (context, index) {
                            return _buildTerrainCard(_filteredTerrains[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddTerrainScreen()),
          ).then((_) => _loadTerrains());
        },
        backgroundColor: AppConstants.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildQuickStat({
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_business,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: AppConstants.largePadding),
            Text(
              _searchQuery.isEmpty
                  ? 'Aucun terrain ajouté'
                  : 'Aucun terrain trouvé',
              style: AppConstants.subHeadingStyle.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: AppConstants.smallPadding),
            Text(
              _searchQuery.isEmpty
                  ? 'Commencez par ajouter votre premier terrain'
                  : 'Essayez avec d\'autres mots-clés',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              SizedBox(height: AppConstants.largePadding),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AddTerrainScreen()),
                  ).then((_) => _loadTerrains());
                },
                icon: Icon(Icons.add),
                label: Text('Ajouter un terrain'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTerrainCard(Terrain terrain) {
    final reservationCount = _reservationCounts[terrain.id] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
      ),
      child: Column(
        children: [
          // Image et statut
          Stack(
            children: [
              _buildTerrainImage(terrain),
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: terrain.disponible ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        terrain.disponible ? 'Actif' : 'Inactif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: terrain.estValide ? Colors.blue : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            terrain.estValide ? Icons.check_circle : Icons.pending,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            terrain.estValide ? 'Validé' : 'En attente',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom et ville
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            terrain.nom,
                            style: AppConstants.subHeadingStyle.copyWith(
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                terrain.ville,
                                style: AppConstants.bodyStyle.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${terrain.prixHeure.toInt()} FCFA/h',
                      style: AppConstants.subHeadingStyle.copyWith(
                        color: AppConstants.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppConstants.mediumPadding),

                // Statistiques rapides
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.event_available,
                      label: '$reservationCount réservations',
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.schedule,
                      label: '${terrain.heureOuverture}h-${terrain.heureFermeture}h',
                      color: Colors.green,
                    ),
                  ],
                ),

                SizedBox(height: AppConstants.mediumPadding),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TerrainReservationsScreen(terrain: terrain),
                            ),
                          );
                        },
                        icon: Icon(Icons.event_note, size: 16),
                        label: Text('Réservations'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.primaryColor,
                          side: BorderSide(color: AppConstants.primaryColor),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EditTerrainScreen(terrain: terrain),
                            ),
                          ).then((_) => _loadTerrains());
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('Modifier'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'toggle':
                            _toggleTerrainStatus(terrain);
                            break;
                          case 'delete':
                            _deleteTerrain(terrain);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                terrain.disponible ? Icons.pause : Icons.play_arrow,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(terrain.disponible ? 'Désactiver' : 'Activer'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.more_vert, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainImage(Terrain terrain) {
    final thumbnailUrl = _imageService.getThumbnailUrl(terrain.photos);

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.mediumRadius),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.mediumRadius),
        ),
        child: thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 120,
                placeholder: (context, url) => Container(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultImage(),
              )
            : _buildDefaultImage(),
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      height: 120,
      color: AppConstants.primaryColor.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.sports_soccer,
          size: 40,
          color: AppConstants.primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
