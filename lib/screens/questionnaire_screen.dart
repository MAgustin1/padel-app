import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'profile_card_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player_model.dart';
import 'package:firebase_storage/firebase_storage.dart'; 

class QuestionnaireScreen extends StatefulWidget {
  final String nombre;
  final String apodo;
  final String categoria;
  // 👇 NUEVOS CAMPOS RECIBIDOS
  final String telefono;
  final DateTime fechaNacimiento;
  final String genero;
  final String posicion;
  final Uint8List? imagenBytes;

  const QuestionnaireScreen({
    super.key,
    required this.nombre,
    required this.apodo,
    required this.categoria,
    required this.telefono,
    required this.fechaNacimiento,
    required this.genero,
    required this.posicion,
    this.imagenBytes,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  // Variables de estadísticas
  double _vel1 = 3, _vel2 = 3;
  double _rem1 = 3, _rem2 = 3;
  double _vol1 = 3, _vol2 = 3;
  double _def1 = 3, _def2 = 3;
  double _con1 = 3, _con2 = 3;
  double _fis1 = 3, _fis2 = 3;

  bool _isGeneratingAI = false;

  final Map<String, List<int>> _rangos = {
    'Inicial': [40, 49], '8va': [50, 59], '7ma': [60, 65],
    '6ta': [66, 72], '5ta': [73, 79], '4ta': [80, 85],
    '3ra': [86, 89], '2da': [90, 94], '1ra': [95, 99],
  };

  int _calcularStat(double puntosPromedio, int min, int max) {
    return (min + (puntosPromedio - 1) * (max - min) / 4).round();
  }

  Future<void> _generarCarta() async {
    setState(() => _isGeneratingAI = true);

    // 1. Simulación de IA (lo que ya teníamos)
    await Future.delayed(const Duration(seconds: 3));
    String nombreFinal = widget.apodo.isNotEmpty ? widget.apodo : widget.nombre.split(' ')[0];
    String semilla = nombreFinal.replaceAll(' ', ''); 
    String urlAvatarIA = 'https://api.dicebear.com/9.x/micah/png?seed=$semilla&backgroundColor=transparent';

    final String tempUid = FirebaseAuth.instance.currentUser!.uid; 
    String urlAvatarFinal = urlAvatarIA; 

    // --- 👇 SUBIDA REAL A FIREBASE STORAGE 👇 ---
    if (widget.imagenBytes != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('avatars')
            .child('$tempUid.jpg');

        UploadTask uploadTask = storageRef.putData(widget.imagenBytes!);
        TaskSnapshot storageSnapshot = await uploadTask;

        urlAvatarFinal = await storageSnapshot.ref.getDownloadURL();
        print("✅ Foto de perfil subida a Firebase Storage con éxito: $urlAvatarFinal");
      } catch (e) {
        print("❌ Error al subir foto a Storage (usando fallback de IA): $e");
      }
    }
    // --- 👆 FIN SUBIDA A STORAGE 👆 ---

    // 2. Cálculo de Stats
    final rango = _rangos[widget.categoria] ?? [50, 59];
    int sVel = _calcularStat((_vel1 + _vel2) / 2, rango[0], rango[1]);
    int sRem = _calcularStat((_rem1 + _rem2) / 2, rango[0], rango[1]);
    int sVol = _calcularStat((_vol1 + _vol2) / 2, rango[0], rango[1]);
    int sDef = _calcularStat((_def1 + _def2) / 2, rango[0], rango[1]);
    int sCon = _calcularStat((_con1 + _con2) / 2, rango[0], rango[1]);
    int sFis = _calcularStat((_fis1 + _fis2) / 2, rango[0], rango[1]);
    int mediaFinal = ((sVel + sRem + sVol + sDef + sCon + sFis) / 6).round();

    try {
      // Guardamos en el modelo usando la urlAvatarFinal 
      PlayerModel nuevoJugador = PlayerModel(
        uid: tempUid,
        nombre: widget.nombre,
        apodo: widget.apodo,
        categoria: widget.categoria,
        posicion: widget.posicion, // 👈 Ahora usa la que vos elegiste
        media: mediaFinal,
        avatarUrl: urlAvatarFinal, 
        stats: {
          'VEL': sVel, 'REM': sRem, 'VOL': sVol,
          'DEF': sDef, 'CON': sCon, 'FIS': sFis,
        },
      );

      // Convertimos a Map y LE AGREGAMOS LOS DATOS NUEVOS
      Map<String, dynamic> datosParaFirestore = nuevoJugador.toMap();
      datosParaFirestore['telefono'] = widget.telefono;
      datosParaFirestore['fechaNacimiento'] = Timestamp.fromDate(widget.fechaNacimiento);
      datosParaFirestore['genero'] = widget.genero;

      // Guardamos en la colección "users" de Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(tempUid)
          .set(datosParaFirestore);

      print("✅ Jugador guardado con éxito en Firebase");

    } catch (e) {
      print("❌ Error al guardar en base de datos: $e");
    }

    setState(() => _isGeneratingAI = false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileCardScreen(
          nombre: nombreFinal.toUpperCase(),
          media: mediaFinal,
          vel: sVel, rem: sRem, vol: sVol,
          def: sDef, con: sCon, fis: sFis,
          avatarUrl: urlAvatarFinal, 
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TEST DE HABILIDADES', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 110, left: 24.0, right: 24.0, bottom: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // --- CATEGORÍA SELECCIONADA ---
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.5)),
                    ),
                    child: Text(
                      'CATEGORÍA: ${widget.categoria.toUpperCase()}', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFDFFF00), letterSpacing: 1)
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sé honesto con tus respuestas para que la media refleje tu nivel real en la cancha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 30),

                // --- TARJETAS DE HABILIDADES ---
                _buildSkillCard('VELOCIDAD', Icons.bolt, 
                  'Arranque explosivo', _vel1, (v) => setState(() => _vel1 = v),
                  'Recuperación atrás', _vel2, (v) => setState(() => _vel2 = v)
                ),
                _buildSkillCard('REMATE', Icons.local_fire_department, 
                  'Potencia bruta', _rem1, (v) => setState(() => _rem1 = v),
                  'Técnica de Rulo/Víbora', _rem2, (v) => setState(() => _rem2 = v)
                ),
                _buildSkillCard('VOLEA', Icons.sports_tennis, 
                  'Reflejos en choque', _vol1, (v) => setState(() => _vol1 = v),
                  'Profundidad de volea', _vol2, (v) => setState(() => _vol2 = v)
                ),
                _buildSkillCard('DEFENSA', Icons.shield, 
                  'Salida de pared', _def1, (v) => setState(() => _def1 = v),
                  'Calidad de globos', _def2, (v) => setState(() => _def2 = v)
                ),
                _buildSkillCard('CONTROL', Icons.track_changes, 
                  'Chiquitas a los pies', _con1, (v) => setState(() => _con1 = v),
                  'Consistencia (no errar)', _con2, (v) => setState(() => _con2 = v)
                ),
                _buildSkillCard('FÍSICO', Icons.fitness_center, 
                  'Resistencia a 3 sets', _fis1, (v) => setState(() => _fis1 = v),
                  'Agilidad de piernas', _fis2, (v) => setState(() => _fis2 = v)
                ),
                
                const SizedBox(height: 40),
                
                // --- BOTÓN DE GENERACIÓN MAGICA ---
                Container(
                  decoration: BoxDecoration(
                    boxShadow: _isGeneratingAI ? [] : [
                      BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))
                    ]
                  ),
                  child: ElevatedButton(
                    onPressed: _isGeneratingAI ? null : _generarCarta,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18), 
                      backgroundColor: const Color(0xFFDFFF00), 
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[800],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                    child: const Text('Generar Carta con IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),

          // --- PANTALLA DE CARGA (Overlay) ---
          if (_isGeneratingAI)
            Container(
              color: const Color(0xFF0F172A).withOpacity(0.9), // Fondo oscuro con blur
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFDFFF00)),
                    const SizedBox(height: 24),
                    const Text(
                      'La IA está calculando\ntus estadísticas...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Forjando tu carta Oro...',
                      style: TextStyle(color: const Color(0xFFDFFF00).withOpacity(0.8), fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGET AUXILIAR REDISEÑADO: TARJETAS DE SKILLS ---
  Widget _buildSkillCard(String titulo, IconData icono, String preg1, double val1, Function(double) onCh1, String preg2, double val2, Function(double) onCh2) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Tarjeta oscura
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: const Color(0xFFDFFF00), size: 24),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white12, height: 1),
          ),
          _buildSliderPremium(preg1, val1, onCh1),
          const SizedBox(height: 15),
          _buildSliderPremium(preg2, val2, onCh2),
        ],
      ),
    );
  }

  // --- WIDGET AUXILIAR REDISEÑADO: SLIDER FLÚOR ---
  Widget _buildSliderPremium(String pregunta, double valor, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(pregunta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[300])),
            Text(valor.round().toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00))),
          ],
        ),
        const SizedBox(height: 5),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFDFFF00),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: const Color(0xFFDFFF00),
            overlayColor: const Color(0xFFDFFF00).withOpacity(0.2),
            trackHeight: 6.0,
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3.0),
            activeTickMarkColor: Colors.black26,
            inactiveTickMarkColor: Colors.white24,
          ),
          child: Slider(
            value: valor, 
            min: 1, 
            max: 5, 
            divisions: 4, 
            onChanged: onChanged
          ),
        ),
      ],
    );
  }
}