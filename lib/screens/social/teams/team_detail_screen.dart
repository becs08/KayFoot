import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../models/social/team.dart';
import '../../../models/social/team_member.dart';
import '../../../models/social/team_request.dart';
import '../../../services/social/teams_service.dart';
import '../../../services/Authentification/auth_service.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailScreen({Key? key, required this.teamId}) : super(key: key);

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeamsService _teamsService = TeamsService();
  final AuthService _authService = AuthService();

  Team? _team;
  TeamMember? _currentUserMember;
  bool _isLoading = true;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeamData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamData() async {
    try {
      // Réparer la team si nécessaire (pour les teams existantes)
      await _teamsService.repairTeam(widget.teamId);

      final team = await _teamsService.getTeamById(widget.teamId);
      if (team != null && mounted) {
        setState(() {
          _team = team;
          _isLoading = false;
        });
        await _checkMembership();
      }
    } catch (e) {
      print('Erreur _loadTeamData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkMembership() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final isMember = await _teamsService.isUserMemberOfTeam(widget.teamId, currentUser.id);
      if (isMember && mounted) {
        // Récupérer les vraies données du membre depuis Firestore
        final memberData = await _teamsService.getUserTeamMember(widget.teamId, currentUser.id);
        if (memberData != null && mounted) {
          setState(() {
            _currentUserMember = memberData;
          });
        }
      }
    } catch (e) {
      print('Erreur _checkMembership: $e');
    }
  }

  Future<void> _joinTeam() async {
    if (_team == null) return;

    setState(() {
      _isJoining = true;
    });

    try {
      await _teamsService.joinTeam(widget.teamId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous avez rejoint ${_team!.name} !'),
            backgroundColor: Colors.green,
          ),
        );
        await _checkMembership();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _leaveTeam() async {
    if (_team == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la team'),
        content: Text('Êtes-vous sûr de vouloir quitter ${_team!.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.errorColor,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _teamsService.leaveTeam(widget.teamId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vous avez quitté ${_team!.name}'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _currentUserMember = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_team == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Team non trouvée'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildTeamHeader(),
              ),
              actions: [
                if (_currentUserMember?.canManageMembers() == true)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'invite':
                          _showInviteDialog();
                          break;
                        case 'requests':
                          _showJoinRequestsDialog();
                          break;
                        case 'settings':
                          _showTeamSettings();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'invite',
                        child: Row(
                          children: [
                            Icon(Icons.person_add),
                            SizedBox(width: 8),
                            Text('Ajouter un membre'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'requests',
                        child: Row(
                          children: [
                            Icon(Icons.mail),
                            SizedBox(width: 8),
                            Text('Demandes d\'adhésion'),
                          ],
                        ),
                      ),
                      if (_currentUserMember?.canEditTeam() == true)
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings),
                              SizedBox(width: 8),
                              Text('Paramètres'),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ];
        },
        body: Column(
          children: [
            // Boutons d'action
            if (_currentUserMember == null && !_team!.isFull)
              _buildActionButtons()
            else if (_currentUserMember != null && !_currentUserMember!.isCreator)
              Container(
                width: double.infinity,
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
                child: OutlinedButton.icon(
                  onPressed: _leaveTeam,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Quitter la team'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.errorColor,
                    side: const BorderSide(color: AppConstants.errorColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

            // Onglets
            Container(
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
              child: TabBar(
                controller: _tabController,
                labelColor: AppConstants.primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AppConstants.primaryColor,
                tabs: const [
                  Tab(text: 'Aperçu'),
                  Tab(text: 'Membres'),
                  Tab(text: 'Activité'),
                ],
              ),
            ),

            // Contenu des onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildMembersTab(),
                  _buildActivityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Avatar de la team
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  image: _team!.avatar != null
                      ? DecorationImage(
                          image: NetworkImage(_team!.avatar!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _team!.avatar == null
                    ? const Icon(
                        Icons.groups,
                        color: Colors.white,
                        size: 40,
                      )
                    : null,
              ),

              const SizedBox(height: 16),

              // Nom et stats
              Text(
                _team!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                _team!.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Membres', '${_team!.memberCount}/${_team!.maxMembers}'),
                  _buildStatColumn('Créateur', '@${_team!.creatorUsername}'),
                  _buildStatColumn('Créée', _formatDate(_team!.createdAt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description complète
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'À propos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _team!.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Informations
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoRow(Icons.lock, 'Confidentialité', _getPrivacyText(_team!.privacy)),
                _buildInfoRow(Icons.people, 'Membres', '${_team!.memberCount} / ${_team!.maxMembers}'),
                _buildInfoRow(Icons.calendar_today, 'Créée le', _formatDate(_team!.createdAt)),
                _buildInfoRow(Icons.update, 'Mise à jour', _formatDate(_team!.updatedAt)),
              ],
            ),
          ),

          // Tags
          if (_team!.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _team!.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return StreamBuilder<List<TeamMember>>(
      stream: _teamsService.getTeamMembers(widget.teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(
            child: Text(
              'Aucun membre pour le moment',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          );
        }

        // Trier les membres par rôle (créateur en premier, puis admins, puis membres)
        members.sort((a, b) {
          if (a.role == TeamMemberRole.creator) return -1;
          if (b.role == TeamMemberRole.creator) return 1;
          if (a.role == TeamMemberRole.admin && b.role != TeamMemberRole.admin) return -1;
          if (b.role == TeamMemberRole.admin && a.role != TeamMemberRole.admin) return 1;
          return a.joinedAt.compareTo(b.joinedAt);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return _buildMemberCard(member);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(TeamMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
          backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
          child: member.avatar == null
              ? Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          member.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${member.username}'),
            const SizedBox(height: 4),
            Text(
              'Membre depuis ${_formatDate(member.joinedAt)}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: _buildRoleBadge(member.role),
      ),
    );
  }

  Widget _buildRoleBadge(TeamMemberRole role) {
    Color color;
    String text;
    IconData icon;

    switch (role) {
      case TeamMemberRole.creator:
        color = Colors.purple;
        text = 'Créateur';
        icon = Icons.star;
        break;
      case TeamMemberRole.admin:
        color = Colors.orange;
        text = 'Admin';
        icon = Icons.admin_panel_settings;
        break;
      case TeamMemberRole.member:
        color = Colors.blue;
        text = 'Membre';
        icon = Icons.person;
        break;
    }

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

  Widget _buildActivityTab() {
    return const Center(
      child: Text(
        'Feed d\'activité à venir...',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
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
      child: _buildTeamActionButton(),
    );
  }

  Widget _buildTeamActionButton() {
    if (_team!.isPublic) {
      // Team publique: rejoindre directement
      return ElevatedButton.icon(
        onPressed: _isJoining ? null : _joinTeam,
        icon: _isJoining
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.group_add),
        label: Text(_isJoining ? 'Adhésion...' : 'Rejoindre la team'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else if (_team!.isPrivate) {
      // Team privée: demander à rejoindre
      return ElevatedButton.icon(
        onPressed: _isJoining ? null : _requestToJoinTeam,
        icon: _isJoining
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.mail),
        label: Text(_isJoining ? 'Envoi...' : 'Demander à rejoindre'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else {
      // Team personnelle: information
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.lock, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cette team est personnelle. Seuls les membres invités peuvent la rejoindre.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _requestToJoinTeam() async {
    setState(() {
      _isJoining = true;
    });

    try {
      await _teamsService.requestToJoinTeam(widget.teamId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande envoyée à ${_team!.name} !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  String _getPrivacyText(TeamPrivacy privacy) {
    switch (privacy) {
      case TeamPrivacy.public:
        return 'Publique';
      case TeamPrivacy.private:
        return 'Privée';
      case TeamPrivacy.personal:
        return 'Personnelle';
    }
  }

  // Afficher le dialogue d'invitation
  void _showInviteDialog() {
    final usernameController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inviter un utilisateur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Pseudo de l\'utilisateur',
                prefixIcon: Icon(Icons.alternate_email),
                hintText: 'Entrez le pseudo sans @',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
                prefixIcon: Icon(Icons.message),
                hintText: 'Message d\'invitation...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameController.text.trim();
              if (username.isNotEmpty) {
                Navigator.of(context).pop();
                await _sendInvitation(username, messageController.text.trim());
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  // Envoyer une invitation
  Future<void> _sendInvitation(String username, String? message) async {
    try {
      await _teamsService.inviteUserToTeam(widget.teamId, username, message: message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation envoyée à @$username'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  // Afficher les demandes d'adhésion
  void _showJoinRequestsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demandes d\'adhésion'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<List<TeamRequest>>(
            stream: _teamsService.getTeamJoinRequestsForTeam(widget.teamId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucune demande d\'adhésion',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: request.fromUserAvatar != null
                            ? NetworkImage(request.fromUserAvatar!)
                            : null,
                        child: request.fromUserAvatar == null
                            ? Text(request.fromUserName.isNotEmpty
                                ? request.fromUserName[0].toUpperCase()
                                : 'U')
                            : null,
                      ),
                      title: Text(request.fromUserName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${request.fromUsername}'),
                          if (request.message != null && request.message!.isNotEmpty)
                            Text(
                              request.message!,
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                          Text(
                            _formatDate(request.createdAt),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _acceptJoinRequest(request.id),
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Accepter',
                          ),
                          IconButton(
                            onPressed: () => _declineJoinRequest(request.id),
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Refuser',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Accepter une demande d'adhésion
  Future<void> _acceptJoinRequest(String requestId) async {
    try {
      await _teamsService.acceptTeamRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande acceptée'),
            backgroundColor: Colors.green,
          ),
        );
        // Recharger les données de la team
        await _loadTeamData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  // Refuser une demande d'adhésion
  Future<void> _declineJoinRequest(String requestId) async {
    try {
      await _teamsService.declineTeamRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande refusée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  // Paramètres de la team
  void _showTeamSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres de la team à venir...')),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Aujourd\'hui';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks semaine${weeks > 1 ? 's' : ''}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
