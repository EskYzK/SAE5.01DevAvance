import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HistoryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
      bucket: "gs://schoolobjectdetector.firebasestorage.app"
  );

  Future<void> saveDetection({
    required File imageFile,
    required String label,
    required String confidence,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception("Vous devez être connecté.");

    try {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child("user_history").child(user.uid).child("$timestamp.jpg");
      
      await ref.putFile(imageFile);
      String imageUrl = await ref.getDownloadURL();

      await _firestore
          .collection('User')
          .doc(user.uid)
          .collection('history')
          .add({
        'imageUrl': imageUrl,
        'label': label,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("Erreur sauvegarde historique: $e");
      rethrow;
    }
  }

  Future<void> deleteDetection(String docId, String imageUrl) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _storage.refFromURL(imageUrl).delete();
      
      await _firestore
          .collection('User')
          .doc(user.uid)
          .collection('history')
          .doc(docId)
          .delete();
    } catch (e) {
      print("Erreur suppression: $e");
    }
  }
}