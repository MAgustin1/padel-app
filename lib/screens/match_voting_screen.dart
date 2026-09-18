import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class MatchVotingScreen extends StatefulWidget {
  final String matchId;
  final List<dynamic> jugadoresActuales;

  const MatchVotingScreen({super.key, required this.matchId, required this.jugadoresActuales});

  @override
  State<MatchVotingScreen> createState() => _MatchVotingScreenState();
}

class _MatchVotingScreenState extends State<MatchVotingScreen> {
  final String miUid = FirebaseAuth.instance.currentUser!.uid;
  bool _estaCargando = true;
  bool _estaGuardando = false;
  
  List<Map<String, dynamic>> _otrosJugadores = [];
  int _indiceCartaActual = 0;

  // Las 6 stats originales de tu app
  final List<String> _listaStats = ['vel', 'rem', 'vol', 'def', 'con', 'fis'];
  final Map<String, String> _nombresStats = {
    'vel': '⚡ VELOCIDAD',
    'rem': '🔥 REMATE',
    'vol': '🏓 VOLEA',
    'def': '🛡️ DEFENSA',
    'con': '🎯 CONTROL',
    'fis': '🏃 FÍSICO'
  };

  // Guardamos qué stat aleatorio le tocó a cada jugador y qué voto elegiste (-1, 0 o 1)
  final Map<String, String> _statAsignadoPorJugador = {};
  final Map<String, int> _votosElegidos = {};

  @override
  void initState() {
    super.initState();
    _prepararCartasArcade();
  }

  Future<void> _prepararCartasArcade() async {
    final List<Map<String, dynamic>> temporales = [];
    final random = math.Random();

    for (String uid in widget.jugadoresActuales) {
      if (uid != miUid) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            temporales.add({'uid': uid, ...doc.data()!});
            
            // Ruleta: Elegimos un stat al azar de los 6 para este jugador
            String statAleatorio = _listaStats[random.nextInt(_listaStats.length)];
            _statAsignadoPorJugador[uid] = statAleatorio;
            _votosElegidos[uid] = 0; // Por defecto arranca en "=" (0)
          }
        } catch (e) {
          print("Error cargando jugador para arcade: $e");
        }
      }
    }

    setState(() {
      _otrosJugadores = temporales;
      _estaCargando = false;
    });
  }

  // 👇 SISTEMA ANTI-ADULTERACIÓN (Rendimientos Decrecientes) 👇
  Future<double> _calcularPesoDelVoto(String uidDestino) async {
    final sieteDiasAtras = DateTime.now().subtract(const Duration(days: 7));
    int partidosJuntosEstaSemana = 0;

    try {
      final query = await FirebaseFirestore.instance
          .collection('partidos')
          .where('estado', isEqualTo: 'finalizado')
          .where('jugadoresActuales', arrayContains: miUid)
          .get();

      for (var doc in query.docs) {
        final pData = doc.data();
        final List jugadores = pData['jugadoresActuales'] ?? [];
        final DateTime fechaPartido = (pData['fechaHora'] as Timestamp).toDate();

        if (jugadores.contains(uidDestino) && fechaPartido.isAfter(sieteDiasAtras)) {
          partidosJuntosEstaSemana++;
        }
      }
    } catch (e) {
      print("Error en chequeo anti-cheat: $e");
    }

    if (partidosJuntosEstaSemana < 3) {
      return 1.0; 
    } else {
      return 1.0 / math.pow(2, partidosJuntosEstaSemana - 2);
    }
  }

  Future<void> _procesarYEnviarVotos() async {
    setState(() => _estaGuardando = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var jugador in _otrosJugadores) {
        final String uidDestino = jugador['uid'];
        final String statAfectado = _statAsignadoPorJugador[uidDestino]!;
        final int votoPresionado = _votosElegidos[uidDestino]!;

        // 1. Calculamos el peso anti-trampa
        double pesoAntiCheat = await _calcularPesoDelVoto(uidDestino);
        double ajusteReal = votoPresionado * pesoAntiCheat;

        // 2. Recuperamos los valores históricos de las 6 stats
        int cantidadVotos = jugador['cantidadVotosStats'] ?? 1;
        
        Map<String, double> nuevosAcumulados = {};
        Map<String, int> nuevosPromedios = {};

        // 3. Procesamos cada stat
        for (String stat in _listaStats) {
          int valorActual = jugador[stat] ?? 50;
          double acumuladoHistorico = jugador['acumulado_$stat'] ?? (valorActual * cantidadVotos).toDouble();
          
          // Si es el stat que tocó calificar, le sumamos el ajuste
          double valorPartido = valorActual.toDouble();
          if (stat == statAfectado) {
            valorPartido += ajusteReal;
          }

          double nuevoAcumulado = acumuladoHistorico + valorPartido;
          int nuevoPromedio = (nuevoAcumulado / (cantidadVotos + 1)).round().clamp(1, 99);

          nuevosAcumulados['acumulado_$stat'] = nuevoAcumulado;
          nuevosPromedios[stat] = nuevoPromedio;
        }

        // 4. Calculamos la Media General
        int sumaTotalStats = nuevosPromedios.values.reduce((a, b) => a + b);
        int nuevaMediaGeneral = (sumaTotalStats / 6).round().clamp(1, 99);

        // 5. Preparamos la actualización para Firebase
        final docRef = FirebaseFirestore.instance.collection('users').doc(uidDestino);
        
        Map<String, dynamic> datosAActualizar = {
          'cantidadVotosStats': cantidadVotos + 1,
          'media': nuevaMediaGeneral, // Tu variable original de media
        };
        datosAActualizar.addAll(nuevosAcumulados);
        datosAActualizar.addAll(nuevosPromedios);

        batch.update(docRef, datosAActualizar);
      }

      // Dejamos asentado que ya voté
      batch.update(FirebaseFirestore.instance.collection('partidos').doc(widget.matchId), {
        'votaron': FieldValue.arrayUnion([miUid])
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Votación completada! Cartas actualizadas con éxito.'), backgroundColor: Colors.green));
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      print("Error en guardado Arcade: $e");
      setState(() => _estaGuardando = false);
    }
  }

  void _registrarVotoYSiguiente(int valorVoto) {
    final jugadorActual = _otrosJugadores[_indiceCartaActual];
    _votosElegidos[jugadorActual['uid']] = valorVoto;

    if (_indiceCartaActual < _otrosJugadores.length - 1) {
      setState(() => _indiceCartaActual++);
    } else {
      _procesarYEnviarVotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estaCargando) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00))),
      );
    }

    final jugador = _otrosJugadores[_indiceCartaActual];
    final uid = jugador['uid'];
    final statAsignada = _statAsignadoPorJugador[uid]!;
    final nombreStatFormateado = _nombresStats[statAsignada]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('EVALUAR ${_indiceCartaActual + 1}/${_otrosJugadores.length}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0A0A0A),
        automaticallyImplyLeading: false, 
        centerTitle: true,
        elevation: 0,
      ),
      body: _estaGuardando 
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFDFFF00)),
              SizedBox(height: 20),
              Text('Calculando promedios y aplicando filtros anti-trampa...', style: TextStyle(color: Colors.grey, fontSize: 13))
            ],
          ))
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))
                      ]
                    ),
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white12,
                          backgroundImage: NetworkImage(jugador['avatarUrl'] ?? jugador['fotoPerfil'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=$uid&backgroundColor=transparent'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          jugador['apodo']?.toString().toUpperCase() ?? jugador['nombre']?.toString().toUpperCase() ?? 'JUGADOR', 
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                        ),
                        Text('Media general: ${jugador['media'] ?? 50}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Divider(color: Colors.white12, height: 1),
                        ),
                        
                        const Text('¿CÓMO ESTUVO HOY SU...', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Text(
                            nombreStatFormateado, 
                            style: const TextStyle(color: Color(0xFFDFFF00), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildArcadeButton(
                      icono: Icons.arrow_downward,
                      colorFondo: Colors.redAccent.withOpacity(0.15),
                      colorIcono: Colors.redAccent,
                      onTap: () => _registrarVotoYSiguiente(-1),
                    ),
                    _buildArcadeButton(
                      icono: Icons.drag_handle,
                      colorFondo: Colors.amber.withOpacity(0.15),
                      colorIcono: Colors.amber,
                      onTap: () => _registrarVotoYSiguiente(0),
                    ),
                    _buildArcadeButton(
                      icono: Icons.arrow_upward,
                      colorFondo: const Color(0xFFDFFF00).withOpacity(0.15),
                      colorIcono: const Color(0xFFDFFF00),
                      onTap: () => _registrarVotoYSiguiente(1),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildArcadeButton({required IconData icono, required Color colorFondo, required Color colorIcono, required VoidCallback onTap}) {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: colorFondo,
        shape: BoxShape.circle,
        border: Border.all(color: colorIcono.withOpacity(0.4), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icono, color: colorIcono, size: 32),
        ),
      ),
    );
  }
}