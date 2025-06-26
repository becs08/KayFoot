import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/terrain.dart';
import '../../models/user.dart';
import '../../models/avis.dart';
import '../../services/avis_service.dart';
import '../../services/auth_service.dart';

class DonnerAvisScreen extends StatefulWidget {
  final Terrain terrain;

  const DonnerAvisScreen({super.key, required this.terrain});

  @override
  State<DonnerAvisScreen> createState() => _DonnerAvisScreenState();
}

class _DonnerAvisScreenState extends State<DonnerAvisScreen> {
  final TextEditingController _commentaireController = TextEditingController();
  final AvisService _avisService = AvisService();
  final AuthService _authService = AuthService();
  
  int _noteSelectionnee = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  Avis? _avisExistant;

  @override
  void initState() {
    super.initState();
    _chargerAvisExistant();
  }

  Future<void> _chargerAvisExistant() async {
    final user = _authService.currentUser;
    if (user != null) {
      final avis = await _avisService.getAvisUtilisateur(widget.terrain.id, user.id);
      if (avis != null) {
        setState(() {
          _avisExistant = avis;
          _noteSelectionnee = avis.note;
          _commentaireController.text = avis.commentaire;
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sauvegarderAvis() async {
    if (_noteSelectionnee == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une note')),
      );
      return;
    }

    if (_commentaireController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez écrire un commentaire')),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await _avisService.ajouterAvis(
        terrainId: widget.terrain.id,
        utilisateur: user,
        note: _noteSelectionnee,
        commentaire: _commentaireController.text.trim(),
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_avisExistant != null 
                ? 'Avis mis à jour avec succès !' 
                : 'Avis ajouté avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Retourner true pour indiquer qu'un avis a été ajouté
      } else {
        throw Exception('Erreur lors de la sauvegarde');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_avisExistant != null ? 'Modifier mon avis' : 'Donner un avis'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info terrain
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: widget.terrain.photos.isNotEmpty
                                  ? Image.network(
                                      widget.terrain.photos.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.sports_soccer),
                                    )
                                  : const Icon(Icons.sports_soccer),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.terrain.nom,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.terrain.adresse,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sélection note
                  const Text(
                    'Votre note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final noteIndex = index + 1;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _noteSelectionnee = noteIndex;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            noteIndex <= _noteSelectionnee
                                ? Icons.star
                                : Icons.star_border,
                            color: AppConstants.primaryColor,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  if (_noteSelectionnee > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          _getTextePourNote(_noteSelectionnee),
                          style: TextStyle(
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Commentaire
                  const Text(
                    'Votre commentaire',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _commentaireController,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Partagez votre expérience sur ce terrain...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Bouton sauvegarder
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _sauvegarderAvis,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_avisExistant != null 
                              ? 'Modifier mon avis' 
                              : 'Publier mon avis'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getTextePourNote(int note) {
    switch (note) {
      case 1:
        return 'Très décevant';
      case 2:
        return 'Pas terrible';
      case 3:
        return 'Correct';
      case 4:
        return 'Bien';
      case 5:
        return 'Excellent !';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _commentaireController.dispose();
    super.dispose();
  }
}