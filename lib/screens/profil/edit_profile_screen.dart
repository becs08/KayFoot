import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

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
  User? _user;

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

  void _loadUserData() {
    _user = AuthService().currentUser;
    if (_user != null) {
      _nomController.text = _user!.nom;
      _telephoneController.text = _user!.telephone;
      _emailController.text = _user!.email;
      _selectedVille = _user!.ville;
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
                      // TODO: Implémenter la prise de photo
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Appareil photo à venir')),
                      );
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
                      // TODO: Implémenter la sélection depuis la galerie
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Galerie à venir')),
                      );
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
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
            backgroundImage: _user!.photo != null
                ? NetworkImage(_user!.photo!)
                : null,
            child: _user!.photo == null
                ? Icon(
                    Icons.person,
                    size: 60,
                    color: AppConstants.primaryColor,
                  )
                : null,
          ),
          
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _changePhoto,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
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