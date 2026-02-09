import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/annotation.dart';

class AnnotationEditor extends StatefulWidget {
  final XFile imageFile;
  final List<String> classes;
  
  // Callback quand l'utilisateur valide. 
  // On renvoie les annotations ET la taille de l'image affichée pour faire le calcul YOLO plus tard.
  final void Function(List<Annotation> annotations, Size displaySize) onValidated;

  const AnnotationEditor({
    super.key,
    required this.imageFile,
    required this.classes,
    required this.onValidated,
  });

  @override
  State<AnnotationEditor> createState() => _AnnotationEditorState();
}

class _AnnotationEditorState extends State<AnnotationEditor> {
  // Clé pour récupérer la taille réelle de l'image affichée à l'écran
  final GlobalKey _imageKey = GlobalKey();
  
  List<Annotation> _currentAnnotations = [];
  Offset? _startDrag;
  Offset? _currentDrag;

  // Affiche la popup pour choisir la classe après avoir dessiné un rectangle
  void _showClassSelectionDialog(Rect rect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Quelle classe ?"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.classes.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(widget.classes[i]),
                onTap: () {
                  setState(() {
                    _currentAnnotations.add(Annotation(
                      rect: rect,
                      label: widget.classes[i],
                      classId: i,
                    ));
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Annuler l'ajout
              child: const Text("Annuler"),
            )
          ],
        );
      },
    );
  }

  void _handleSave() {
    // On récupère la taille exacte du widget Image affiché à l'écran
    // C'est CRUCIAL pour convertir les pixels du rectangle en pourcentage YOLO (0.0 - 1.0)
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null) {
      widget.onValidated(_currentAnnotations, renderBox.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Zone Image + Dessin
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _startDrag = details.localPosition;
                    _currentDrag = details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentDrag = details.localPosition;
                  });
                },
                onPanEnd: (details) {
                  if (_startDrag != null && _currentDrag != null) {
                    // On crée le rectangle normalisé (gauche/haut/droite/bas)
                    final rect = Rect.fromPoints(_startDrag!, _currentDrag!);
                    // Si le rectangle est trop petit (clic involontaire), on l'ignore
                    if (rect.width > 10 && rect.height > 10) {
                      _showClassSelectionDialog(rect);
                    }
                  }
                  setState(() {
                    _startDrag = null;
                    _currentDrag = null;
                  });
                },
                child: Stack(
                  key: _imageKey, // La clé est ici pour mesurer la taille
                  children: [
                    // 1. L'image de fond
                    Image.file(
                      File(widget.imageFile.path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain, // Garde les proportions
                    ),

                    // 2. Les rectangles déjà validés (Verts)
                    ..._currentAnnotations.map((annotation) {
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: annotation.rect,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green, width: 2),
                                color: Colors.green.withOpacity(0.2),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    annotation.label,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // La croix rouge pour supprimer
                          Positioned(
                            left: annotation.rect.right - 20,
                            top: annotation.rect.top - 10,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentAnnotations.remove(annotation);
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(5),
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),

                    // 3. Le rectangle en cours de tracé (Bleu)
                    if (_startDrag != null && _currentDrag != null)
                      Positioned.fromRect(
                        rect: Rect.fromPoints(_startDrag!, _currentDrag!),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent, width: 2),
                            color: Colors.blueAccent.withOpacity(0.1),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // Barre d'outils en bas
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bouton Annuler (Undo)
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: "Retirer le dernier",
                  onPressed: _currentAnnotations.isNotEmpty 
                    ? () => setState(() => _currentAnnotations.removeLast()) 
                    : null,
                ),
                
                // Info compteur
                Text(
                  "${_currentAnnotations.length} objet(s)", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),

                // Bouton Sauvegarder
                ElevatedButton.icon(
                  onPressed: _handleSave,
                  icon: const Icon(Icons.save),
                  label: const Text("VALIDER"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}