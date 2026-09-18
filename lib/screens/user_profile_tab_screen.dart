import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/player_card_widget.dart';
import 'match_history_screen.dart';


class UserProfileTabScreen extends StatefulWidget {
  const UserProfileTabScreen({super.key});

  @override
  State<UserProfileTabScreen> createState() => _UserProfileTabScreenState();
}

class _UserProfileTabScreenState extends State<UserProfileTabScreen> {
  
  // --- FUNCIÓN DEL POP-UP (CARTA GIGANTE) ---
  void _abrirCartaGigante(BuildContext context, Map<String, dynamic> datos, int mediaCalc, int ganados, int perdidos) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 320,
                height: 450,
                child: PadelPlayerCardWidget(
                  nombre: datos['apodo']?.toString().toUpperCase() ?? 'JUGADOR',
                  media: mediaCalc,
                  categoriaLugar: '${datos['categoria'] ?? '8va'} / ${datos['posicion'] ?? 'DRIVE'}'.toUpperCase(),
                  vel: _calc(datos, 'VEL'), rem: _calc(datos, 'REM'), vol: _calc(datos, 'VOL'),
                  def: _calc(datos, 'DEF'), con: _calc(datos, 'CON'), fis: _calc(datos, 'FIS'),
                  avatarUrl: datos['avatarUrl'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=${datos['apodo']}&backgroundColor=transparent',
                  isTinderView: false,
                  partidosGanados: ganados,
                  partidosPerdidos: perdidos,
                ),
              ),
              Positioned(
                top: 0, right: 0,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white, size: 35),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  // Helper para calcular las stats con el bonus de categoría
  int _calc(Map<String, dynamic> datos, String stat) {
    String cat = (datos['categoria'] ?? '8va').toString().toLowerCase();
    int base = 50;
    if (cat.contains('1ra')) base = 92;
    else if (cat.contains('2da')) base = 88;
    else if (cat.contains('3ra')) base = 84;
    else if (cat.contains('4ta')) base = 78;
    else if (cat.contains('5ta')) base = 73;
    else if (cat.contains('6ta')) base = 67;
    else if (cat.contains('7ma')) base = 60;

    int valorCrudo = (datos['estadisticas']?[stat] ?? 50);
    int finalStat = base + (valorCrudo * 0.12).round();
    return finalStat > 99 ? 99 : finalStat;
  }

  // 👇 NUEVA FUNCIÓN: POP-UP DE EDICIÓN RÁPIDA 👇
  void _abrirEditorPerfil(BuildContext context, Map<String, dynamic> datosActuales) {
    final TextEditingController apodoController = TextEditingController(text: datosActuales['apodo']);
    final TextEditingController telController = TextEditingController(text: datosActuales['telefono']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('EDITAR MIS DATOS', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFDFFF00), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 24),
                TextField(
                  controller: apodoController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Apodo en la Carta',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.star_border, color: Color(0xFFDFFF00)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: telController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Teléfono de Contacto',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFFDFFF00)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    if (apodoController.text.trim().isEmpty || telController.text.trim().isEmpty) return;
                    
                    try {
                      final String miUid = FirebaseAuth.instance.currentUser!.uid;
                      await FirebaseFirestore.instance.collection('users').doc(miUid).update({
                        'apodo': apodoController.text.trim(),
                        'telefono': telController.text.trim(),
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Datos actualizados!'), backgroundColor: Colors.greenAccent));
                    } catch (e) {
                      print("Error al actualizar: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDFFF00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final String miUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text('MI ÁLBUM', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent, 
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(miUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Error al cargar tu perfil.', style: TextStyle(color: Colors.grey)));
          }

          final datos = snapshot.data!.data() as Map<String, dynamic>;
          
          // Matemáticas previas
          final int vF = _calc(datos, 'VEL'); final int rF = _calc(datos, 'REM'); final int voF = _calc(datos, 'VOL');
          final int dF = _calc(datos, 'DEF'); final int cF = _calc(datos, 'CON'); final int fF = _calc(datos, 'FIS');
          final int mediaCalculada = ((vF + rF + voF + dF + cF + fF) / 6).round();
          
          final int ganados = datos['partidosGanados'] ?? 0;
          final int perdidos = datos['partidosPerdidos'] ?? 0;
          final int jugados = ganados + perdidos;
          final String efectividad = jugados > 0 ? '${((ganados / jugados) * 100).round()}%' : '0%';

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 100, left: 24.0, right: 24.0, bottom: 40.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                
                // --- 1. LA CARTA MINIATURA (Clickeable) ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.3))
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_out_map, color: Color(0xFFDFFF00), size: 14),
                      SizedBox(width: 8),
                      Text('TOCA TU CARTA PARA AMPLIAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDFFF00), letterSpacing: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                GestureDetector(
                  onTap: () => _abrirCartaGigante(context, datos, mediaCalculada, ganados, perdidos),
                  child: Container(
                    height: 280, 
                    decoration: BoxDecoration(
                      // Brillo sutil detrás de la carta
                      boxShadow: [BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.1), blurRadius: 40, spreadRadius: 5)]
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain, 
                      child: SizedBox(
                        width: 320, 
                        height: 450,
                        child: PadelPlayerCardWidget(
                          nombre: datos['apodo']?.toString().toUpperCase() ?? 'JUGADOR',
                          media: mediaCalculada,
                          categoriaLugar: '${datos['categoria'] ?? '8va'} / ${datos['posicion'] ?? 'DRIVE'}'.toUpperCase(),
                          vel: vF, rem: rF, vol: voF, def: dF, con: cF, fis: fF,
                          avatarUrl: datos['avatarUrl'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=${datos['apodo']}&backgroundColor=transparent',
                          partidosGanados: ganados,
                          partidosPerdidos: perdidos,
                          isTinderView: false,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // --- 2. BOTÓN DE EDICIÓN ---
                OutlinedButton.icon(
                  onPressed: () => _abrirEditorPerfil(context, datos),
                  icon: const Icon(Icons.edit, color: Color(0xFFDFFF00)),
                  label: const Text('EDITAR DATOS DE LA CARTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: const Color(0xFFDFFF00).withOpacity(0.5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 40),

                // --- 3. HISTORIAL DE TEMPORADA ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('RENDIMIENTO DE TEMPORADA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                ),
                const SizedBox(height: 15),

                // Grilla de Estadísticas Pro
                Row(
                  children: [
                    Expanded(child: _buildEstadisticaBox('PARTIDOS\nJUGADOS', '$jugados', Icons.sports_tennis)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildEstadisticaBox('VICTORIAS\nTOTALES', '$ganados', Icons.emoji_events, isHighlight: true)), 
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildEstadisticaBox('EFECTIVIDAD\n(WIN RATE)', efectividad, Icons.local_fire_department)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildEstadisticaBox('PUNTOS\nRANKING', '${datos['puntosTotales'] ?? 0}', Icons.military_tech)),
                  ],
                ),
                // 👇 ACÁ AGREGAMOS EL BOTÓN 👇
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchHistoryScreen()));
                  },
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text('VER HISTORIAL COMPLETO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ], // <-- Acá se cierra el children del Column
            ),
          );
        },
      ),
    );
  }

  // 👇 Widget Rediseñado: Cristal Oscuro y detalles Neon 👇
  Widget _buildEstadisticaBox(String titulo, String valor, IconData icono, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? const Color(0xFFDFFF00) : Colors.white.withOpacity(0.05), 
          width: isHighlight ? 1.5 : 1
        ),
        boxShadow: isHighlight 
            ? [BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))]
            : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: isHighlight ? const Color(0xFFDFFF00) : Colors.grey[400], size: 28),
          const SizedBox(height: 12),
          Text(valor, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
          const SizedBox(height: 8),
          Text(titulo, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.0)),
        ],
      ),
    );
  }
}