import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart'; 

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final String miUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Text(
              'MIS CONEXIONES ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Icon(
              Icons.sports_tennis, 
              color: Color(0xFFDFFF00), 
              size: 24, 
            ),
          ],
        ),
        // 👇 ACÁ ESTABA EL ERROR. Ahora tiene EXACTAMENTE el mismo color que el fondo del Scaffold
        backgroundColor: const Color(0xFF0F172A), 
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(miUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Error al cargar tus datos.', style: TextStyle(color: Colors.grey)),
            );
          }

          final datosUsuario = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> amigosIds = datosUsuario['amigos'] ?? [];

          if (amigosIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_tennis, size: 80, color: Colors.grey[700]),
                    const SizedBox(height: 20),
                    const Text(
                      '¡Todavía no hay conexiones!',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Andá al Tinder de Pádel y dale paletazo a los jugadores para empezar a armar tu lista de amigos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.bug_report),
                      label: const Text('FORZAR MATCH DE PRUEBA'),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc('AMIGO_PRUEBA').set({
                            'nombre': 'LA BESTIA',
                            'categoriaLugar': '3RA / DRIVE',
                            'media': 88,
                            'avatarUrl': 'https://api.dicebear.com/9.x/micah/png?seed=LaBestia&backgroundColor=transparent'
                          });

                          await FirebaseFirestore.instance.collection('users').doc(miUid).update({
                            'amigos': FieldValue.arrayUnion(['AMIGO_PRUEBA'])
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('¡Amigo inyectado con éxito!'), backgroundColor: Colors.green)
                          );
                        } catch (e) {
                          print("Error inyectando: $e");
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: amigosIds)
                .snapshots(),
            builder: (context, amigosSnapshot) {
              if (amigosSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }

              if (!amigosSnapshot.hasData || amigosSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No se pudo encontrar la info de tus amigos.', style: TextStyle(color: Colors.grey)));
              }

              final listaAmigos = amigosSnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                itemCount: listaAmigos.length,
                itemBuilder: (context, index) {
                  final amigo = listaAmigos[index];
                  final datosAmigo = amigo.data() as Map<String, dynamic>;
                  
                  final String nombre = datosAmigo['nombre'] ?? 'Jugador';
                  final String avatarUrl = datosAmigo['avatarUrl'] ?? 'https://api.dicebear.com/9.x/micah/png';
                  final String categoria = datosAmigo['categoriaLugar'] ?? 'Sin Categoría';
                  final int media = datosAmigo['media'] ?? 60;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B), 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: NetworkImage(avatarUrl),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$media',
                                  style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            nombre.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Categoría: $categoria',
                              style: TextStyle(color: Colors.blueGrey[200], fontSize: 13),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  idOtroJugador: amigo.id,
                                  nombreOtroJugador: nombre,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}