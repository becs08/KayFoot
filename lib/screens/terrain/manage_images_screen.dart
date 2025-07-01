import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../models/terrain.dart';
import '../../services/terrain/terrain_service.dart';
import '../../services/terrain/terrain_image_service.dart';

class ManageTerrainImagesScreen extends StatefulWidget {
  final Terrain terrain;

  const ManageTerrainImagesScreen({super.key, required this.terrain});

  @override
  _ManageTerrainImagesScreenState createState() => _ManageTerrainImagesScreenState();
}

class _ManageTerrainImagesScreenState extends State<ManageTerrainImagesScreen> {
  final TerrainImageService _imageService = TerrainImageService();
  final TerrainService _terrainService = TerrainService();

  List<String> _photos = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.terrain.photos);
  }

  /// 📷 Ajouter une nouvelle photo
  Future<void> _addPhoto() async {
    final result = await _imageService.pickImage(source: ImageSource.gallery);

    if (result.success && result.imagePath != null) {
      _uploadImage(result.imagePath!);
    } else if (result.message.isNotEmpty) {
      _showError(result.message);
    }
  }

  /// 📸 Prendre une photo avec l'appareil
  Future<void> _takePhoto() async {
    final result = await _imageService.pickImage(source: ImageSource.camera);

    if (result.success && result.imagePath != null) {
      _uploadImage(result.imagePath!);
    } else if (result.message.isNotEmpty) {
      _showError(result.message);
    }
  }

  /// ☁️ Upload une image
  Future<void> _uploadImage(String imagePath) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final result = await _imageService.uploadTerrainImage(
        terrainId: widget.terrain.id,
        imagePath: imagePath,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (result.success && result.downloadUrl != null) {
        setState(() {
          _photos.add(result.downloadUrl!);
        });
        await _updateTerrainPhotos();
        _showSuccess('Photo ajoutée avec succès');
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Erreur lors de l\'upload: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  /// 🗑️ Supprimer une photo
  Future<void> _deletePhoto(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la photo'),
        content: Text('Êtes-vous sûr de vouloir supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final imageUrl = _photos[index];
        final deleted = await _imageService.deleteTerrainImage(
          terrainId: widget.terrain.id,
          imageUrl: imageUrl,
        );

        if (deleted) {
          setState(() {
            _photos.removeAt(index);
          });
          await _updateTerrainPhotos();
          _showSuccess('Photo supprimée');
        } else {
          _showError('Erreur lors de la suppression');
        }
      } catch (e) {
        _showError('Erreur: ${e.toString()}');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 🔄 Mettre à jour les photos du terrain
  Future<void> _updateTerrainPhotos() async {
    final updatedTerrain = widget.terrain.copyWith(photos: _photos);
    await _terrainService.updateTerrain(updatedTerrain);
  }

  /// 📷 Ajouter plusieurs photos
  Future<void> _addMultiplePhotos() async {
    if (_photos.length >= 10) {
      _showError('Maximum 10 photos autorisées');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final remainingSlots = 10 - _photos.length;
      final result = await _imageService.pickAndUploadMultipleImages(
        terrainId: widget.terrain.id,
        maxImages: remainingSlots,
        onProgress: (current, total) {
          setState(() {
            _uploadProgress = current / total;
          });
        },
      );

      if (result.success && result.uploadedUrls.isNotEmpty) {
        setState(() {
          _photos.addAll(result.uploadedUrls);
        });
        await _updateTerrainPhotos();
        _showSuccess('${result.uploadedUrls.length} photo(s) ajoutée(s)');
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
      ),
    );
  }

  void _showImageOptions() {
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
              'Ajouter des photos',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 18),
            ),
            SizedBox(height: AppConstants.largePadding),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Appareil photo'),
                  ),
                ),
                SizedBox(width: AppConstants.mediumPadding),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addPhoto,
                    icon: Icon(Icons.photo_library),
                    label: Text('Galerie'),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppConstants.mediumPadding),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addMultiplePhotos,
                icon: Icon(Icons.add_photo_alternate),
                label: Text('Plusieurs photos'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gérer les photos'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_a_photo),
            onPressed: _photos.length < 10 ? _showImageOptions : null,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress bar pendant l'upload
                if (_isUploading)
                  Container(
                    padding: EdgeInsets.all(AppConstants.mediumPadding),
                    child: Column(
                      children: [
                        Text('Upload en cours...'),
                        SizedBox(height: 8),
                        LinearProgressIndicator(value: _uploadProgress),
                        SizedBox(height: 8),
                        Text('${(_uploadProgress * 100).toInt()}%'),
                      ],
                    ),
                  ),

                // Informations
                Container(
                  padding: EdgeInsets.all(AppConstants.mediumPadding),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_photos.length}/10 photos • La première photo sera utilisée comme miniature',
                          style: AppConstants.bodyStyle.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Grid des photos
                Expanded(
                  child: _photos.isEmpty
                      ? _buildEmptyState()
                      : _buildPhotosGrid(),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: AppConstants.mediumPadding),
          Text(
            'Aucune photo',
            style: AppConstants.subHeadingStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: AppConstants.smallPadding),
          Text(
            'Ajoutez des photos pour rendre votre terrain plus attractif',
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppConstants.largePadding),
          ElevatedButton.icon(
            onPressed: _showImageOptions,
            icon: Icon(Icons.add_a_photo),
            label: Text('Ajouter des photos'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppConstants.mediumPadding,
        mainAxisSpacing: AppConstants.mediumPadding,
        childAspectRatio: 1.0,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return _buildPhotoCard(index);
      },
    );
  }

  Widget _buildPhotoCard(int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            child: CachedNetworkImage(
              imageUrl: _photos[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade300,
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Badge "Miniature" pour la première photo
        if (index == 0)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Miniature',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // Bouton supprimer
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _deletePhoto(index),
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}