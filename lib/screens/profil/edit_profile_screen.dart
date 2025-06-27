import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/fallback_image_service.dart';
import '../../models/user.dart';
import '../../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _selectedVille = AppConstants.villes.first;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  User? _user;
  final ImageUploadService _imageUploadService = ImageUploadService();
  final FallbackImageService _fallbackImageService = FallbackImageService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    try {
      // Recharger l'utilisateur depuis Firestore pour avoir les dernières données
      await AuthService().reloadCurrentUser();
      _user = AuthService().currentUser;
      if (_user != null) {
        _nomController.text = _user!.nom;
        _telephoneController.text = _user!.telephone;
        _emailController.text = _user!.email;
        _selectedVille = _user!.ville;
        print('👤 Utilisateur rechargé (edit): ${_user?.photo}');
      }
    } catch (e) {
      print('❌ Erreur rechargement utilisateur (edit): $e');
      _user = AuthService().currentUser;
      if (_user != null) {
        _nomController.text = _user!.nom;
        _telephoneController.text = _user!.telephone;
        _emailController.text = _user!.email;
        _selectedVille = _user!.ville;
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_user != null) {
        final updatedUser = _user!.copyWith(
          nom: _nomController.text.trim(),
          telephone: _telephoneController.text.trim(),
          email: _emailController.text.trim(),
          ville: _selectedVille,
        );

        final result = await AuthService().updateProfile(updatedUser);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppConstants.successColor,
            ),
          );
          Navigator.of(context).pop(result.user); // Retourner l'utilisateur mis à jour
        } else {
          _showError(result.message);
        }
      }
    } catch (e) {
      _showError('Erreur lors de la mise à jour: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Modifier le profil')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Modifier le profil'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Enregistrer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Photo de profil
              _buildProfilePhoto(),
              
              SizedBox(height: AppConstants.largePadding),
              
              // Formulaire d'édition
              _buildEditForm(),
              
              SizedBox(height: AppConstants.largePadding),
              
              // Boutons d'action
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: ProfileAvatar(
        photoUrl: _user!.photo,
        radius: 60,
        fallbackText: _user!.nom,
        onTap: _isUploadingPhoto ? null : _changePhoto,
        showCameraIcon: true,
        isLoading: _isUploadingPhoto,
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        // Nom complet
        TextFormField(
          controller: _nomController,
          decoration: InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre nom';
            }
            if (value.trim().length < 2) {
              return 'Le nom doit contenir au moins 2 caractères';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Téléphone
        TextFormField(
          controller: _telephoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Téléphone',
            prefixIcon: Icon(Icons.phone),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre numéro de téléphone';
            }
            if (!RegExp(AppConstants.phonePattern).hasMatch(value.trim())) {
              return 'Numéro de téléphone invalide';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre email';
            }
            if (!RegExp(AppConstants.emailPattern).hasMatch(value.trim())) {
              return 'Adresse email invalide';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Ville
        DropdownButtonFormField<String>(
          value: _selectedVille,
          decoration: InputDecoration(
            labelText: 'Ville',
            prefixIcon: Icon(Icons.location_city),
          ),
          items: AppConstants.villes.map((String ville) {
            return DropdownMenuItem<String>(
              value: ville,
              child: Text(ville),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedVille = newValue!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Text(
                    'Enregistrer les modifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Annuler'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        SizedBox(height: AppConstants.largePadding),
        
        // Section dangereuse
        _buildDangerZone(),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Card(
      color: AppConstants.errorColor.withOpacity(0.05),
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: AppConstants.errorColor,
                  size: 20,
                ),
                SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Zone dangereuse',
                  style: AppConstants.subHeadingStyle.copyWith(
                    fontSize: 14,
                    color: AppConstants.errorColor,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: AppConstants.mediumPadding),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Changer le mot de passe'),
                      content: Text('Fonctionnalité à venir'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(Icons.lock),
                label: Text('Changer le mot de passe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.errorColor,
                  side: BorderSide(color: AppConstants.errorColor),
                ),
              ),
            ),
            
            SizedBox(height: AppConstants.smallPadding),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Supprimer le compte'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cette action est irréversible.'),
                          SizedBox(height: AppConstants.smallPadding),
                          Text(
                            'Toutes vos données seront définitivement supprimées.',
                            style: TextStyle(
                              color: AppConstants.errorColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Suppression de compte à venir')),
                            );
                          },
                          child: Text('Supprimer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.errorColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(Icons.delete_forever),
                label: Text('Supprimer le compte'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.errorColor,
                  side: BorderSide(color: AppConstants.errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}