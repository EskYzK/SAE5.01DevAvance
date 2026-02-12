import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/history_service.dart';
import 'package:intl/intl.dart';
import '../widgets/full_screen_image_viewer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Historique")),
        body: const Center(child: Text("Connectez-vous pour voir votre historique.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mon Historique Cloud ☁️")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('User')
            .doc(user.uid)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Aucun scan sauvegardé."),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String dateStr = "Date inconnue";
              if (data['timestamp'] != null) {
                DateTime date = (data['timestamp'] as Timestamp).toDate();
                dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
              }

              final imageUrl = data['imageUrl'] ?? '';

              return Dismissible(
                key: Key(doc.id),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  HistoryService().deleteDetection(doc.id, data['imageUrl']);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Supprimé !")));
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (imageUrl.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imagePath: imageUrl,
                                heroTag: doc.id, 
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: doc.id,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 60, height: 60, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      data['label'] ?? "Objet",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text("$dateStr\nConfiance: ${(double.tryParse(data['confidence']?.toString() ?? '0') ?? 0 * 100).toStringAsFixed(1)}%"),
                    isThreeLine: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}