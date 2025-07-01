import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_constants.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/terrain/terrain_image_service.dart';
import '../../services/profil/statistics_service.dart';
import '../../services/location/location_service.dart';
import '../../models/terrain.dart';
import 'detail_screen.dart';

class TerrainListScreen extends StatefulWidget {
  const TerrainListScreen({super.key});

  @override
  _TerrainListScreenState createState() => _TerrainListScreenState();
}

class _TerrainListScreenState extends State<TerrainListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TerrainService _terrainService = TerrainService();
  final TerrainImageService _imageService = TerrainImageService();
  final StatisticsService _statsService = StatisticsService();
  final LocationService _locationService = LocationService();

  List<Terrain> _allTerrains = [];
  List<Terrain> _filteredTerrains = [];
  String _selectedVille = 'Toutes';
  bool _isLoading = true;
  String _sortBy = 'nom'; // nom, prix, note

  @override
  void initState() {
    super.initState();
    _loadTerrains();
    _searchController.addListener(_onSearchChanged);
    _tryGetUserLocation();
  }

  Future<void> _tryGetUserLocation() async {
    try {
      await _locationService.getCurrentPosition();
    } catch (e) {
      // Ignorer l'erreur silencieusement
      // L'utilisateur peut choisir de ne pas partager sa position
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTerrains() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final terrains = await _terrainService.getAllTerrains();
      setState(() {
        _allTerrains = terrains;
        _filteredTerrains = terrains;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Erreur lors du chargement des terrains');
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredTerrains = _allTerrains.where((terrain) {
        // Filtre par recherche textuelle
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            terrain.nom.toLowerCase().contains(searchQuery) ||
            terrain.description.toLowerCase().contains(searchQuery) ||
            terrain.ville.toLowerCase().contains(searchQuery);

        // Filtre par ville
        final matchesVille = _selectedVille == 'Toutes' ||
            terrain.ville == _selectedVille;

        return matchesSearch && matchesVille;
      }).toList();

      // Tri
      _filteredTerrains.sort((a, b) {
        switch (_sortBy) {
          case 'prix':
            return a.prixHeure.compareTo(b.prixHeure);
          case 'note':
            return b.notemoyenne.compareTo(a.notemoyenne);
          case 'distance':
            return _sortByDistance(a, b);
          case 'nom':
          default:
            return a.nom.compareTo(b.nom);
        }
      });
    });
  }

  int _sortByDistance(Terrain a, Terrain b) {
    final currentPosition = _locationService.currentPosition;
    if (currentPosition == null) {
      // Si pas de position, trier par nom
      return a.nom.compareTo(b.nom);
    }

    final distanceA = _locationService.calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      a.latitude,
      a.longitude,
    );
    
    final distanceB = _locationService.calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      b.latitude,
      b.longitude,
    );

    return distanceA.compareTo(distanceB);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.mediumRadius),
        ),
      ),
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terrains disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),

          // Statistiques
          _buildStatsBar(),

          // Liste des terrains
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTerrains.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTerrains,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppConstants.mediumPadding),
                          itemCount: _filteredTerrains.length,
                          itemBuilder: (context, index) {
                            return _buildTerrainCard(_filteredTerrains[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.mediumPadding),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un terrain...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.mediumPadding,
                  vertical: AppConstants.smallPadding,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.mediumPadding,
        vertical: AppConstants.smallPadding,
      ),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_filteredTerrains.length} terrain(s) trouvé(s)',
                style: AppConstants.bodyStyle.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              if (_sortBy == 'distance' && _locationService.currentPosition != null)
                Text(
                  'Triés par distance',
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 10,
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_sortBy == 'distance' && _locationService.currentPosition == null)
                Text(
                  'Position non disponible',
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),

          DropdownButton<String>(
            value: _sortBy,
            icon: Icon(Icons.sort, size: 16),
            underline: SizedBox(),
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
            items: const [
              DropdownMenuItem(value: 'nom', child: Text('Nom A-Z')),
              DropdownMenuItem(value: 'prix', child: Text('Prix croissant')),
              DropdownMenuItem(value: 'note', child: Text('Mieux notés')),
              DropdownMenuItem(value: 'distance', child: Text('Plus proches')),
            ],
            onChanged: (value) {
              setState(() {
                _sortBy = value!;
              });
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),

          SizedBox(height: AppConstants.mediumPadding),

          Text(
            'Aucun terrain trouvé',
            style: AppConstants.subHeadingStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),

          SizedBox(height: AppConstants.smallPadding),

          Text(
            'Essayez de modifier vos critères de recherche',
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: AppConstants.mediumPadding),

          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedVille = 'Toutes';
              });
              _applyFilters();
            },
            child: Text('Réinitialiser les filtres'),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainCard(Terrain terrain) {
    return Card(
      margin: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TerrainDetailScreen(terrain: terrain),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image du terrain
                  _buildTerrainImage(terrain),

                  SizedBox(width: AppConstants.mediumPadding),

                  // Informations du terrain
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          terrain.nom,
                          style: AppConstants.subHeadingStyle.copyWith(
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: AppConstants.smallPadding),

                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${terrain.adresse}, ${terrain.ville}',
                                style: AppConstants.bodyStyle.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: AppConstants.smallPadding),

                        Row(
                          children: [
                            // Note dynamique
                            FutureBuilder<Map<String, dynamic>>(
                              future: _statsService.calculateTerrainStats(terrain.id),
                              builder: (context, snapshot) {
                                final noteMoyenne = snapshot.hasData && snapshot.data!['noteMoyenne'] != null && snapshot.data!['noteMoyenne'] > 0
                                    ? snapshot.data!['noteMoyenne'] as double
                                    : 0.0;
                                final nombreAvis = snapshot.hasData && snapshot.data!['nombreAvis'] != null
                                    ? snapshot.data!['nombreAvis'] as int
                                    : 0;

                                return Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: noteMoyenne > 0 ? AppConstants.accentColor : Colors.grey.shade400,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      noteMoyenne > 0 ? noteMoyenne.toStringAsFixed(1) : 'N/A',
                                      style: AppConstants.bodyStyle.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      ' ($nombreAvis)',
                                      style: AppConstants.bodyStyle.copyWith(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            Spacer(),

                            // Distance (si tri par distance)
                            if (_sortBy == 'distance' && _locationService.currentPosition != null) ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.near_me,
                                      size: 10,
                                      color: AppConstants.primaryColor,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      _locationService.formatDistance(
                                        _locationService.calculateDistance(
                                          _locationService.currentPosition!.latitude,
                                          _locationService.currentPosition!.longitude,
                                          terrain.latitude,
                                          terrain.longitude,
                                        ),
                                      ),
                                      style: AppConstants.bodyStyle.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Prix
                            Text(
                              '${terrain.prixHeure.toInt()} FCFA/h',
                              style: AppConstants.bodyStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (terrain.equipements.isNotEmpty) ...[
                SizedBox(height: AppConstants.mediumPadding),

                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: terrain.equipements.take(3).map((equipement) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        equipement,
                        style: AppConstants.bodyStyle.copyWith(
                          fontSize: 10,
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              SizedBox(height: AppConstants.smallPadding),

              Text(
                terrain.description,
                style: AppConstants.bodyStyle.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBottomSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtres',
                style: AppConstants.subHeadingStyle.copyWith(fontSize: 18),
              ),

              SizedBox(height: AppConstants.largePadding),

              // Filtre par ville
              Text(
                'Ville',
                style: AppConstants.bodyStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: AppConstants.smallPadding),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Toutes', ...AppConstants.villes].map((ville) {
                  final isSelected = _selectedVille == ville;
                  return FilterChip(
                    label: Text(
                      ville,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setSheetState(() {
                        _selectedVille = ville;
                      });
                    },
                    selectedColor: AppConstants.primaryColor,
                    backgroundColor: Colors.grey.shade200,
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),

              SizedBox(height: AppConstants.largePadding),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedVille = 'Toutes';
                        });
                      },
                      child: Text('Réinitialiser'),
                    ),
                  ),

                  SizedBox(width: AppConstants.mediumPadding),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Les filtres sont déjà appliqués via setSheetState
                        });
                        _applyFilters();
                        Navigator.of(context).pop();
                      },
                      child: Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🖼️ Widget pour afficher l'image du terrain
  Widget _buildTerrainImage(Terrain terrain) {
    final thumbnailUrl = _imageService.getThumbnailUrl(terrain.photos);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        child: thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultTerrainImage(),
              )
            : _buildDefaultTerrainImage(),
      ),
    );
  }

  /// 🏟️ Widget par défaut quand il n'y a pas d'image
  Widget _buildDefaultTerrainImage() {
    return Container(
      color: AppConstants.primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.sports_soccer,
        color: AppConstants.primaryColor,
        size: 32,
      ),
    );
  }
}
