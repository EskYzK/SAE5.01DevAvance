import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: "gs://schoolobjectdetector.firebasestorage.app"
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> shareDetection({
    required File imageFile,
    required String label,
    required double confidence,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception("Vous devez être connecté pour partager.");
      }

      DocumentSnapshot userDoc = await _firestore.collection('User').doc(user.uid).get();

      String pseudo = 'Anonyme';
      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('pseudo')) {
          pseudo = data['pseudo'];
        }
      }

      String fileName = "detect_${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = _storage.ref().child("uploads").child(fileName);

      UploadTask task = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      task.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      }, onError: (e) {
      });

      await task;

      String imageUrl = await ref.getDownloadURL();

      await _firestore.collection('detections').add({
        'imageUrl': imageUrl,
        'label': label,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userPseudo': pseudo,
      });
      
      
    } on FirebaseException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}