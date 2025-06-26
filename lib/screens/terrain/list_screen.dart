import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/terrain_service.dart';
import '../../services/statistics_service.dart';
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
  final StatisticsService _statsService = StatisticsService();

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
          case 'nom':
          default:
            return a.nom.compareTo(b.nom);
        }
      });
    });
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
          Text(
            '${_filteredTerrains.length} terrain(s) trouvé(s)',
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade700,
            ),
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
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                    ),
                    child: Icon(
                      Icons.sports_soccer,
                      color: AppConstants.primaryColor,
                      size: 32,
                    ),
                  ),

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
}
