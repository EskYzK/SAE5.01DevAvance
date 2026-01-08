import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: "gs://schoolobjectdetector.firebasestorage.app"
  );

  Future<void> shareDetection({
    required File imageFile,
    required String label,
    required double confidence,
  }) async {
    try {
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
      });
      
      
    } on FirebaseException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}