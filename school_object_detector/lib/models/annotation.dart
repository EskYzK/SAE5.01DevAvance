import 'dart:ui'; // Nécessaire pour utiliser la classe Rect

class Annotation {
  final Rect rect;      // La position du rectangle (en pixels écran)
  final String label;   // Le nom de la classe (ex: 'gomme')
  final int classId;    // L'identifiant numérique pour YOLO (ex: 0)

  Annotation({
    required this.rect,
    required this.label,
    required this.classId,
  });
}