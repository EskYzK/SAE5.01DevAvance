import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String pseudo,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _createUserData(userCredential.user!, pseudo);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createUserData(User user, String pseudo) async {
    await _firestore.collection('User').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'pseudo': pseudo,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'user',
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}