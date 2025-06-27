import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

/// Service de secours pour les images en cas de problème avec Firebase Storage
class FallbackImageService {
  static final FallbackImageService _instance = FallbackImageService._internal();
  factory FallbackImageService() => _instance;
  FallbackImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Sélectionne une image depuis la galerie
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Erreur sélection image galerie: $e');
      return null;
    }
  }

  /// Sélectionne une image depuis l'appareil photo
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Erreur prise photo: $e');
      return null;
    }
  }

  /// Convertit l'image en Base64 (solution temporaire)
  Future<String?> convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Créer une URL data URI
      final mimeType = _getMimeType(imageFile.path);
      final dataUri = 'data:$mimeType;base64,$base64String';
      
      print('✅ Image convertie en Base64 (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
      return dataUri;
    } catch (e) {
      print('❌ Erreur conversion Base64: $e');
      return null;
    }
  }

  /// Détermine le type MIME d'un fichier
  String _getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Vérifie si une image est valide
  bool isValidImage(File imageFile) {
    try {
      final String extension = imageFile.path.toLowerCase().split('.').last;
      final List<String> validExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      
      if (!validExtensions.contains(extension)) {
        return false;
      }

      // Vérifier la taille du fichier (max 5MB)
      final int fileSizeInMB = imageFile.lengthSync() ~/ (1024 * 1024);
      if (fileSizeInMB > 5) {
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Erreur validation image: $e');
      return false;
    }
  }

  /// Obtient la taille d'un fichier image en MB
  double getImageSizeInMB(File imageFile) {
    try {
      final int fileSizeInBytes = imageFile.lengthSync();
      return fileSizeInBytes / (1024 * 1024);
    } catch (e) {
      print('❌ Erreur calcul taille image: $e');
      return 0.0;
    }
  }

  /// Génère une URL placeholder avec gravatar ou une image par défaut
  String getPlaceholderImageUrl(String userId) {
    // Utiliser une combinaison de l'ID utilisateur pour générer une image unique
    final hash = userId.hashCode.abs();
    
    // URLs d'avatars par défaut (services gratuits)
    final List<String> avatarServices = [
      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userId)}&background=4F46E5&color=fff&size=200',
      'https://robohash.org/$hash?set=set4&size=200x200',
      'https://api.dicebear.com/7.x/avataaars/svg?seed=$userId',
    ];
    
    // Choisir un service basé sur le hash de l'ID
    final serviceIndex = hash % avatarServices.length;
    return avatarServices[serviceIndex];
  }
}