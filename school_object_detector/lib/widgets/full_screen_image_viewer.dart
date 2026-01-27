import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String? heroTag;

  const FullScreenImageViewer({
    super.key, 
    required this.imagePath, 
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUrl = imagePath.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: heroTag ?? imagePath,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: isUrl
                ? Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, color: Colors.white, size: 50),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, color: Colors.white, size: 50),
                  ),
          ),
        ),
      ),
    );
  }
}