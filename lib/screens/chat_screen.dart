import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_details_screen.dart'; // 👇 IMPORTANTE: Sumamos esta importación

class ChatScreen extends StatefulWidget {
  final String idOtroJugador;
  final String nombreOtroJugador;

  const ChatScreen({
    super.key,
    required this.idOtroJugador,
    required this.nombreOtroJugador,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final String miUid = FirebaseAuth.instance.currentUser!.uid;
  late String _chatId;

  @override
  void initState() {
    super.initState();
    _chatId = _generarChatId(miUid, widget.idOtroJugador);
  }

  // Truco para que la sala de chat sea siempre la misma para ambos
  String _generarChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort(); // Los ordenamos alfabéticamente
    return uids.join('_'); // Ej: "abc_xyz"
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty) return;

    _mensajeController.clear(); // Limpiamos la caja de texto rápido

    try {
      final mensajeRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('mensajes')
          .doc();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);

      // Batch: el mensaje y el "último mensaje" del chat se escriben juntos,
      // para que el inbox nunca quede desactualizado si una de las dos falla.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(mensajeRef, {
        'texto': texto,
        'enviadoPor': miUid,
        'tipo': 'texto',
        'fecha': FieldValue.serverTimestamp(),
      });
      batch.set(chatRef, {
        'ultimoMensaje': texto,
        'fechaUltimo': FieldValue.serverTimestamp(),
        'participantes': [miUid, widget.idOtroJugador],
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      _mensajeController.text = texto; // No lo dejamos perderse: lo devolvemos al input
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el mensaje: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- 1. MENÚ DE INVITACIÓN A PARTIDOS ---
  void _mostrarPartidosParaInvitar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          // Buscamos los partidos donde vos estás jugando y siguen abiertos
          stream: FirebaseFirestore.instance
              .collection('partidos')
              .where('jugadoresActuales', arrayContains: miUid)
              .where('estado', isEqualTo: 'abierto')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00))),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text('No tenés partidos con lugares disponibles.', style: TextStyle(color: Colors.grey)),
                ),
              );
            }

            // Filtramos por las dudas para asegurarnos de que haya lugar
            final misPartidosAbiertos = snapshot.data!.docs.where((doc) {
              final datos = doc.data() as Map<String, dynamic>;
              return (datos['lugaresDisponibles'] as int) > 0;
            }).toList();

            if (misPartidosAbiertos.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text('Tus partidos ya están llenos.', style: TextStyle(color: Colors.grey)),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Elegí un partido para invitar:',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: misPartidosAbiertos.length,
                    itemBuilder: (context, index) {
                      final doc = misPartidosAbiertos[index];
                      final datos = doc.data() as Map<String, dynamic>;
                      
                      final DateTime fecha = (datos['fechaHora'] as Timestamp).toDate();
                      final String horaStr = "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}hs";
                      final String diaStr = "${fecha.day}/${fecha.month}";

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF1E293B),
                          child: Icon(Icons.sports_tennis, color: Color(0xFFDFFF00)),
                        ),
                        title: Text(datos['club'].toString().toUpperCase(), style: const TextStyle(color: Colors.white)),
                        subtitle: Text("$diaStr - $horaStr • Faltan ${datos['lugaresDisponibles']} lugares", style: TextStyle(color: Colors.grey[400])),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Cerramos el menú
                            _enviarInvitacionAlChat(doc.id, datos['club'], diaStr, horaStr);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDFFF00),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Invitar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  // --- 2. MANDAR INVITACIÓN AL CHAT ---
  Future<void> _enviarInvitacionAlChat(String idPartido, String club, String dia, String hora) async {
    final textoInvitacion = '¡Che, sumate a mi partido! Jugamos en $club el $dia a las $hora. 🎾';

    try {
      final mensajeRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('mensajes')
          .doc();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);

      final batch = FirebaseFirestore.instance.batch();
      batch.set(mensajeRef, {
        'texto': textoInvitacion,
        'enviadoPor': miUid,
        'tipo': 'invitacion',
        'partidoId': idPartido,
        // 👇 Guardamos estos datos extra para dibujar la tarjeta fácil
        'club': club,
        'dia': dia,
        'hora': hora,
        'fecha': FieldValue.serverTimestamp(),
      });
      batch.set(chatRef, {
        'ultimoMensaje': '🎾 Invitación a partido',
        'fechaUltimo': FieldValue.serverTimestamp(),
        'participantes': [miUid, widget.idOtroJugador],
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la invitación: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          widget.nombreOtroJugador.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_tennis, color: Color(0xFFDFFF00)),
            onPressed: () {
              _mostrarPartidosParaInvitar(context);
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- ZONA DE BURBUJAS DE CHAT ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // 👇 Tope a los últimos 50 mensajes: sin esto, cada apertura del
              // chat descarga y mantiene en memoria el historial completo de
              // la conversación. Paginación real ("cargar más" al scrollear
              // hacia arriba) queda pendiente como mejora futura.
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('mensajes')
                  .orderBy('fecha', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Rompé el hielo y mandale un mensaje a ${widget.nombreOtroJugador} 🧊🎾',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                final mensajes = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, 
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final datosMsg = mensajes[index].data() as Map<String, dynamic>;
                    final bool soyYo = datosMsg['enviadoPor'] == miUid;
                    final bool esInvitacion = datosMsg['tipo'] == 'invitacion';
                    
                    // Elegimos qué tipo de burbuja mostrar
                    if (esInvitacion) {
                      return _buildBurbujaInvitacion(datosMsg, soyYo, context);
                    } else {
                      return _buildBurbujaTexto(datosMsg, soyYo);
                    }
                  },
                );
              },
            ),
          ),

          // --- CAJA PARA ESCRIBIR MENSAJE ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A0A),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribí un mensaje...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _enviarMensaje,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDFFF00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BURBUJA DE TEXTO NORMAL ---
  Widget _buildBurbujaTexto(Map<String, dynamic> datosMsg, bool soyYo) {
    return Align(
      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: soyYo ? const Color(0xFFDFFF00) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: soyYo ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: soyYo ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Text(
          datosMsg['texto'] ?? '',
          style: TextStyle(
            color: soyYo ? Colors.black : Colors.white,
            fontWeight: soyYo ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- WIDGET TARJETA DE INVITACIÓN (Estilo Home) ---
  Widget _buildBurbujaInvitacion(Map<String, dynamic> datosMsg, bool soyYo, BuildContext context) {
    final club = datosMsg['club'] ?? 'Cancha';
    final dia = datosMsg['dia'] ?? '';
    final hora = datosMsg['hora'] ?? '';
    final partidoId = datosMsg['partidoId'] ?? '';

    return Align(
      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          // Si tocan la tarjeta, los manda directo a los detalles del partido
          if (partidoId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MatchDetailsScreen(matchId: partidoId)),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: MediaQuery.of(context).size.width * 0.75, // La tarjeta ocupa el 75% del ancho del chat
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E293B),
                const Color(0xFF0F172A).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: soyYo ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight: soyYo ? const Radius.circular(4) : const Radius.circular(20),
            ),
            border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.1), blurRadius: 10, spreadRadius: 1)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado de la tarjeta
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFFF00).withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  )
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Color(0xFFDFFF00), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      soyYo ? 'INVITACIÓN ENVIADA' : '¡TE INVITARON!', 
                      style: const TextStyle(color: Color(0xFFDFFF00), fontWeight: FontWeight.w900, fontSize: 12)
                    ),
                  ],
                ),
              ),
              // Cuerpo de la tarjeta
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(datosMsg['texto'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(club.toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('$dia - $hora', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Color(0xFFDFFF00), size: 14)
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}