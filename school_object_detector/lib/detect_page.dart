 import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class DetectPage extends StatefulWidget {
  const DetectPage({Key? key}) : super(key: key);

  @override
  State<DetectPage> createState() => _DetectPageState();
}

class _DetectPageState extends State<DetectPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _resultText = "";

  // ⚙️ Ton IP locale (celle de ton Flask)
  final String apiUrl = "http://172.20.10.9:5001/detect";

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _resultText = "Analyse en cours...";
      });

      await _sendToServer(_image!);
    }
  }

  Future<void> _sendToServer(File image) async {
    try {
      // Convertir l’image en base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Debug: log taille et url
      debugPrint('Envoi de l\'image vers $apiUrl (${bytes.length} octets)');

      // Envoyer au serveur Flask
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"image": base64Image}),
      );

      // Debug: log réponse
      debugPrint('Réponse serveur: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          if (data["detections"] != null && data["detections"].isNotEmpty) {
            _resultText = data["detections"]
                .map((d) => "${d['label']} (${d['confidence']})")
                .join("\n");
          } else {
            _resultText = "Aucun objet détecté.";
          }
        });
      } else {
        setState(() {
          _resultText =
              "Erreur serveur : ${response.statusCode} ${response.reasonPhrase}\n${response.body}";
        });
      }
    } catch (e) {
      // Log complet de l'exception pour Xcode/console
      debugPrint('Erreur lors de l\'envoi: $e');
      setState(() {
        _resultText = "Erreur : $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détection d’objets scolaires"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null
                ? Image.file(_image!, height: 300)
                : const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera),
              label: const Text("Prendre une photo"),
            ),
            const SizedBox(height: 30),
            Text(
              _resultText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
