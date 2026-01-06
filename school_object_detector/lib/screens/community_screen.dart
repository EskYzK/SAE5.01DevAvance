import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Communauté")),
      body: StreamBuilder<QuerySnapshot>(
        // Écoute en temps réel la collection 'detections'
        stream: FirebaseFirestore.instance
            .collection('detections')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("Aucun partage pour le moment."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Affiche l'image depuis Internet
                    if (data['imageUrl'] != null)
                      Image.network(
                        data['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, loading) {
                          if (loading == null) return child;
                          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                        },
                      ),
                    ListTile(
                      title: Text(data['label'] ?? 'Inconnu'),
                      subtitle: Text("Confiance : ${((data['confidence'] ?? 0) * 100).toStringAsFixed(1)}%"),
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