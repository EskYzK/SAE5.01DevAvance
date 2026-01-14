import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;

  final _pseudoController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPseudo();
  }

  void _loadCurrentPseudo() async {
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('User').doc(user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _pseudoController.text = doc.get('pseudo') ?? "";
        });
      }
    }
  }

  Future<void> _updatePseudo() async {
    if (_pseudoController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pseudo trop court (3 min)")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePseudo(user!.uid, _pseudoController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Pseudo mis à jour !"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le nouveau mot de passe est trop court (6 min)")));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Les nouveaux mots de passe ne correspondent pas")));
      return;
    }
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez entrer votre mot de passe actuel")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Mot de passe modifié !"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier le profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 20),

            const Text("Changer de nom d'utilisateur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 15),
            TextField(
              controller: _pseudoController,
              decoration: const InputDecoration(
                labelText: "Nouveau pseudo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePseudo,
                child: const Text("Enregistrer le nouveau pseudo"),
              ),
            ),

            const Divider(height: 60, thickness: 2),

            const Text("Changer de mot de passe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 15),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Mot de passe ACTUEL",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_open),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Nouveau mot de passe",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirmer le nouveau mot de passe",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.check),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                ),
                onPressed: _isLoading ? null : _updatePassword,
                child: const Text("Mettre à jour le mot de passe"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}