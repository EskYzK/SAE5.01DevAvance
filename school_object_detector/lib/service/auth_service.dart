import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Connexion
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Inscription + Création de la collection User (VERSION BLINDÉE)
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String pseudo,
  }) async {
    UserCredential? userCredential;

    try {
      // 1. On essaie de créer le compte
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // C'EST ICI LE FIX : 
      // Si on a l'erreur "Pigeon" ou autre bug bizarre, mais que l'utilisateur est quand même créé :
      if (_auth.currentUser != null) {
        print("Bug détecté mais utilisateur créé. On force la création du profil.");
        // On continue comme si de rien n'était
      } else {
        // Sinon, c'est une vraie erreur (mdp trop court, etc.), on la relance
        rethrow;
      }
    }

    // 2. Si on arrive ici, c'est que l'utilisateur existe (normalement ou via le rattrapage d'erreur)
    if (_auth.currentUser != null) {
      await _createUserData(_auth.currentUser!, pseudo);
    }

    return userCredential;
  }

  // Fonction privée pour créer le document User
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

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
}