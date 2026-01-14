import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/auth_service.dart'; // Assurez-vous que le chemin est correct

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLogin = true; // Pour basculer entre Connexion et Inscription
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();

  // Fonction pour soumettre le formulaire
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Connexion
        await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        // Inscription
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          pseudo: _pseudoController.text.trim(),
        );
      }
      // Si tout se passe bien, on peut fermer la page ou afficher un succès
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLogin ? "Bon retour !" : "Bienvenue !"), backgroundColor: Colors.green),
        );
         // Optionnel : Navigator.pop(context); pour revenir à l'accueil directement
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Une erreur est survenue.";
        if (e.code == 'user-not-found') message = "Utilisateur introuvable.";
        if (e.code == 'wrong-password') message = "Mot de passe incorrect.";
        if (e.code == 'email-already-in-use') message = "Cet email est déjà utilisé.";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // On écoute l'état de l'utilisateur (Connecté ou non)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si l'utilisateur est connecté, on affiche son profil
        if (snapshot.hasData) {
          return _buildProfileView(snapshot.data!);
        }
        // Sinon, on affiche le formulaire d'auth
        return _buildAuthForm();
      },
    );
  }

  // VUE PROFIL (Connecté)
  Widget _buildProfileView(User user) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon Profil")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 20),
            // On récupère le pseudo depuis Firestore
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('User').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                String pseudo = "Utilisateur";
                if (snapshot.hasData && snapshot.data!.exists) {
                  pseudo = snapshot.data!.get('pseudo') ?? "Utilisateur";
                }
                return Text(pseudo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
              },
            ),
            const SizedBox(height: 10),
            Text(user.email ?? "", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                await _authService.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text("Se déconnecter"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }

  // VUE FORMULAIRE (Non connecté)
  Widget _buildAuthForm() {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? "Connexion" : "Inscription")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              
              // Champ Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.contains('@') ? null : "Email invalide",
              ),
              const SizedBox(height: 15),

              // Champ Pseudo (Seulement si Inscription)
              if (!_isLogin) ...[
                TextFormField(
                  controller: _pseudoController,
                  decoration: const InputDecoration(labelText: "Pseudo", prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.length < 3 ? "Pseudo trop court" : null,
                ),
                const SizedBox(height: 15),
              ],

              // Champ Mot de passe
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Mot de passe", prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                validator: (v) => v!.length < 6 ? "Minimum 6 caractères" : null,
              ),
              const SizedBox(height: 30),

              // Bouton Valider
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isLogin ? "SE CONNECTER" : "S'INSCRIRE"),
                ),
              
              const SizedBox(height: 20),

              // Bouton Toggle (Basculer Connexion / Inscription)
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin 
                  ? "Pas encore de compte ? Créer un compte" 
                  : "Déjà un compte ? Se connecter"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}