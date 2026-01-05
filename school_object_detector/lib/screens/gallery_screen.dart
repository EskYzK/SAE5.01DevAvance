import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'object_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  File? _selectedImage;
  String _resultText = "";
  bool _isAnalyzing = false;
  late ObjectDetectionService _objectDetectionService;
  List<Map<String, dynamic>> _detections = [];
  ui.Image? _loadedImage;

  @override
  void initState() {
    super.initState();
    _objectDetectionService = ObjectDetectionService();
    _objectDetectionService.initialize();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _resultText = "";
        _detections = [];
        _loadedImage = null;
      });
      
      final data = await _selectedImage!.readAsBytes();
      final image = await decodeImageFromList(data);
      setState(() {
        _loadedImage = image;
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
      final bytes = await _selectedImage!.readAsBytes();
      final detections = await _objectDetectionService.processImage(bytes);

      await _addToHistory(_selectedImage!.path);

      setState(() {
        _detections = detections;
        
        if (detections.isNotEmpty) {
          _resultText = "Objets détectés :\n\n" +
              detections.map<String>((d) {
                 double conf = (d['box'][4] * 100); 
                 return "• ${d['tag']} (confiance: ${conf.toStringAsFixed(0)}%)";
              }).join("\n");
        } else {
          _resultText = "✅ Aucun objet scolaire détecté.";
        }
      });

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
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Expanded(
                child: Center(
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              size: 90,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Aucune image sélectionnée",
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          // Modification ici : Stack pour superposer les cadres sur l'image
                          child: _loadedImage == null 
                            ? Image.file(_selectedImage!, fit: BoxFit.contain)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  return FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox(
                                      width: _loadedImage!.width.toDouble(),
                                      height: _loadedImage!.height.toDouble(),
                                      child: Stack(
                                        children: [
                                          Image.file(_selectedImage!),
                                          CustomPaint(
                                            painter: GalleryObjectPainter(
                                              _detections,
                                            ),
                                            size: Size(
                                              _loadedImage!.width.toDouble(),
                                              _loadedImage!.height.toDouble(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // BOUTON CHOISIR (Ton style exact)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text(
                    "Choisir une image",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // BOUTON ANALYSER (Ton style exact)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedImage != null && !_isAnalyzing
                      ? _analyzeImage
                      : null,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(
                    _isAnalyzing ? "Analyse en cours..." : "Analyser",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2575FC),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // RESULTATS (Ton style exact)
              if (_resultText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _resultText,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GalleryObjectPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;

  GalleryObjectPainter(this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = const Color(0xFF6A11CB);

    for (var object in objects) {
      final box = object["box"]; // [x1, y1, x2, y2, prob]
      // Conversion directe des coordonnées
      final rect = Rect.fromLTRB(box[0], box[1], box[2], box[3]);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
