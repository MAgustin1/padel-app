import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchResultScreen extends StatefulWidget {
  final String matchId;
  final List<dynamic> jugadoresActuales; 

  const MatchResultScreen({super.key, required this.matchId, required this.jugadoresActuales});

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> {
  bool _estaGuardando = false;
  String? _companeroSeleccionadoUid;

  // Obtenemos los nombres de los otros 3 jugadores para elegir compañero
  Future<List<Map<String, dynamic>>> _obtenerOtrosJugadores() async {
    final String miUid = FirebaseAuth.instance.currentUser!.uid;
    List<String> otrosUids = List<String>.from(widget.jugadoresActuales).where((uid) => uid != miUid).toList();

    if (otrosUids.isEmpty) return [];
    
    final query = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: otrosUids).get();
    return query.docs.map((doc) => {'uid': doc.id, 'apodo': doc['apodo']}).toList();
  }

  // --- GUARDA EL RESULTADO COMO "PENDIENTE DE CONFIRMACIÓN" ---
  Future<void> _proponerResultado(String resultado) async {
    if (_companeroSeleccionadoUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Falta elegir a tu compañero!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _estaGuardando = true);

    try {
      final String miUid = FirebaseAuth.instance.currentUser!.uid;
      
      // Armamos los equipos
      List<String> equipoA = [miUid, _companeroSeleccionadoUid!];
      List<String> equipoB = List<String>.from(widget.jugadoresActuales).where((uid) => !equipoA.contains(uid)).toList();

      // Guardamos la propuesta en el partido
      await FirebaseFirestore.instance.collection('partidos').doc(widget.matchId).update({
        'estado': 'esperando_confirmacion',
        'equipoA': equipoA,
        'equipoB': equipoB,
        'resultadoPropuesto': resultado, 
        'propuestoPor': miUid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultado enviado. Esperando que los rivales confirmen.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFFDFFF00))
      );
      
      Navigator.of(context).popUntil((route) => route.isFirst); // Volvemos al Home

    } catch (e) {
      print("Error al proponer: $e");
      setState(() => _estaGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CARGAR RESULTADO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)), 
        backgroundColor: Colors.transparent, 
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: _estaGuardando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(top: 110, left: 24, right: 24, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('1. ¿QUIÉN FUE TU COMPAÑERO?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  
                  // --- SELECTOR DE COMPAÑERO (Cristal Oscuro) ---
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _obtenerOtrosJugadores(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFDFFF00))));
                      final jugadores = snapshot.data!;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
                        ),
                        child: Column(
                          children: jugadores.map((j) {
                            final bool isSelected = _companeroSeleccionadoUid == j['uid'];
                            return Theme(
                              data: ThemeData(
                                unselectedWidgetColor: Colors.grey[600],
                              ),
                              child: RadioListTile<String>(
                                title: Text(
                                  j['apodo'].toString().toUpperCase(), 
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                                    color: isSelected ? const Color(0xFFDFFF00) : Colors.white
                                  )
                                ),
                                value: j['uid'],
                                groupValue: _companeroSeleccionadoUid,
                                activeColor: const Color(0xFFDFFF00),
                                onChanged: (val) => setState(() => _companeroSeleccionadoUid = val),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),

                  const Text('2. ¿CÓMO SALIERON USTEDES?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
                  const SizedBox(height: 12),

                  // --- BOTONES DE RESULTADO GAMING ---
                  _buildResultButton('¡Ganamos 2 a 0!', const Color(0xFFDFFF00), Icons.emoji_events, () => _proponerResultado('2-0')),
                  const SizedBox(height: 16),
                  _buildResultButton('Ganamos 2 a 1', Colors.greenAccent, Icons.thumb_up, () => _proponerResultado('2-1')),
                  const SizedBox(height: 16),
                  _buildResultButton('Perdimos 1 a 2', Colors.orangeAccent, Icons.thumb_down, () => _proponerResultado('1-2')),
                  const SizedBox(height: 16),
                  _buildResultButton('Perdimos 0 a 2', Colors.redAccent, Icons.sentiment_very_dissatisfied, () => _proponerResultado('0-2')),
                ],
              ),
            ),
    );
  }

  // --- BOTÓN GAMING DE RESULTADO ---
  Widget _buildResultButton(String titulo, Color colorAcento, IconData icono, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: colorAcento.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))
        ]
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B), // Fondo cristal oscuro
          foregroundColor: colorAcento, // Efecto al clickear
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: colorAcento.withOpacity(0.5), width: 1.5) // Borde del color de la victoria/derrota
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: colorAcento, size: 24),
            const SizedBox(width: 12),
            Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorAcento, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}