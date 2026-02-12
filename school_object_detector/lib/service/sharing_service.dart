import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: "gs://schoolobjectdetector.firebasestorage.app"
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> shareDetection({
    required File imageFile,
    required String label,
    required String confidence,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception("Vous devez être connecté pour partager.");
      }

      DocumentSnapshot userDoc = await _firestore.collection('User').doc(user.uid).get();

      String pseudo = 'Anonyme';
      String? photoProfileUrl = user.photoURL;

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          if (data.containsKey('pseudo')) {
            pseudo = data['pseudo'];
          }
          if (photoProfileUrl == null && data.containsKey('photoUrl')) {
             photoProfileUrl = data['photoUrl'];
          }
        }
      }

      String fileName = "detect_${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = _storage.ref().child("uploads").child(fileName);

      UploadTask task = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      await task;

      String imageUrl = await ref.getDownloadURL();

      await _firestore.collection('detections').add({
        'imageUrl': imageUrl,
        'label': label,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userPseudo': pseudo,
        'userPhotoUrl': photoProfileUrl, 
      });
      
    } on FirebaseException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> uploadToDataset({
  required File imageFile,
  required File annotationFile,
  required String label,
}) async {
  try {
    User? user = _auth.currentUser;
    // On peut autoriser l'envoi même sans compte si vous voulez, 
    // mais il est préférable d'avoir un identifiant.
    String uid = user?.uid ?? "anonymous";
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // 1. Upload de l'image
    String imgFileName = "train_${uid}_$timestamp.jpg";
    Reference imgRef = _storage.ref().child("annotated_pictures").child(imgFileName);
    await imgRef.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

    // 2. Upload de l'annotation (.txt)
    String txtFileName = "train_${uid}_$timestamp.txt";
    Reference txtRef = _storage.ref().child("annotated_pictures").child(txtFileName);
    await txtRef.putFile(annotationFile, SettableMetadata(contentType: 'text/plain'));

    // Optionnel: Garder une trace dans Firestore pour statistiques
    await _firestore.collection('dataset_contributions').add({
      'userId': uid,
      'label': label,
      'timestamp': FieldValue.serverTimestamp(),
      'imagePath': imgRef.fullPath,
    });
  } catch (e) {
    debugPrint("Erreur upload dataset: $e");
    rethrow;
  }
}
}