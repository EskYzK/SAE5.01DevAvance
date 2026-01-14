import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
      bucket: "gs://schoolobjectdetector.firebasestorage.app"
  );

  User? get currentUser => _auth.currentUser;

  // Connexion
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String pseudo,
  }) async {
    UserCredential? userCredential;

    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (_auth.currentUser != null) {
        print("Bug détecté mais utilisateur créé. On force la création du profil.");
      } else {
        rethrow;
      }
    }

    if (_auth.currentUser != null) {
      await _createUserData(_auth.currentUser!, pseudo);
    }

    return userCredential;
  }

  Future<void> _createUserData(User user, String pseudo) async {
    try {
      await _firestore.collection('User').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'pseudo': pseudo,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
      });
      print("✅ Profil User créé pour le pseudo : $pseudo");
    } catch (e) {
      print("❌ Erreur lors de la création du profil Firestore : $e");
      throw Exception("Compte créé mais impossible de sauvegarder le profil.");
    }
  }

  Future<void> updateProfilePicture(String uid, File imageFile) async {
    try {
      Reference ref = _storage.ref().child("user_profiles").child("$uid.jpg");

      await ref.putFile(imageFile);

      String photoUrl = await ref.getDownloadURL();

      await _firestore.collection('User').doc(uid).update({
        'photoUrl': photoUrl,
      });
      
    } catch (e) {
      print("Erreur upload profil: $e");
      throw Exception("Impossible de mettre à jour la photo.");
    }
  }

  Future<void> updatePseudo(String uid, String newPseudo) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'pseudo': newPseudo,
      });
    } catch (e) {
      throw Exception("Impossible de mettre à jour le pseudo.");
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception("Utilisateur introuvable");

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception("L'ancien mot de passe est incorrect.");
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("Aucun compte ne correspond à cet email.");
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}