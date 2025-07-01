import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_constants.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/terrain/terrain_image_service.dart';
import '../../services/location/location_service.dart';
import '../../models/terrain.dart';
import 'detail_screen.dart';

class TerrainsProchesScreen extends StatefulWidget {
  @override
  _TerrainsProchesScreenState createState() => _TerrainsProchesScreenState();
}

class _TerrainsProchesScreenState extends State<TerrainsProchesScreen> {
  final TerrainService _terrainService = TerrainService();
  final TerrainImageService _imageService = TerrainImageService();
  final LocationService _locationService = LocationService();

  List<TerrainWithDistance> _terrainsProches = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadTerrainsProches();
  }

  Future<void> _loadTerrainsProches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final terrainsProches = await _terrainService.getTerrainsProches();
      
      setState(() {
        _terrainsProches = terrainsProches;
        _locationPermissionGranted = _locationService.isLocationPermissionGranted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      await _locationService.getCurrentPosition();
      await _loadTerrainsProches();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'obtenir votre position'),
          action: SnackBarAction(
            label: 'Paramètres',
            onPressed: () => _locationService.openLocationSettings(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terrains proches'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTerrainsProches,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recherche des terrains proches...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_locationPermissionGranted) {
      return _buildLocationPermissionWidget();
    }

    if (_terrainsProches.isEmpty) {
      return _buildEmptyWidget();
    }

    return _buildTerrainsList();
  }

  Widget _buildLocationPermissionWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: AppConstants.largePadding),
            Text(
              'Localisation requise',
              style: AppConstants.subHeadingStyle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.mediumPadding),
            Text(
              'Pour vous montrer les terrains les plus proches, nous avons besoin d\'accéder à votre position.',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.largePadding),
            ElevatedButton.icon(
              onPressed: _requestLocationPermission,
              icon: Icon(Icons.location_on),
              label: Text('Activer la localisation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.largePadding,
                  vertical: AppConstants.mediumPadding,
                ),
              ),
            ),
            SizedBox(height: AppConstants.mediumPadding),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Voir tous les terrains'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            SizedBox(height: AppConstants.largePadding),
            Text(
              'Erreur',
              style: AppConstants.subHeadingStyle,
            ),
            SizedBox(height: AppConstants.mediumPadding),
            Text(
              _errorMessage!,
              style: AppConstants.bodyStyle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.largePadding),
            ElevatedButton(
              onPressed: _loadTerrainsProches,
              child: Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: AppConstants.largePadding),
            Text(
              'Aucun terrain trouvé',
              style: AppConstants.subHeadingStyle,
            ),
            SizedBox(height: AppConstants.mediumPadding),
            Text(
              'Il n\'y a pas de terrain disponible près de votre position.',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerrainsList() {
    return RefreshIndicator(
      onRefresh: _loadTerrainsProches,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(AppConstants.mediumPadding),
              color: AppConstants.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_terrainsProches.length} terrain(s) trouvé(s) près de vous',
                          style: AppConstants.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                        if (_terrainsProches.isNotEmpty && _terrainsProches.first.distance != null)
                          Text(
                            'Le plus proche à ${_terrainsProches.first.distanceFormatted}',
                            style: AppConstants.bodyStyle.copyWith(
                              fontSize: 11,
                              color: AppConstants.primaryColor.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final terrainWithDistance = _terrainsProches[index];
                return _buildTerrainCard(terrainWithDistance);
              },
              childCount: _terrainsProches.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainCard(TerrainWithDistance terrainWithDistance) {
    final terrain = terrainWithDistance.terrain;
    final thumbnailUrl = _imageService.getThumbnailUrl(terrain.photos);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppConstants.mediumPadding,
        vertical: AppConstants.smallPadding,
      ),
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
          child: Row(
            children: [
              // Image du terrain
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  color: AppConstants.primaryColor.withOpacity(0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                  child: thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.sports_soccer,
                            color: AppConstants.primaryColor,
                            size: 30,
                          ),
                        )
                      : Icon(
                          Icons.sports_soccer,
                          color: AppConstants.primaryColor,
                          size: 30,
                        ),
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
                      style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

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
                            terrain.ville,
                            style: AppConstants.bodyStyle.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Badge de distance
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppConstants.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.near_me,
                                size: 12,
                                color: AppConstants.primaryColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                terrainWithDistance.distanceFormatted,
                                style: AppConstants.bodyStyle.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Note
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: terrain.notemoyenne > 0 
                                  ? AppConstants.accentColor 
                                  : Colors.grey.shade400,
                            ),
                            SizedBox(width: 4),
                            Text(
                              terrain.notemoyenne > 0 
                                  ? terrain.notemoyenne.toStringAsFixed(1)
                                  : 'N/A',
                              style: AppConstants.bodyStyle.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        // Prix
                        Text(
                          '${terrain.prixHeure.toInt()} FCFA/h',
                          style: AppConstants.bodyStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicateur de distance
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getDistanceColor(terrainWithDistance.distance).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getDistanceColor(terrainWithDistance.distance).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getDistanceIcon(terrainWithDistance.distance),
                      color: _getDistanceColor(terrainWithDistance.distance),
                      size: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _getDistanceCategory(terrainWithDistance.distance),
                    style: AppConstants.bodyStyle.copyWith(
                      fontSize: 8,
                      color: _getDistanceColor(terrainWithDistance.distance),
                      fontWeight: FontWeight.w600,
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

  /// 🎨 Obtenir la couleur selon la distance
  Color _getDistanceColor(double? distance) {
    if (distance == null) return Colors.grey;
    
    if (distance <= 1) {
      return Colors.green; // Très proche
    } else if (distance <= 5) {
      return AppConstants.primaryColor; // Proche
    } else if (distance <= 15) {
      return Colors.orange; // Moyen
    } else {
      return Colors.red; // Loin
    }
  }

  /// 🔍 Obtenir l'icône selon la distance
  IconData _getDistanceIcon(double? distance) {
    if (distance == null) return Icons.location_off;
    
    if (distance <= 1) {
      return Icons.directions_walk; // À pied
    } else if (distance <= 5) {
      return Icons.directions_bike; // Vélo
    } else if (distance <= 15) {
      return Icons.directions_car; // Voiture proche
    } else {
      return Icons.directions_car; // Voiture loin
    }
  }

  /// 📝 Obtenir la catégorie de distance
  String _getDistanceCategory(double? distance) {
    if (distance == null) return 'N/A';
    
    if (distance <= 1) {
      return 'TRÈS PROCHE';
    } else if (distance <= 5) {
      return 'PROCHE';
    } else if (distance <= 15) {
      return 'MOYEN';
    } else {
      return 'LOIN';
    }
  }
}