import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/app_constants.dart';
import '../../services/Authentification/auth_service.dart';
import '../../services/terrain/terrain_service.dart';
import '../../models/terrain.dart';
import '../../models/enums.dart';

class AddTerrainScreen extends StatefulWidget {
  @override
  _AddTerrainScreenState createState() => _AddTerrainScreenState();
}

class _AddTerrainScreenState extends State<AddTerrainScreen> {
  final TerrainService _terrainService = TerrainService();
  final AuthService _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Contrôleurs de champs
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();
  final _prixHeureController = TextEditingController();
  final _heureOuvertureController = TextEditingController();
  final _heureFermetureController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _googleMapsUrlController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // Valeurs sélectionnées
  TypeTerrain _typeTerrain = TypeTerrain.football;
  bool _disponible = true;
  bool _eclairage = false;
  bool _vestiaires = false;
  bool _parking = false;
  bool _securite = false;
  
  // Photos
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  // Horaires par jour
  Map<String, Map<String, String>> _horairesParJour = {
    'lundi': {'ouverture': '08', 'fermeture': '22'},
    'mardi': {'ouverture': '08', 'fermeture': '22'},
    'mercredi': {'ouverture': '08', 'fermeture': '22'},
    'jeudi': {'ouverture': '08', 'fermeture': '22'},
    'vendredi': {'ouverture': '08', 'fermeture': '22'},
    'samedi': {'ouverture': '08', 'fermeture': '22'},
    'dimanche': {'ouverture': '08', 'fermeture': '22'},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Ajouter un terrain'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: EdgeInsets.all(AppConstants.mediumPadding),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppConstants.primaryColor,
                        ),
                        SizedBox(width: AppConstants.smallPadding),
                        Expanded(
                          child: Text(
                            'Remplissez tous les champs pour ajouter votre terrain',
                            style: AppConstants.bodyStyle.copyWith(
                              color: AppConstants.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppConstants.smallPadding),
                    Row(
                      children: [
                        Icon(
                          Icons.pending_actions,
                          color: Colors.orange,
                          size: 16,
                        ),
                        SizedBox(width: AppConstants.smallPadding),
                        Expanded(
                          child: Text(
                            'Votre terrain nécessitera une validation par notre équipe avant d\'être visible.',
                            style: AppConstants.bodyStyle.copyWith(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppConstants.largePadding),

              // Informations de base
              _buildSectionHeader('Informations générales'),
              _buildCard([
                _buildTextField(
                  controller: _nomController,
                  label: 'Nom du terrain',
                  hint: 'Ex: Terrain Municipal',
                  icon: Icons.sports_soccer,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le nom est obligatoire';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Décrivez votre terrain...',
                  icon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La description est obligatoire';
                    }
                    return null;
                  },
                ),
                _buildDropdownField(),
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Localisation
              _buildSectionHeader('Localisation'),
              _buildCard([
                _buildTextField(
                  controller: _adresseController,
                  label: 'Adresse',
                  hint: 'Adresse complète',
                  icon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'L\'adresse est obligatoire';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _villeController,
                  label: 'Ville',
                  hint: 'Ex: Dakar',
                  icon: Icons.location_city,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La ville est obligatoire';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _googleMapsUrlController,
                  label: 'Lien Google Maps (optionnel)',
                  hint: 'https://maps.google.com/...',
                  icon: Icons.map,
                  keyboardType: TextInputType.url,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _latitudeController,
                        label: 'Latitude',
                        hint: '14.7167',
                        icon: Icons.gps_fixed,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final lat = double.tryParse(value);
                            if (lat == null || lat < -90 || lat > 90) {
                              return 'Latitude invalide';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: AppConstants.mediumPadding),
                    Expanded(
                      child: _buildTextField(
                        controller: _longitudeController,
                        label: 'Longitude',
                        hint: '-17.4677',
                        icon: Icons.gps_fixed,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final lng = double.tryParse(value);
                            if (lng == null || lng < -180 || lng > 180) {
                              return 'Longitude invalide';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                _buildLocationHelper(),
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Photos
              _buildSectionHeader('Photos du terrain'),
              _buildCard([
                _buildPhotosSection(),
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Tarifs
              _buildSectionHeader('Tarifs et contact'),
              _buildCard([
                _buildTextField(
                  controller: _prixHeureController,
                  label: 'Prix par heure (FCFA)',
                  hint: '5000',
                  icon: Icons.monetization_on,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le prix est obligatoire';
                    }
                    final prix = double.tryParse(value);
                    if (prix == null || prix <= 0) {
                      return 'Prix invalide';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _telephoneController,
                  label: 'Téléphone de contact',
                  hint: '77 123 45 67',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Horaires par jour
              _buildSectionHeader('Horaires d\'ouverture'),
              _buildCard([
                _buildHorairesSection(),
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Équipements
              _buildSectionHeader('Équipements disponibles'),
              _buildCard([
                _buildSwitchTile(
                  title: 'Éclairage',
                  subtitle: 'Terrain éclairé pour jouer le soir',
                  icon: Icons.lightbulb,
                  value: _eclairage,
                  onChanged: (value) {
                    setState(() {
                      _eclairage = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Vestiaires',
                  subtitle: 'Vestiaires avec douches',
                  icon: Icons.shower,
                  value: _vestiaires,
                  onChanged: (value) {
                    setState(() {
                      _vestiaires = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Parking',
                  subtitle: 'Parking disponible',
                  icon: Icons.local_parking,
                  value: _parking,
                  onChanged: (value) {
                    setState(() {
                      _parking = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Sécurité',
                  subtitle: 'Agent de sécurité ou surveillance',
                  icon: Icons.security,
                  value: _securite,
                  onChanged: (value) {
                    setState(() {
                      _securite = value;
                    });
                  },
                ),
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Statut
              _buildSectionHeader('Statut du terrain'),
              _buildCard([
                _buildSwitchTile(
                  title: 'Terrain disponible',
                  subtitle: 'Les clients peuvent réserver ce terrain',
                  icon: Icons.check_circle,
                  value: _disponible,
                  onChanged: (value) {
                    setState(() {
                      _disponible = value;
                    });
                  },
                ),
              ]),

              SizedBox(height: AppConstants.largePadding * 2),

              // Bouton d'ajout
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _ajouterTerrain,
                  icon: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.add_business),
                  label: Text(_isLoading ? 'Ajout en cours...' : 'Ajouter le terrain'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      child: Text(
        title,
        style: AppConstants.subHeadingStyle.copyWith(
          color: AppConstants.primaryColor,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
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
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            borderSide: BorderSide(color: AppConstants.primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.mediumPadding),
      child: DropdownButtonFormField<TypeTerrain>(
        value: _typeTerrain,
        decoration: InputDecoration(
          labelText: 'Type de terrain',
          prefixIcon: Icon(Icons.category),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            borderSide: BorderSide(color: AppConstants.primaryColor),
          ),
        ),
        items: TypeTerrain.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(_getTypeTerrainText(type)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _typeTerrain = value;
            });
          }
        },
      ),
    );
  }

  String _getTypeTerrainText(TypeTerrain type) {
    return type.displayName;
  }

  Widget _buildLocationHelper() {
    return Container(
      padding: EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Astuce: Utilisez Google Maps pour trouver les coordonnées exactes',
              style: AppConstants.bodyStyle.copyWith(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      children: [
        // Boutons d'ajout de photos
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library),
                label: Text('Galerie'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                ),
              ),
            ),
            SizedBox(width: AppConstants.mediumPadding),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: Icon(Icons.camera_alt),
                label: Text('Appareil photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Aperçu des photos sélectionnées
        if (_selectedImages.isEmpty)
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(AppConstants.smallRadius),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey.shade400),
                  SizedBox(height: 8),
                  Text(
                    'Aucune photo sélectionnée',
                    style: AppConstants.bodyStyle.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: EdgeInsets.only(right: AppConstants.smallPadding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                        child: Image.file(
                          _selectedImages[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(height: AppConstants.smallPadding),
          Text(
            '${_selectedImages.length} photo(s) sélectionnée(s)',
            style: AppConstants.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHorairesSection() {
    return Column(
      children: [
        // En-tête avec option "Appliquer à tous"
        Row(
          children: [
            Expanded(
              child: Text(
                'Configurez les horaires pour chaque jour',
                style: AppConstants.bodyStyle.copyWith(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _applyHoursToAll,
              icon: Icon(Icons.copy_all, size: 16),
              label: Text('Appliquer à tous'),
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        // Horaires par jour
        ..._horairesParJour.entries.map((entry) {
          final jour = entry.key;
          final horaires = entry.value;
          
          return Padding(
            padding: EdgeInsets.only(bottom: AppConstants.smallPadding),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _capitalizeFirst(jour),
                    style: AppConstants.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: horaires['ouverture'],
                          decoration: InputDecoration(
                            labelText: 'Ouverture',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                            ),
                          ),
                          items: List.generate(24, (index) {
                            final hour = index.toString().padLeft(2, '0');
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('${hour}h'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _horairesParJour[jour]!['ouverture'] = value;
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: AppConstants.smallPadding),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: horaires['fermeture'],
                          decoration: InputDecoration(
                            labelText: 'Fermeture',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                            ),
                          ),
                          items: List.generate(24, (index) {
                            final hour = index.toString().padLeft(2, '0');
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('${hour}h'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _horairesParJour[jour]!['fermeture'] = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de l\'image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _applyHoursToAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appliquer les horaires'),
        content: Text('Voulez-vous appliquer les horaires du lundi à tous les jours de la semaine ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final lundiHoraires = _horairesParJour['lundi']!;
              setState(() {
                for (String jour in _horairesParJour.keys) {
                  if (jour != 'lundi') {
                    _horairesParJour[jour] = Map.from(lundiHoraires);
                  }
                }
              });
              Navigator.pop(context);
            },
            child: Text('Appliquer'),
            style: TextButton.styleFrom(foregroundColor: AppConstants.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        secondary: Icon(icon, color: AppConstants.primaryColor),
        value: value,
        onChanged: onChanged,
        activeColor: AppConstants.primaryColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _ajouterTerrain() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Validation des coordonnées GPS si fournies
      double latitude = 0.0;
      double longitude = 0.0;
      
      if (_latitudeController.text.isNotEmpty) {
        latitude = double.parse(_latitudeController.text);
      }
      if (_longitudeController.text.isNotEmpty) {
        longitude = double.parse(_longitudeController.text);
      }

      // Créer les équipements sous forme de liste
      List<String> equipements = [];
      if (_eclairage) equipements.add('Éclairage');
      if (_vestiaires) equipements.add('Vestiaires');
      if (_parking) equipements.add('Parking');
      if (_securite) equipements.add('Sécurité');

      // Créer les disponibilités basées sur les horaires par jour
      Map<String, List<String>> disponibilites = {};
      if (_disponible) {
        for (String jour in _horairesParJour.keys) {
          final horaires = _horairesParJour[jour]!;
          final heureOuverture = int.parse(horaires['ouverture']!);
          final heureFermeture = int.parse(horaires['fermeture']!);
          
          // Créer des créneaux d'1 heure pour ce jour au format "HH:MM-HH:MM"
          List<String> creneaux = [];
          if (heureOuverture < heureFermeture) {
            for (int h = heureOuverture; h < heureFermeture; h++) {
              final heureDebut = '${h.toString().padLeft(2, '0')}:00';
              final heureFin = '${(h + 1).toString().padLeft(2, '0')}:00';
              creneaux.add('$heureDebut-$heureFin');
            }
          }
          
          disponibilites[jour] = creneaux;
        }
      }

      // Note: Les photos seront uploadées séparément et les URLs ajoutées plus tard
      // Pour l'instant, on crée le terrain sans photos
      print('📸 ${_selectedImages.length} photos sélectionnées à uploader');
      
      // Créer l'objet Terrain
      final terrain = Terrain(
        id: '', // Sera généré par Firestore
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        ville: _villeController.text.trim(),
        adresse: _adresseController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        googleMapsUrl: _googleMapsUrlController.text.trim().isNotEmpty 
            ? _googleMapsUrlController.text.trim() 
            : null,
        gerantId: user.id,
        photos: [], // Les photos seront ajoutées après upload
        equipements: equipements,
        prixHeure: double.parse(_prixHeureController.text),
        disponibilites: disponibilites,
        notemoyenne: 0.0,
        nombreAvis: 0,
        dateCreation: DateTime.now(),
        estValide: false, // En attente de validation par le super-admin
        dateValidation: null,
      );

      // Ajouter le terrain
      final result = await _terrainService.addTerrain(terrain);
      
      if (!result.success) {
        throw Exception(result.message);
      }

      // Succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terrain ajouté avec succès ! En attente de validation.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _prixHeureController.dispose();
    _heureOuvertureController.dispose();
    _heureFermetureController.dispose();
    _telephoneController.dispose();
    _googleMapsUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}