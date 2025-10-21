import 'dart:io';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  final List<String> images;

  const HistoryScreen({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des images"),
        backgroundColor: Colors.deepPurple,
      ),
      body: images.isEmpty
          ? const Center(
              child: Text(
                "Aucune image enregistrée",
                style: TextStyle(fontSize: 18),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // Affiche l'image en plein écran
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImage(imagePath: images[index]),
                      ),
                    );
                  },
                  child: Hero(
                    tag: images[index],
                    child: Image.file(
                      File(images[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;

  const FullScreenImage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: imagePath,
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    );
  }
}