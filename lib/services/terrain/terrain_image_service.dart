import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class TerrainImageService {
  static final TerrainImageService _instance = TerrainImageService._internal();
  factory TerrainImageService() => _instance;
  TerrainImageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// 📸 Sélectionner une image depuis la galerie ou l'appareil photo
  Future<ImagePickerResult> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      print('📸 Sélection d\'image depuis ${source == ImageSource.camera ? 'appareil photo' : 'galerie'}');

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        return ImagePickerResult(
          success: false,
          message: 'Aucune image sélectionnée',
        );
      }

      print('✅ Image sélectionnée: ${image.name}');
      return ImagePickerResult(
        success: true,
        message: 'Image sélectionnée',
        imagePath: image.path,
      );

    } catch (e) {
      print('❌ Erreur pickImage: $e');
      return ImagePickerResult(
        success: false,
        message: 'Erreur lors de la sélection: ${e.toString()}',
      );
    }
  }

  /// ☁️ Upload une image vers Firebase Storage
  Future<ImageUploadResult> uploadTerrainImage({
    required String terrainId,
    required String imagePath,
    Function(double)? onProgress,
  }) async {
    try {
      print('☁️ Upload image terrain: $terrainId');

      final file = File(imagePath);
      if (!await file.exists()) {
        return ImageUploadResult(
          success: false,
          message: 'Le fichier image n\'existe pas',
        );
      }

      // Générer un nom de fichier unique
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imagePath)}';
      final ref = _storage.ref().child('terrains/$terrainId/$fileName');

      print('📤 Upload vers: terrains/$terrainId/$fileName');

      // Upload avec suivi de progression
      final uploadTask = ref.putFile(file);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Upload terminé: $downloadUrl');

      return ImageUploadResult(
        success: true,
        message: 'Image uploadée avec succès',
        downloadUrl: downloadUrl,
        fileName: fileName,
      );

    } catch (e) {
      print('❌ Erreur uploadTerrainImage: $e');
      return ImageUploadResult(
        success: false,
        message: 'Erreur lors de l\'upload: ${e.toString()}',
      );
    }
  }

  /// 🗑️ Supprimer une image du terrain
  Future<bool> deleteTerrainImage({
    required String terrainId,
    required String imageUrl,
  }) async {
    try {
      print('🗑️ Suppression image: $imageUrl');

      // Extraire le nom du fichier depuis l'URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      print('✅ Image supprimée: ${ref.name}');
      return true;

    } catch (e) {
      print('❌ Erreur deleteTerrainImage: $e');
      return false;
    }
  }

  /// 📷 Sélectionner et uploader plusieurs images
  Future<MultiImageUploadResult> pickAndUploadMultipleImages({
    required String terrainId,
    int maxImages = 5,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      print('📷 Sélection multiple d\'images (max: $maxImages)');

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isEmpty) {
        return MultiImageUploadResult(
          success: false,
          message: 'Aucune image sélectionnée',
          uploadedUrls: [],
        );
      }

      // Limiter le nombre d'images
      final imagesToUpload = images.take(maxImages).toList();
      print('📸 ${imagesToUpload.length} images à uploader');

      final List<String> uploadedUrls = [];
      final List<String> errors = [];

      for (int i = 0; i < imagesToUpload.length; i++) {
        final image = imagesToUpload[i];
        onProgress?.call(i + 1, imagesToUpload.length);

        final result = await uploadTerrainImage(
          terrainId: terrainId,
          imagePath: image.path,
        );

        if (result.success && result.downloadUrl != null) {
          uploadedUrls.add(result.downloadUrl!);
          print('✅ Image ${i + 1}/${imagesToUpload.length} uploadée');
        } else {
          errors.add('Image ${i + 1}: ${result.message}');
          print('❌ Erreur image ${i + 1}: ${result.message}');
        }
      }

      return MultiImageUploadResult(
        success: uploadedUrls.isNotEmpty,
        message: uploadedUrls.isNotEmpty
            ? '${uploadedUrls.length} image(s) uploadée(s)'
            : 'Aucune image n\'a pu être uploadée',
        uploadedUrls: uploadedUrls,
        errors: errors,
      );

    } catch (e) {
      print('❌ Erreur pickAndUploadMultipleImages: $e');
      return MultiImageUploadResult(
        success: false,
        message: 'Erreur: ${e.toString()}',
        uploadedUrls: [],
      );
    }
  }

  /// 🔄 Compresser et redimensionner une image
  Future<String?> compressImage(String imagePath) async {
    try {
      // Cette fonctionnalité peut être étendue avec des packages comme image_compression
      // Pour l'instant, on retourne le chemin original
      return imagePath;
    } catch (e) {
      print('❌ Erreur compressImage: $e');
      return null;
    }
  }

  /// 📋 Obtenir la miniature d'une liste d'images
  String? getThumbnailUrl(List<String> photos) {
    if (photos.isEmpty) return null;
    return photos.first;
  }

  /// 🖼️ Valider le format et la taille d'une image
  Future<bool> validateImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return false;

      // Vérifier la taille (max 10MB)
      final fileSizeInBytes = await file.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > 10) {
        print('⚠️ Image trop grande: ${fileSizeInMB.toStringAsFixed(1)}MB');
        return false;
      }

      // Vérifier l'extension
      final extension = path.extension(imagePath).toLowerCase();
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

      if (!allowedExtensions.contains(extension)) {
        print('⚠️ Format non supporté: $extension');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Erreur validateImage: $e');
      return false;
    }
  }
}

// 📊 Classes de résultat
class ImagePickerResult {
  final bool success;
  final String message;
  final String? imagePath;

  ImagePickerResult({
    required this.success,
    required this.message,
    this.imagePath,
  });
}

class ImageUploadResult {
  final bool success;
  final String message;
  final String? downloadUrl;
  final String? fileName;

  ImageUploadResult({
    required this.success,
    required this.message,
    this.downloadUrl,
    this.fileName,
  });
}

class MultiImageUploadResult {
  final bool success;
  final String message;
  final List<String> uploadedUrls;
  final List<String> errors;

  MultiImageUploadResult({
    required this.success,
    required this.message,
    required this.uploadedUrls,
    this.errors = const [],
  });
}