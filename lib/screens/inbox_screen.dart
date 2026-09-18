import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

// 👇 Firestore corta 'whereIn' en 30 valores: si el usuario tiene más de 30
// amigos, la query directa fallaría entera y la lista de amigos desaparecería
// sin aviso. Partimos los IDs en tandas de 30 y combinamos los resultados en
// vivo de cada tanda en un solo stream.
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _streamAmigosEnTandas(List<String> amigosIds) {
  const int tamanioTanda = 30;
  final List<List<String>> tandas = [];
  for (int i = 0; i < amigosIds.length; i += tamanioTanda) {
    tandas.add(amigosIds.sublist(i, i + tamanioTanda > amigosIds.length ? amigosIds.length : i + tamanioTanda));
  }

  late final StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>> controller;
  final resultadosPorTanda = List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.filled(tandas.length, const []);
  final List<StreamSubscription> subs = [];

  void emitirCombinado() {
    controller.add(resultadosPorTanda.expand((lista) => lista).toList());
  }

  controller = StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.broadcast(
    onListen: () {
      for (int i = 0; i < tandas.length; i++) {
        subs.add(
          FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: tandas[i])
              .snapshots()
              .listen((snap) {
            resultadosPorTanda[i] = snap.docs;
            emitirCombinado();
          }),
        );
      }
    },
    onCancel: () {
      for (final s in subs) {
        s.cancel();
      }
    },
  );

  return controller.stream;
}

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
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _streamAmigosEnTandas(amigosIds.cast<String>()),
            builder: (context, amigosSnapshot) {
              if (amigosSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }

              if (!amigosSnapshot.hasData || amigosSnapshot.data!.isEmpty) {
                return const Center(child: Text('No se pudo encontrar la info de tus amigos.', style: TextStyle(color: Colors.grey)));
              }

              final listaAmigos = amigosSnapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                itemCount: listaAmigos.length,
                itemBuilder: (context, index) {
                  final amigo = listaAmigos[index];
                  final datosAmigo = amigo.data();
                  
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