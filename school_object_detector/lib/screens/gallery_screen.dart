import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'object_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img; 
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  File? _selectedImage;
  // On ajoute une variable pour stocker l'image corrigée (droite)
  Uint8List? _correctedImageBytes; 
  Size? _correctedImageSize;

  String _resultText = "";
  bool _isAnalyzing = false;
  late ObjectDetectionService _objectDetectionService;


  @override
  void initState() {
    super.initState();
    _objectDetectionService = ObjectDetectionService();
    _objectDetectionService.initialize();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _correctedImageBytes = null; // Reset
        _correctedImageSize = null;
        _resultText = "";
      });
    }
  }

  Future<void> _analyzeImage() async {
  if (_selectedImage == null) return;

  setState(() {
    _isAnalyzing = true;
    _resultText = "Analyse en cours...";
  });

  try {
    final rawBytes = await _selectedImage!.readAsBytes();

    // 1. On décode et on corrige l'orientation
    img.Image? originalImage = img.decodeImage(rawBytes);
    
    if (originalImage != null) {
      // "Cuisson" de l'orientation (remet l'image droite pour de bon)
      img.Image fixedImage = img.bakeOrientation(originalImage);

      // 2. Analyse par l'IA
      // On encode en JPG pour l'envoyer à l'IA
      final fixedBytes = img.encodeJpg(fixedImage);
      final detections = await _objectDetectionService.processImage(
        fixedBytes, 
        fixedImage.width, 
        fixedImage.height
      );

      // 3. DESSIN DES RECTANGLES SUR L'IMAGE (La partie magique)
      // On dessine directement sur 'fixedImage' qui sera sauvegardée
      for (var detection in detections) {
        final box = detection["box"]; // [x1, y1, x2, y2, prob]
        
        // Conversion en entiers pour la librairie 'image'
        final x1 = (box[0] as double).toInt();
        final y1 = (box[1] as double).toInt();
        final x2 = (box[2] as double).toInt();
        final y2 = (box[3] as double).toInt();
        
        // Dessin du rectangle (Rouge, épaisseur 3)
        img.drawRect(
          fixedImage, 
          x1: x1, y1: y1, x2: x2, y2: y2, 
          color: img.ColorRgb8(255, 0, 0), 
          thickness: 3
        );

        // Dessin du texte (Si possible)
        // Note: img.arial24 est une police incluse par défaut
        final label = "${detection['tag']} ${(box[4] * 100).toStringAsFixed(0)}%";

        // Estimation de la taille du fond (arial24 ~14px large + padding)
        int textWidth = label.length * 14 + 12; 
        int textHeight = 30;
        
        // Position Y : Au-dessus, sinon dedans si on dépasse en haut
        int textY = y1 - textHeight;
        if (textY < 0) textY = y1 + 4;
        

        // A. Fond NOIR
        img.fillRect(
          fixedImage, 
          x1: x1, 
          y1: textY, 
          x2: x1 + textWidth, 
          y2: textY + textHeight, 
          color: img.ColorRgb8(0, 0, 0)
        );

        // B. Texte BLANC
        img.drawString(
          fixedImage, 
          label, 
          font: img.arial24, 
          x: x1 + 6, 
          y: textY + 3, 
          color: img.ColorRgb8(255, 255, 255)
        );
      }

      // 4. Sauvegarde de l'image annotée dans le téléphone
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'analyse_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(directory.path, fileName);
      
      // On écrit le fichier modifié sur le disque
      final finalBytes = img.encodeJpg(fixedImage);
      await File(savedPath).writeAsBytes(finalBytes);

      // 5. On ajoute le chemin de l'image MODIFIÉE à l'historique
      await _addToHistory(savedPath);

      setState(() {
        // On affiche l'image modifiée à l'écran aussi
        _correctedImageBytes = finalBytes; 
        _correctedImageSize = Size(fixedImage.width.toDouble(), fixedImage.height.toDouble());
        
        if (detections.isNotEmpty) {
           _resultText = "Objets détectés et image sauvegardée !";
        } else {
          _resultText = "✅ Aucun objet scolaire détecté.";
        }
      });
    }

  } catch (e) {
    debugPrint('Erreur lors de l\'analyse: $e');
    setState(() {
      _resultText = "❌ Erreur : $e";
    });
  } finally {
    setState(() {
      _isAnalyzing = false;
    });
  }
}

  Future<void> _addToHistory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('history_images') ?? [];
    history.remove(path);
    history.add(path);
    await prefs.setStringList('history_images', history);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Analyse d'image"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ZONE D'IMAGE
              Expanded(
                child: Center(
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_rounded, size: 90, color: Colors.grey[400]),
                            const SizedBox(height: 20),
                            const Text("Aucune image sélectionnée", style: TextStyle(fontSize: 17, color: Colors.black54)),
                          ],
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // 3. LOGIQUE D'AFFICHAGE INTELLIGENTE
                              // Si on a fait l'analyse, on affiche l'image corrigée (bytes).
                              // Sinon, on affiche le fichier brut (File).
                              final bool hasAnalysis = _correctedImageBytes != null && _correctedImageSize != null;
                              
                              return FittedBox(
                                fit: BoxFit.contain,
                                child: hasAnalysis 
                                  ? SizedBox(
                                      width: _correctedImageSize!.width,
                                      height: _correctedImageSize!.height,
                                      child: Stack(
                                        children: [
                                          Image.memory(_correctedImageBytes!), // L'image EXACTE vue par YOLO
                                        ],
                                      ),
                                    )
                                  : Image.file(_selectedImage!), // Affichage simple avant analyse
                              );
                            },
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // BOUTONS
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text("Choisir une image", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedImage != null && !_isAnalyzing ? _analyzeImage : null,
                  icon: _isAnalyzing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Icon(Icons.search_rounded),
                  label: Text(_isAnalyzing ? "Analyse en cours..." : "Analyser", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2575FC),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_resultText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: SingleChildScrollView(
                    child: Text(_resultText, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}