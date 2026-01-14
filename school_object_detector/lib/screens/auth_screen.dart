import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/auth_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLogin = true;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          pseudo: _pseudoController.text.trim(),
        );
      }
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLogin ? "Bon retour !" : "Bienvenue !"), backgroundColor: Colors.green),
        );
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
  
  Future<void> _updatePhoto(User user) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mise à jour de la photo...")),
          );
        }

        await _authService.updateProfilePicture(user.uid, File(image.path));

        if (mounted) {
          setState(() {
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Photo de profil mise à jour !"), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _buildProfileView(snapshot.data!);
        }
        return _buildAuthForm();
      },
    );
  }

  Widget _buildProfileView(User user) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon Profil")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('User').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final String? photoUrl = data?['photoUrl'];
                final String pseudo = data?['pseudo'] ?? "Utilisateur";

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => _updatePhoto(user),
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                              image: photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              border: Border.all(color: Colors.deepPurple, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: photoUrl == null
                                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.deepPurple,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      pseudo,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user.email ?? "",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/edit_profile');
              },
              icon: const Icon(Icons.edit),
              label: const Text("Modifier mes informations"),
            ),
            
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () async {
                await _authService.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text("Se déconnecter"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

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
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.contains('@') ? null : "Email invalide",
              ),
              const SizedBox(height: 15),

              if (!_isLogin) ...[
                TextFormField(
                  controller: _pseudoController,
                  decoration: const InputDecoration(labelText: "Pseudo", prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.length < 3 ? "Pseudo trop court" : null,
                ),
                const SizedBox(height: 15),
              ],

              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Mot de passe", prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                validator: (v) => v!.length < 6 ? "Minimum 6 caractères" : null,
              ),
              const SizedBox(height: 30),

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