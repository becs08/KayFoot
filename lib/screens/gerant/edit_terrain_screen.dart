import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../services/terrain/terrain_service.dart';
import '../../models/terrain.dart';
import '../../models/terrain_extended.dart';
import '../../models/enums.dart';

class EditTerrainScreen extends StatefulWidget {
  final Terrain terrain;

  const EditTerrainScreen({Key? key, required this.terrain}) : super(key: key);

  @override
  _EditTerrainScreenState createState() => _EditTerrainScreenState();
}

class _EditTerrainScreenState extends State<EditTerrainScreen> {
  final TerrainService _terrainService = TerrainService();
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Contrôleurs de champs
  late final TextEditingController _nomController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _adresseController;
  late final TextEditingController _villeController;
  late final TextEditingController _prixHeureController;
  late final TextEditingController _heureOuvertureController;
  late final TextEditingController _heureFermetureController;
  late final TextEditingController _telephoneController;

  // Valeurs sélectionnées
  late TypeTerrain _typeTerrain;
  late bool _disponible;
  late bool _eclairage;
  late bool _vestiaires;
  late bool _parking;
  late bool _securite;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final terrain = widget.terrain;
    
    _nomController = TextEditingController(text: terrain.nom);
    _descriptionController = TextEditingController(text: terrain.description);
    _adresseController = TextEditingController(text: terrain.adresse);
    _villeController = TextEditingController(text: terrain.ville);
    _prixHeureController = TextEditingController(text: terrain.prixHeure.toString());
    _heureOuvertureController = TextEditingController(text: terrain.heureOuverture.toString());
    _heureFermetureController = TextEditingController(text: terrain.heureFermeture.toString());
    _telephoneController = TextEditingController(text: terrain.telephone ?? '');

    _typeTerrain = terrain.type;
    _disponible = terrain.disponible;
    final equipementsMap = terrain.equipementsMap;
    _eclairage = equipementsMap['eclairage'] ?? false;
    _vestiaires = equipementsMap['vestiaires'] ?? false;
    _parking = equipementsMap['parking'] ?? false;
    _securite = equipementsMap['securite'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Modifier le terrain'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _supprimerTerrain,
            icon: Icon(Icons.delete),
            tooltip: 'Supprimer le terrain',
          ),
        ],
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      color: Colors.orange,
                    ),
                    SizedBox(width: AppConstants.smallPadding),
                    Expanded(
                      child: Text(
                        'Modifiez les informations de votre terrain',
                        style: AppConstants.bodyStyle.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
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
              ]),

              SizedBox(height: AppConstants.largePadding),

              // Horaires et tarifs
              _buildSectionHeader('Horaires et tarifs'),
              _buildCard([
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _heureOuvertureController,
                        label: 'Heure d\'ouverture',
                        hint: '08',
                        icon: Icons.access_time,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Obligatoire';
                          }
                          final hour = int.tryParse(value);
                          if (hour == null || hour < 0 || hour > 23) {
                            return 'Heure invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: AppConstants.mediumPadding),
                    Expanded(
                      child: _buildTextField(
                        controller: _heureFermetureController,
                        label: 'Heure de fermeture',
                        hint: '22',
                        icon: Icons.access_time,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Obligatoire';
                          }
                          final hour = int.tryParse(value);
                          if (hour == null || hour < 0 || hour > 23) {
                            return 'Heure invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
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

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _supprimerTerrain,
                      icon: Icon(Icons.delete),
                      label: Text('Supprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppConstants.mediumPadding),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _modifierTerrain,
                      icon: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.save),
                      label: Text(_isLoading ? 'Modification...' : 'Enregistrer'),
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

  Future<void> _modifierTerrain() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validation des heures
      final heureOuverture = int.parse(_heureOuvertureController.text);
      final heureFermeture = int.parse(_heureFermetureController.text);
      
      if (heureOuverture >= heureFermeture) {
        throw Exception('L\'heure de fermeture doit être après l\'heure d\'ouverture');
      }

      // Créer les équipements sous forme de liste
      List<String> equipements = [];
      if (_eclairage) equipements.add('Éclairage');
      if (_vestiaires) equipements.add('Vestiaires');
      if (_parking) equipements.add('Parking');
      if (_securite) equipements.add('Sécurité');

      // Créer les disponibilités mises à jour
      Map<String, List<String>> disponibilites = {};
      if (_disponible) {
        // Créer des créneaux d'1 heure
        List<String> creneaux = [];
        for (int h = heureOuverture; h < heureFermeture; h++) {
          creneaux.add('${h.toString().padLeft(2, '0')}:00');
        }
        
        // Ajouter pour tous les jours de la semaine
        disponibilites = {
          'lundi': List.from(creneaux),
          'mardi': List.from(creneaux),
          'mercredi': List.from(creneaux),
          'jeudi': List.from(creneaux),
          'vendredi': List.from(creneaux),
          'samedi': List.from(creneaux),
          'dimanche': List.from(creneaux),
        };
      }

      // Créer le terrain modifié
      final terrainModifie = widget.terrain.copyWith(
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        ville: _villeController.text.trim(),
        adresse: _adresseController.text.trim(),
        equipements: equipements,
        prixHeure: double.parse(_prixHeureController.text),
        disponibilites: disponibilites,
      );

      // Modifier le terrain
      final result = await _terrainService.updateTerrain(terrainModifie);
      
      if (!result.success) {
        throw Exception(result.message);
      }

      // Succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terrain modifié avec succès'),
          backgroundColor: Colors.green,
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

  Future<void> _supprimerTerrain() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le terrain'),
        content: Text('Êtes-vous sûr de vouloir supprimer \"${widget.terrain.nom}\" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await _terrainService.deleteTerrain(widget.terrain.id);
        
        if (!result.success) {
          throw Exception(result.message);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terrain supprimé'),
            backgroundColor: Colors.green,
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
    super.dispose();
  }
}