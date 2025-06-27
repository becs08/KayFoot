import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  /// Upload une image vers Firebase Storage
  Future<String?> uploadImage(File imageFile, String userId) async {
    try {
      // Vérifier que Firebase Storage est disponible
      if (!await _isStorageAvailable()) {
        print('❌ Firebase Storage non disponible');
        return null;
      }

      // Générer un nom unique pour l'image
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final String filePath = 'profile_photos/$userId/$fileName';

      print('📤 Upload vers: $filePath');

      // Référence vers le fichier dans Firebase Storage
      final Reference ref = _storage.ref().child(filePath);

      // Metadata pour optimiser l'upload
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=300',
      );

      // Upload du fichier
      final UploadTask uploadTask = ref.putFile(imageFile, metadata);
      
      // Écouter les progrès de l'upload
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Progrès upload: ${progress.toStringAsFixed(1)}%');
      });
      
      // Attendre la fin de l'upload
      final TaskSnapshot snapshot = await uploadTask;
      
      // Obtenir l'URL de téléchargement
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploadée avec succès: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('❌ Erreur Firebase upload: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ Erreur upload image: $e');
      return null;
    }
  }

  /// Vérifie si Firebase Storage est disponible
  Future<bool> _isStorageAvailable() async {
    try {
      // Test simple : créer une référence et vérifier si le service répond
      final ref = _storage.ref().child('test/connection_test.txt');
      
      // Essayer de lister les objets dans le bucket (opération moins intrusive)
      await _storage.ref().child('test').listAll();
      
      return true;
    } on FirebaseException catch (e) {
      print('❌ Firebase Storage non accessible: ${e.code} - ${e.message}');
      if (e.code == 'storage/bucket-not-found') {
        print('💡 Conseil: Vérifiez la configuration du bucket Firebase Storage');
      }
      return false;
    } catch (e) {
      print('❌ Firebase Storage non accessible: $e');
      return false;
    }
  }

  /// Upload une image de profil avec suppression de l'ancienne
  Future<String?> uploadProfileImage(File imageFile, String userId, {String? oldImageUrl}) async {
    try {
      // Upload la nouvelle image d'abord
      final String? newImageUrl = await uploadImage(imageFile, userId);
      
      if (newImageUrl == null) {
        return null;
      }

      // Supprimer l'ancienne image seulement si l'upload a réussi
      // et si l'ancienne image existe vraiment
      if (oldImageUrl != null && 
          oldImageUrl.isNotEmpty && 
          oldImageUrl.contains('firebase') &&
          oldImageUrl != newImageUrl) {
        print('🗑️ Suppression de l\'ancienne image...');
        final deleted = await deleteImage(oldImageUrl);
        if (deleted) {
          print('✅ Ancienne image supprimée');
        } else {
          print('⚠️ Impossible de supprimer l\'ancienne image (pas grave)');
        }
      }

      return newImageUrl;
    } catch (e) {
      print('❌ Erreur upload photo de profil: $e');
      return null;
    }
  }

  /// Supprime une image de Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      if (!imageUrl.contains('firebase')) {
        print('⚠️ URL non Firebase, ignorer la suppression');
        return false;
      }

      // Extraire le chemin depuis l'URL Firebase
      final Uri uri = Uri.parse(imageUrl);
      
      // Pour les URLs Firebase Storage, le chemin est dans le query parameter 'o'
      String? filePath;
      
      if (uri.pathSegments.isNotEmpty) {
        // Essayer d'extraire depuis les pathSegments pour les URLs de type:
        // https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Ffile.jpg
        final segments = uri.pathSegments;
        if (segments.length >= 4 && segments[2] == 'o') {
          filePath = Uri.decodeComponent(segments[3]);
        }
      }
      
      if (filePath == null) {
        print('❌ Impossible d\'extraire le chemin de l\'URL: $imageUrl');
        return false;
      }
      
      print('🗑️ Tentative de suppression: $filePath');
      
      // Supprimer le fichier
      final Reference ref = _storage.ref().child(filePath);
      await ref.delete();
      
      print('✅ Image supprimée avec succès: $filePath');
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        print('⚠️ Image déjà supprimée ou inexistante: ${e.message}');
        return true; // Considérer comme un succès si l'objet n'existe pas
      } else {
        print('❌ Erreur Firebase suppression: ${e.code} - ${e.message}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur suppression image: $e');
      return false;
    }
  }

  /// Upload multiple images (pour les terrains par exemple)
  Future<List<String>> uploadMultipleImages(List<File> imageFiles, String category, String id) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFiles[i].path)}';
        final String filePath = '$category/$id/$fileName';

        final Reference ref = _storage.ref().child(filePath);

        final SettableMetadata metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=300',
        );

        final UploadTask uploadTask = ref.putFile(imageFiles[i], metadata);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        uploadedUrls.add(downloadUrl);
        print('✅ Image ${i + 1}/${imageFiles.length} uploadée: $downloadUrl');
      } catch (e) {
        print('❌ Erreur upload image ${i + 1}: $e');
      }
    }

    return uploadedUrls;
  }

  /// Vérifie si une image est valide
  bool isValidImage(File imageFile) {
    try {
      final String extension = path.extension(imageFile.path).toLowerCase();
      final List<String> validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

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
}
