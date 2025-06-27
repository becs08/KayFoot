import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/statistics_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/fallback_image_service.dart';
import '../../models/user.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  final StatisticsService _statsService = StatisticsService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final FallbackImageService _fallbackImageService = FallbackImageService();
  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserStats();
  }

  Future <void> _loadUserData() async {
    try {
      // Recharger l'utilisateur depuis Firestore pour avoir les dernières données
      await AuthService().reloadCurrentUser();
      setState(() {
        _user = AuthService().currentUser;
      });
      print('👤 Utilisateur rechargé: ${_user?.photo}');
    } catch (e) {
      print('❌ Erreur rechargement utilisateur: $e');
      setState(() {
        _user = AuthService().currentUser;
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnexion'),
        content: Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.of(context).push<User?>(
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    );

    if (result != null) {
      // Recharger les données utilisateur après modification
      await _loadUserData();
      // Aussi recharger les stats si nécessaire
      await _loadUserStats();
    }
  }

  void _changePhoto() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.mediumRadius),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Changer la photo de profil',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            SizedBox(height: AppConstants.largePadding),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickImageFromCamera();
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text('Appareil photo'),
                  ),
                ),

                SizedBox(width: AppConstants.mediumPadding),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickImageFromGallery();
                    },
                    icon: Icon(Icons.photo_library),
                    label: Text('Galerie'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionner une image depuis la galerie
  Future<void> _pickImageFromGallery() async {
    try {
      setState(() {
        _isUploadingPhoto = true;
      });

      // Sélectionner l'image
      final File? imageFile = await _fallbackImageService.pickImageFromGallery();

      if (imageFile == null) {
        _showError('Aucune image sélectionnée');
        return;
      }

      // Valider l'image
      if (!_fallbackImageService.isValidImage(imageFile)) {
        _showError('Format d\'image non valide ou fichier trop volumineux (max 5MB)');
        return;
      }

      // Uploader l'image
      await _uploadProfileImage(imageFile);
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: ${e.toString()}');
    } finally {
      setState(() {
        _isUploadingPhoto = false;
      });
    }
  }

  /// Prendre une photo avec l'appareil photo
  Future<void> _pickImageFromCamera() async {
    try {
      setState(() {
        _isUploadingPhoto = true;
      });

      // Prendre la photo
      final File? imageFile = await _fallbackImageService.pickImageFromCamera();

      if (imageFile == null) {
        _showError('Aucune photo prise');
        return;
      }

      // Valider l'image
      if (!_fallbackImageService.isValidImage(imageFile)) {
        _showError('Format d\'image non valide ou fichier trop volumineux (max 5MB)');
        return;
      }

      // Uploader l'image
      await _uploadProfileImage(imageFile);
    } catch (e) {
      _showError('Erreur lors de la prise de photo: ${e.toString()}');
    } finally {
      setState(() {
        _isUploadingPhoto = false;
      });
    }
  }

  /// Upload l'image de profil
  Future<void> _uploadProfileImage(File imageFile) async {
    if (_user == null) {
      _showError('Utilisateur non connecté');
      return;
    }

    try {
      // Afficher la taille du fichier
      final double sizeInMB = _fallbackImageService.getImageSizeInMB(imageFile);
      print('📸 Taille de l\'image: ${sizeInMB.toStringAsFixed(2)} MB');

      String? downloadUrl;

      // Essayer d'uploader vers Firebase Storage d'abord
      downloadUrl = await _imageUploadService.uploadProfileImage(
        imageFile,
        _user!.id,
        oldImageUrl: _user!.photo,
      );

      // Si Firebase Storage échoue, utiliser le service de secours
      if (downloadUrl == null) {
        print('⚠️ Firebase Storage non disponible, utilisation du service de secours');
        downloadUrl = await _fallbackImageService.convertImageToBase64(imageFile);

        if (downloadUrl == null) {
          _showError('Erreur lors de la conversion de l\'image');
          return;
        }
      }

      // Mettre à jour le profil avec la nouvelle photo
      final result = await AuthService().updateProfilePhoto(downloadUrl);

      if (result.success) {
        setState(() {
          _user = result.user;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo de profil mise à jour avec succès'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Erreur lors de la mise à jour de la photo: ${e.toString()}');
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

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Profil')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mon profil'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          children: [
            // Photo et informations principales
            _buildProfileHeader(),

            SizedBox(height: AppConstants.largePadding),

            // Informations personnelles
            _buildPersonalInfo(),

            SizedBox(height: AppConstants.mediumPadding),

            // Statistiques (pour les joueurs)
            if (_user!.role == UserRole.joueur) _buildStats(),

            SizedBox(height: AppConstants.mediumPadding),

            // Paramètres et options
            _buildSettings(),

            SizedBox(height: AppConstants.largePadding),

            // Bouton de déconnexion
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          children: [
            // Photo de profil
            ProfileAvatar(
              photoUrl: _user!.photo,
              radius: 50,
              fallbackText: _user!.nom,
              onTap: _isUploadingPhoto ? null : _changePhoto,
              showCameraIcon: true,
              isLoading: _isUploadingPhoto,
            ),

            SizedBox(height: AppConstants.mediumPadding),

            // Nom et rôle
            Text(
              _user!.nom,
              style: AppConstants.headingStyle.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppConstants.smallPadding),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.mediumPadding,
                vertical: AppConstants.smallPadding,
              ),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _user!.role == UserRole.joueur ? 'Joueur' : 'Gérant',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'Membre depuis ${_formatMemberSince(_user!.dateCreation)}',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations personnelles',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            SizedBox(height: AppConstants.mediumPadding),

            _buildInfoRow(
              icon: Icons.email,
              label: 'Email',
              value: _user!.email,
            ),

            _buildInfoRow(
              icon: Icons.phone,
              label: 'Téléphone',
              value: _user!.telephone,
            ),

            _buildInfoRow(
              icon: Icons.location_city,
              label: 'Ville',
              value: _user!.ville,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    // Utiliser les vraies statistiques dynamiques (seulement 3 stats)
    final matchsJoues = _userStats['matchsJoues'] ?? 0;
    final tempsJeuMinutes = _userStats['tempsJeuMinutes'] ?? 0;
    final terrainsVisites = _userStats['terrainsVisites'] ?? 0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes statistiques',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),

            SizedBox(height: AppConstants.mediumPadding),

            if (_isLoadingStats)
              Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.sports_soccer,
                      value: matchsJoues.toString(),
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
                      value: terrainsVisites.toString(),
                      label: 'Terrains visités',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return Card(
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Gérer les notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Paramètres notifications à venir')),
              );
            },
          ),

          Divider(height: 1),

          _buildSettingItem(
            icon: Icons.privacy_tip,
            title: 'Confidentialité',
            subtitle: 'Paramètres de confidentialité',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Paramètres confidentialité à venir')),
              );
            },
          ),

          Divider(height: 1),

          _buildSettingItem(
            icon: Icons.help,
            title: 'Aide et support',
            subtitle: 'FAQ et contact',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Aide et support à venir')),
              );
            },
          ),

          Divider(height: 1),

          _buildSettingItem(
            icon: Icons.info,
            title: 'À propos',
            subtitle: 'Version ${AppConstants.appVersion}',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: Icon(
                  Icons.sports_soccer,
                  color: AppConstants.primaryColor,
                ),
                children: [
                  Text('Application de réservation de terrains de minifoot au Sénégal'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: Icon(Icons.logout),
        label: Text('Se déconnecter'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.errorColor,
          side: BorderSide(color: AppConstants.errorColor),
          padding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),

          SizedBox(width: AppConstants.mediumPadding),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                Text(
                  value,
                  style: AppConstants.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            fontSize: 18,
          ),
        ),

        Text(
          label,
          style: AppConstants.bodyStyle.copyWith(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppConstants.primaryColor,
      ),
      title: Text(
        title,
        style: AppConstants.bodyStyle.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppConstants.bodyStyle.copyWith(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  String _formatMemberSince(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years an${years > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months mois';
    } else {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    }
  }
}
