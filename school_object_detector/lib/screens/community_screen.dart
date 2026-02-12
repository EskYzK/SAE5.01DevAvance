import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/full_screen_image_viewer.dart'; // Import du widget de zoom

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Communauté"),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('detections')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Oups, une erreur est survenue."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public_off, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Aucun partage pour le moment."),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final data = docs[index].data() as Map<String, dynamic>;
              
              final dynamic rawConfidence = data['confidence'];
              String confString = rawConfidence?.toString() ?? '0';
              List<String> confParts = confString.split(',');

              String displayConfidence = confParts.map((part) {
                double val = double.tryParse(part.trim().replaceAll(',', '.')) ?? 0.0;
                return "${(val * 100).toStringAsFixed(1)}%";
              }).join(', ');

              double mainConfidence = 0.0;
              if (confParts.isNotEmpty) {
                mainConfidence = double.tryParse(confParts[0].trim().replaceAll(',', '.')) ?? 0.0;
              }

              final String? imageUrl = data['imageUrl'];
              final String label = data['label'] ?? 'Objet inconnu';
              final String userPseudo = data['userPseudo'] ?? 'Anonyme';
              final String docId = docs[index].id;

              final String? userPhotoUrl = data['userPhotoUrl'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        backgroundImage: (userPhotoUrl != null && userPhotoUrl.isNotEmpty) 
                            ? NetworkImage(userPhotoUrl) 
                            : null,
                          child: (userPhotoUrl == null || userPhotoUrl.isEmpty) 
                            ? Text(
                                userPseudo.isNotEmpty ? userPseudo[0].toUpperCase() : "?",
                                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(userPseudo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.public, size: 16, color: Colors.grey),
                    ),

                    if (imageUrl != null && imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imagePath: imageUrl,
                                heroTag: 'community_$docId',
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'community_$docId',
                          child: SizedBox(
                            height: 250,
                            width: double.infinity,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 250,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Confiance IA : $displayConfidence", // Affiche "95.0%, 82.0%"
                                style: TextStyle(
                                  // Utilise mainConfidence (le premier objet) pour la couleur
                                  color: mainConfidence > 0.8 ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}