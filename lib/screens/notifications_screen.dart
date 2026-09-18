import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Función para borrar una notificación del historial
  Future<void> _borrarNotificacion(String docId) async {
    final String miUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(miUid)
        .collection('notificaciones')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final String miUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito
      appBar: AppBar(
        title: const Text('NOTIFICACIONES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(miUid)
            .collection('notificaciones')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No tenés notificaciones nuevas.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final notificaciones = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notificaciones.length,
            itemBuilder: (context, index) {
              final doc = notificaciones[index];
              final datos = doc.data() as Map<String, dynamic>;
              
              final String titulo = datos['titulo'] ?? 'Aviso';
              final String mensaje = datos['mensaje'] ?? '';
              final String tipo = datos['tipo'] ?? 'info'; 
              
              IconData icono = Icons.info_outline;
              Color colorIcono = Colors.grey;
              
              if (tipo == 'match') {
                icono = Icons.favorite;
                colorIcono = Colors.redAccent;
              } else if (tipo == 'partido') {
                icono = Icons.sports_tennis;
                colorIcono = const Color(0xFFDFFF00);
              }

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) => _borrarNotificacion(doc.id),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colorIcono.withOpacity(0.1),
                      child: Icon(icono, color: colorIcono),
                    ),
                    title: Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(mensaje, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ),
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