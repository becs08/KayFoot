import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../models/social/team.dart';
import '../../../services/social/teams_service.dart';
import 'team_create_screen.dart';
import 'team_detail_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({Key? key}) : super(key: key);

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeamsService _teamsService = TeamsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header avec actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Bouton créer + recherche
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Rechercher une team...',
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TeamCreateScreen(),
                          ),
                        );
                        if (result == true) {
                          // Rafraîchir la liste
                          setState(() {});
                        }
                      },
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Onglets
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppConstants.primaryColor,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Mes Teams'),
                      Tab(text: 'Découvrir'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyTeamsTab(),
                _buildDiscoverTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTeamsTab() {
    return StreamBuilder<List<Team>>(
      stream: _teamsService.getUserTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final teams = snapshot.data ?? [];

        // Filtrer selon la recherche
        final filteredTeams = teams.where((team) {
          if (_searchQuery.isEmpty) return true;
          return team.name.toLowerCase().contains(_searchQuery) ||
                 team.description.toLowerCase().contains(_searchQuery);
        }).toList();

        if (filteredTeams.isEmpty) {
          return _buildEmptyState(
            icon: _searchQuery.isNotEmpty ? Icons.search_off : Icons.groups_outlined,
            title: _searchQuery.isNotEmpty ? 'Aucune team trouvée' : 'Aucune team',
            subtitle: _searchQuery.isNotEmpty
                ? 'Essayez avec un autre terme'
                : 'Créez votre première team ou rejoignez-en une !',
            actionText: _searchQuery.isEmpty ? 'Créer une team' : null,
            onAction: _searchQuery.isEmpty ? () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const TeamCreateScreen()),
            ) : null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredTeams.length,
          itemBuilder: (context, index) {
            return _buildTeamCard(filteredTeams[index], isMyTeam: true);
          },
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return StreamBuilder<List<Team>>(
      stream: _teamsService.getPublicTeams(searchQuery: _searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final teams = snapshot.data ?? [];

        if (teams.isEmpty) {
          return _buildEmptyState(
            icon: _searchQuery.isNotEmpty ? Icons.search_off : Icons.explore_outlined,
            title: _searchQuery.isNotEmpty ? 'Aucune team trouvée' : 'Aucune team publique',
            subtitle: _searchQuery.isNotEmpty
                ? 'Essayez avec un autre terme'
                : 'Soyez le premier à créer une team publique !',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: teams.length,
          itemBuilder: (context, index) {
            return _buildTeamCard(teams[index], isMyTeam: false);
          },
        );
      },
    );
  }

  Widget _buildTeamCard(Team team, {required bool isMyTeam}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TeamDetailScreen(teamId: team.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar de la team
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: team.avatar != null
                          ? DecorationImage(
                              image: NetworkImage(team.avatar!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: team.avatar == null
                        ? Icon(
                            Icons.groups,
                            color: AppConstants.primaryColor,
                            size: 25,
                          )
                        : null,
                  ),

                  const SizedBox(width: 12),

                  // Infos principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                team.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildPrivacyBadge(team.privacy),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          team.description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stats et infos
              Row(
                children: [
                  _buildStatChip(
                    Icons.people,
                    '${team.memberCount}/${team.maxMembers}',
                    Colors.blue,
                  ),

                  const SizedBox(width: 8),

                  _buildStatChip(
                    Icons.person,
                    '@${team.creatorUsername}',
                    Colors.green,
                  ),

                  const Spacer(),

                  if (!isMyTeam && !team.isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Rejoindre',
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (team.isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Complète',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              // Tags
              if (team.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: team.tags.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyBadge(TeamPrivacy privacy) {
    IconData icon;
    Color color;
    String text;

    switch (privacy) {
      case TeamPrivacy.public:
        icon = Icons.public;
        color = Colors.green;
        text = 'Public';
        break;
      case TeamPrivacy.private:
        icon = Icons.lock;
        color = Colors.orange;
        text = 'Privé';
        break;
      case TeamPrivacy.personal:
        icon = Icons.mail;
        color = Colors.blue;
        text = 'Invitation';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppConstants.subHeadingStyle.copyWith(
                color: Colors.grey.shade600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur lors du chargement',
            style: AppConstants.subHeadingStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Veuillez réessayer plus tard',
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
