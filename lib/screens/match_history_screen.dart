import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final String miUid = FirebaseAuth.instance.currentUser!.uid;

  // Lógica para saber si el usuario ganó, perdió, y cuántos puntos sacó
  Map<String, dynamic> _analizarResultado(Map<String, dynamic> datos) {
    final String resultado = datos['resultadoPropuesto'] ?? 'Sin resultado';
    final List equipoA = datos['equipoA'] ?? [];
    final List equipoB = datos['equipoB'] ?? [];

    bool soyEquipoA = equipoA.contains(miUid);
    bool soyEquipoB = equipoB.contains(miUid);

    int misPuntos = 0;
    String estado = 'EMPATE';
    Color color = Colors.grey;

    if (soyEquipoA || soyEquipoB) {
      if (resultado == '2-0') {
        misPuntos = soyEquipoA ? 3 : 0;
        estado = soyEquipoA ? 'VICTORIA' : 'DERROTA';
      } else if (resultado == '2-1') {
        misPuntos = soyEquipoA ? 2 : 1;
        estado = soyEquipoA ? 'VICTORIA' : 'DERROTA';
      } else if (resultado == '1-2') {
        misPuntos = soyEquipoA ? 1 : 2;
        estado = soyEquipoA ? 'DERROTA' : 'VICTORIA';
      } else if (resultado == '0-2') {
        misPuntos = soyEquipoA ? 0 : 3;
        estado = soyEquipoA ? 'DERROTA' : 'VICTORIA';
      }
    }

    if (estado == 'VICTORIA') color = Colors.greenAccent;
    if (estado == 'DERROTA') color = Colors.redAccent;

    return {
      'puntos': '+$misPuntos PTS',
      'estado': estado,
      'color': color,
      'resultado': resultado
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('HISTORIAL DE PARTIDOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos todos los partidos donde estás anotado
        stream: FirebaseFirestore.instance
            .collection('partidos')
            .where('jugadoresActuales', arrayContains: miUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Todavía no jugaste ningún partido.', style: TextStyle(color: Colors.grey)));
          }

          // Filtramos SOLO los finalizados y los ordenamos en Dart para evitar indexar en Firebase
          final partidosFinalizados = snapshot.data!.docs.where((doc) {
            final datos = doc.data() as Map<String, dynamic>;
            return datos['estado'] == 'finalizado';
          }).toList();

          if (partidosFinalizados.isEmpty) {
            return const Center(
              child: Text('No tenés partidos finalizados aún.\n¡A salir a la cancha!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
            );
          }

          // Ordenamos del más reciente al más antiguo
          partidosFinalizados.sort((a, b) => (b['fechaHora'] as Timestamp).compareTo(a['fechaHora'] as Timestamp));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: partidosFinalizados.length,
            itemBuilder: (context, index) {
              final datos = partidosFinalizados[index].data() as Map<String, dynamic>;
              
              final DateTime fecha = (datos['fechaHora'] as Timestamp).toDate();
              final String fechaStr = "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";
              
              final analisis = _analizarResultado(datos);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: analisis['color'].withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                  ]
                ),
                child: Row(
                  children: [
                    // Columna Izquierda (Info)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fechaStr, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(datos['club'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: analisis['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: analisis['color'].withOpacity(0.5))
                            ),
                            child: Text(
                              analisis['estado'],
                              style: TextStyle(color: analisis['color'], fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    // Columna Derecha (Resultado y Puntos)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          analisis['resultado'],
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analisis['puntos'],
                          style: TextStyle(color: analisis['color'], fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    )
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