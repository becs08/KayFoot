import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/terrain_service.dart';
import '../../services/statistics_service.dart';
import '../../models/terrain.dart';
import '../../models/user.dart';
import '../terrain/detail_screen.dart';
import '../terrain/list_screen.dart';
import '../profil/profile_screen.dart';
import '../reservation/reservations_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Terrain> _featuredTerrains = [];
  bool _isLoading = true;
  
  // Statistiques dynamiques
  final StatisticsService _statsService = StatisticsService();
  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadFeaturedTerrains();
    _loadUserStats();
  }

  Future<void> _loadFeaturedTerrains() async {
    try {
      final terrains = await TerrainService().getAllTerrains();
      setState(() {
        _featuredTerrains.clear();
        _featuredTerrains.addAll(terrains.take(3));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final stats = await _statsService.calculateUserStats(user.id);
        setState(() {
          _userStats = stats;
          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          TerrainListScreen(),
          ReservationsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
            label: 'Terrains',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: 'Réservations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final user = AuthService().currentUser;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadFeaturedTerrains,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec salutation
              _buildHeader(user),

              SizedBox(height: AppConstants.largePadding),

              // Barre de recherche
              _buildSearchBar(),

              SizedBox(height: AppConstants.largePadding),

              // Actions rapides
              _buildQuickActions(),

              SizedBox(height: AppConstants.largePadding),

              // Terrains en vedette
              _buildFeaturedTerrains(),

              SizedBox(height: AppConstants.largePadding),

              // Statistiques utilisateur (pour les joueurs)
              if (user?.role == UserRole.joueur) _buildUserStats(),
            ],
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
                  'Salut ${user?.nom ?? 'Utilisateur'} !',
                  style: AppConstants.subHeadingStyle.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),

                SizedBox(height: AppConstants.smallPadding),

                Text(
                  user?.role == UserRole.joueur
                      ? 'Prêt pour votre prochain match ?'
                      : 'Gérez vos terrains facilement',
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              user?.role == UserRole.joueur
                  ? Icons.sports_soccer
                  : Icons.business,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => TerrainListScreen()),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.mediumPadding,
          vertical: AppConstants.smallPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade600),
            SizedBox(width: AppConstants.smallPadding),
            Text(
              'Rechercher un terrain...',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final user = AuthService().currentUser;

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
                icon: Icons.location_on,
                title: 'Terrains proches',
                subtitle: 'Trouvez près de vous',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => TerrainListScreen()),
                  );
                },
              ),
            ),

            SizedBox(width: AppConstants.mediumPadding),

            Expanded(
              child: _buildActionCard(
                icon: user?.role == UserRole.joueur
                    ? Icons.history
                    : Icons.add_business,
                title: user?.role == UserRole.joueur
                    ? 'Historique'
                    : 'Ajouter terrain',
                subtitle: user?.role == UserRole.joueur
                    ? 'Vos réservations'
                    : 'Nouveau terrain',
                onTap: () {
                  if (user?.role == UserRole.joueur) {
                    setState(() {
                      _currentIndex = 2; // Onglet réservations
                    });
                  } else {
                    // TODO: Navigation vers ajout de terrain
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fonctionnalité à venir')),
                    );
                  }
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
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                color: AppConstants.primaryColor,
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

  Widget _buildFeaturedTerrains() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Terrains populaires',
              style: AppConstants.subHeadingStyle,
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 1; // Onglet terrains
                });
              },
              child: Text('Voir tout'),
            ),
          ],
        ),

        SizedBox(height: AppConstants.mediumPadding),

        _isLoading
            ? Center(child: CircularProgressIndicator())
            : _featuredTerrains.isEmpty
                ? Center(
                    child: Text(
                      'Aucun terrain disponible',
                      style: AppConstants.bodyStyle.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _featuredTerrains.length,
                      itemBuilder: (context, index) {
                        return _buildTerrainCard(_featuredTerrains[index]);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildTerrainCard(Terrain terrain) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TerrainDetailScreen(terrain: terrain),
          ),
        );
      },
      child: Container(
        width: 160,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du terrain
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.mediumRadius),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.sports_soccer,
                  size: 40,
                  color: AppConstants.primaryColor,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(AppConstants.smallPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    terrain.nom,
                    style: AppConstants.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          terrain.ville,
                          style: AppConstants.bodyStyle.copyWith(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: _statsService.calculateTerrainStats(terrain.id),
                        builder: (context, snapshot) {
                          final noteMoyenne = snapshot.hasData && snapshot.data!['noteMoyenne'] != null && snapshot.data!['noteMoyenne'] > 0
                              ? snapshot.data!['noteMoyenne'] as double
                              : 0.0;
                          
                          return Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: noteMoyenne > 0 ? AppConstants.accentColor : Colors.grey.shade400,
                              ),
                              SizedBox(width: 2),
                              Text(
                                noteMoyenne > 0 ? noteMoyenne.toStringAsFixed(1) : 'N/A',
                                style: AppConstants.bodyStyle.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      Text(
                        '${terrain.prixHeure.toInt()} FCFA/h',
                        style: AppConstants.bodyStyle.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStats() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vos statistiques',
                style: AppConstants.subHeadingStyle,
              ),
              if (_isLoadingStats)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),

          SizedBox(height: AppConstants.mediumPadding),

          if (_isLoadingStats)
            _buildLoadingStats()
          else
            _buildRealStats(),
        ],
      ),
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.sports_soccer,
            value: '...',
            label: 'Matchs joués',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.schedule,
            value: '...',
            label: 'Temps de jeu',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.place,
            value: '...',
            label: 'Terrains visités',
          ),
        ),
      ],
    );
  }

  Widget _buildRealStats() {
    final matchsJoues = _userStats['matchsJoues'] ?? 0;
    final tempsJeuMinutes = _userStats['tempsJeuMinutes'] ?? 0;
    final terrainsVisites = _userStats['terrainsVisites'] ?? 0;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.sports_soccer,
            value: '$matchsJoues',
            label: 'Matchs joués',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.schedule,
            value: _statsService.formatTempsJeu(tempsJeuMinutes),
            label: 'Temps de jeu',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.place,
            value: '$terrainsVisites',
            label: 'Terrains visités',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppConstants.primaryColor,
          size: 24,
        ),

        SizedBox(height: AppConstants.smallPadding),

        Text(
          value,
          style: AppConstants.subHeadingStyle.copyWith(
            color: AppConstants.primaryColor,
          ),
        ),

        Text(
          label,
          style: AppConstants.bodyStyle.copyWith(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
