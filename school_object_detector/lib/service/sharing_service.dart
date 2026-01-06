import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // On enlève FirebaseStorage pour l'instant
  Future<void> shareDetection({
    required File imageFile,
    required String label,
    required double confidence,
  }) async {
    try {
      // Au lieu d'envoyer l'image, on met une image par défaut ou vide
      String fakeImageUrl = "https://via.placeholder.com/150"; 

      // On enregistre seulement le texte dans Firestore (c'est gratuit sans CB)
      await _firestore.collection('detections').add({
        'imageUrl': fakeImageUrl, 
        'label': label,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print("Partage (texte uniquement) réussi !");
    } catch (e) {
      print("Erreur : $e");
      rethrow;
    }
  }
}