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
      print("🚀 1. Démarrage du service de partage");
      print("   - Fichier : ${imageFile.path}");
      print("   - Taille : ${await imageFile.length()} octets");

      String fileName = "detect_${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = _storage.ref().child("uploads").child(fileName);

      print("📂 2. Référence créée : uploads/$fileName");

      UploadTask task = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      task.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print("⏳ Upload en cours... ${progress.toStringAsFixed(1)}%");
      }, onError: (e) {
        print("❌ Erreur pendant le flux d'upload : $e");
      });

      await task;
      print("✅ 3. Upload terminé avec succès !");

      String imageUrl = await ref.getDownloadURL();
      print("🔗 4. URL obtenue : $imageUrl");

      await _firestore.collection('detections').add({
        'imageUrl': imageUrl,
        'label': label,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print("🎉 5. Tout est fini !");
      
    } on FirebaseException catch (e) {
      print("❌ ERREUR FIREBASE : [${e.code}] - ${e.message}");
      rethrow;
    } catch (e) {
      print("❌ ERREUR GÉNÉRALE : $e");
      rethrow;
    }
  }
}