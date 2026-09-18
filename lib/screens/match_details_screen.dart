import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_result_screen.dart';
import 'match_voting_screen.dart'; 

class MatchDetailsScreen extends StatefulWidget {
  final String matchId; 

  const MatchDetailsScreen({super.key, required this.matchId});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  bool _estaProcesando = false;
  Map<String, dynamic>? _misDatos;

  @override
  void initState() {
    super.initState();
    _cargarMisDatos();
  }

  Future<void> _cargarMisDatos() async {
    final String miUid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(miUid).get();
      if (doc.exists) {
        setState(() => _misDatos = doc.data());
      }
    } catch (e) {
      print("Error cargando mis datos: $e");
    }
  }

  // 👇 FUNCIÓN GENÉRICA PARA ENVIAR AVISOS A LA CAMPANITA 👇
  Future<void> _enviarNotificacionCampanita(String uidDestino, String titulo, String mensaje, String tipo) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uidDestino)
          .collection('notificaciones')
          .add({
            'titulo': titulo,
            'mensaje': mensaje,
            'tipo': tipo,
            'fecha': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error enviando notificación genérica: $e");
    }
  }

  // 👇 NUEVA FUNCIÓN: MENÚ DESLIZABLE PARA INVITAR AMIGOS 👇
  void _abrirMenuInvitarAmigos(String nombreClub, String fechaStr, String horaStr) {
    final amigos = _misDatos?['amigos'] as List<dynamic>? ?? [];

    if (amigos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tenés matches todavía. ¡Andá a "Encontrar Pareja" para hacer amigos!'), backgroundColor: Colors.orangeAccent)
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('INVITAR A TUS MATCHES', style: TextStyle(color: Color(0xFFDFFF00), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Divider(color: Colors.white12, height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: amigos.length,
                  itemBuilder: (context, index) {
                    final amigoId = amigos[index];
                    
                    // Buscamos los datos del amigo en tiempo real
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(amigoId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00))));
                        
                        final amigoData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final nombre = amigoData['apodo'] ?? amigoData['nombre'] ?? 'Jugador';
                        final avatar = amigoData['avatarUrl'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=$amigoId&backgroundColor=transparent';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.white12,
                            backgroundImage: NetworkImage(avatar),
                          ),
                          title: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              // Mandamos la notificación a la campanita del amigo
                              await _enviarNotificacionCampanita(
                                amigoId,
                                '¡TE INVITARON A JUGAR! 🎾',
                                'Te invitaron a un partido en $nombreClub el $fechaStr a las $horaStr. ¡Buscá el partido y sumate!',
                                'partido'
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context); // Cierra el menú
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitación enviada a $nombre'), backgroundColor: Colors.green));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDFFF00), 
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0
                            ),
                            child: const Text('Invitar', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String miUid = FirebaseAuth.instance.currentUser!.uid;
    // 👇 Esto lee el espacio de los botones de Android para empujar el contenido hacia arriba
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        title: const Text('DETALLES DEL PARTIDO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0A0A0A), 
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidos').doc(widget.matchId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('El partido ya no existe o fue cancelado.', style: TextStyle(color: Colors.grey)));
          }

          final datos = snapshot.data!.data() as Map<String, dynamic>;
          
          final String creadorId = datos['creadorId'] ?? '';
          final bool soyCreador = creadorId == miUid;
          final String estado = datos['estado']?.toString().toLowerCase() ?? 'abierto'; 
          final List jugadoresActuales = datos['jugadoresActuales'] as List? ?? []; 
          final int cantidadJugadores = jugadoresActuales.length;
          
          final DateTime fecha = (datos['fechaHora'] as Timestamp).toDate();
          final String horaStr = "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}hs";
          final String fechaStr = "${fecha.day}/${fecha.month}/${fecha.year}";

          final String genero = datos['generoReq'] ?? 'Mixto (Todos)';
          final String edad = datos['rangoEdadReq'] ?? 'Cualquier edad';
          final String tipo = datos['tipoPartido'] ?? 'Competitivo (Suma Puntos)';
          final String club = datos['club']?.toString().toUpperCase() ?? 'LA CANCHA';

          return SingleChildScrollView(
            // 👇 ACÁ ESTÁ LA SOLUCIÓN AL BOTÓN TAPADO: le sumamos el bottomPadding
            padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 20.0 + bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- TARJETA PRINCIPAL: Info de Cancha ---
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                    ]
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFFF00).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sports_tennis, size: 40, color: Color(0xFFDFFF00)),
                      ),
                      const SizedBox(height: 16),
                      Text(club, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.5))
                        ),
                        child: Text(datos['categoriaReq'] ?? 'Sin categoría', style: const TextStyle(fontSize: 14, color: Color(0xFFDFFF00), fontWeight: FontWeight.bold)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
                              const SizedBox(height: 6),
                              Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.white12),
                          Column(
                            children: [
                              const Icon(Icons.access_time, color: Colors.grey, size: 20),
                              const SizedBox(height: 6),
                              Text(horaStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- SECCIÓN: FILTROS DEL PARTIDO ---
                const Text('FILTROS DEL PARTIDO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildFiltroRow(Icons.wc, 'Género', genero),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      _buildFiltroRow(Icons.cake, 'Edad', edad),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      _buildFiltroRow(Icons.local_fire_department, 'Tipo', tipo),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- SECCIÓN: JUGADORES ANOTADOS ---
                const Text('JUGADORES ANOTADOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Lugares disponibles:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Text('${4 - cantidadJugadores} de 4', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: soyCreador ? const Color(0xFFDFFF00).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: soyCreador ? const Color(0xFFDFFF00) : Colors.transparent)
                          ),
                          child: Icon(Icons.person, color: soyCreador ? const Color(0xFFDFFF00) : Colors.white),
                        ),
                        title: Text(soyCreador ? 'Vos (Organizador)' : 'Jugador Anotado', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(soyCreador ? 'Creador del partido' : 'Listo para jugar', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ),
                      
                      if (cantidadJugadores > 1)
                        ...List.generate(cantidadJugadores - 1, (index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          title: const Text('Compañero de Pádel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Listo para jugar', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- ACCIONES BOTONES DEPENDIENDO DE QUIÉN SOS ---
                
                // CASO A: EL PARTIDO ESTÁ ABIERTO Y LLENO -> EL CREADOR PUEDE CARGAR RESULTADO
                if (estado == 'abierto' && soyCreador && cantidadJugadores >= 4)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => MatchResultScreen(matchId: widget.matchId, jugadoresActuales: jugadoresActuales),
                      ));
                    },
                    icon: const Icon(Icons.scoreboard, color: Colors.black),
                    label: const Text('Cargar Resultado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDFFF00), 
                      foregroundColor: Colors.black, 
                      padding: const EdgeInsets.symmetric(vertical: 18), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0
                    ),
                  ),

                // CASO B: ESPERANDO CONFIRMACIÓN
                if (estado == 'esperando_confirmacion') ...[
                  if ((datos['equipoB'] as List<dynamic>?)?.contains(miUid) ?? false)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.05), 
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)), 
                        borderRadius: BorderRadius.circular(15)
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.gavel, color: Colors.cyanAccent, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'El Equipo A propuso el resultado:\n${datos['resultadoPropuesto']}', 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, height: 1.4)
                          ),
                          const SizedBox(height: 8),
                          Text('¿Es correcto?', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 20),
                          _estaProcesando
                            ? const CircularProgressIndicator(color: Colors.cyanAccent)
                            : ElevatedButton(
                                onPressed: () => _confirmarResultadoYRepartirPuntos(datos, club),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent, 
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                child: const Text('Confirmar y Repartir Puntos', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white12)
                      ),
                      child: const Center(
                        child: Text(
                          '⏳ Esperando a que los rivales validen el resultado...', 
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 14),
                          textAlign: TextAlign.center,
                        )
                      ),
                    ),
                ],

                // CASO C: ESTÁ ABIERTO Y NO ESTÁ LLENO
                if (estado == 'abierto' && cantidadJugadores < 4) ...[
                  _estaProcesando
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)))
                      : soyCreador
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // 👇 LLAMAMOS AL MENÚ MÁGICO 👇
                                    _abrirMenuInvitarAmigos(club, fechaStr, horaStr);
                                  },
                                  icon: const Icon(Icons.share, color: Color(0xFFDFFF00)),
                                  label: const Text('Invitar Amigos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDFFF00), 
                                    side: const BorderSide(color: Color(0xFFDFFF00)),
                                    padding: const EdgeInsets.symmetric(vertical: 18), 
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _cancelarPartido(),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Cancelar mi Partido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent.withOpacity(0.1), 
                                    foregroundColor: Colors.redAccent, 
                                    padding: const EdgeInsets.symmetric(vertical: 18), 
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: const BorderSide(color: Colors.redAccent)
                                    ),
                                    elevation: 0
                                  ),
                                ),
                              ],
                            )
                          : !jugadoresActuales.contains(miUid)
                              // 👇 EL USUARIO NO ES CREADOR Y NO ESTÁ ANOTADO -> SE PUEDE ANOTAR
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    final miGenero = _misDatos?['genero']?.toString().toLowerCase() ?? 'masculino';
                                    _anotarseAlPartido(miGenero);
                                  },
                                  icon: const Icon(Icons.add, color: Colors.black),
                                  label: const Text('Anotarme al Partido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDFFF00),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                )
                              // 👇 EL USUARIO YA ESTÁ ANOTADO -> SE PUEDE BAJAR
                              : ElevatedButton.icon(
                                  onPressed: () => _salirDelPartido(jugadoresActuales, creadorId, genero),
                                  icon: const Icon(Icons.exit_to_app),
                                  label: const Text('Bajarme del Partido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orangeAccent.withOpacity(0.1), 
                                    foregroundColor: Colors.orangeAccent, 
                                    padding: const EdgeInsets.symmetric(vertical: 18), 
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: const BorderSide(color: Colors.orangeAccent)
                                    ),
                                    elevation: 0
                                  ),
                                ),
                ],

                // CASO D: EL PARTIDO ESTÁ FINALIZADO -> ¡A VOTAR!
                if (estado == 'finalizado') ...[
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.25), blurRadius: 20, spreadRadius: 2)
                      ]
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(
                          builder: (context) => MatchVotingScreen(
                            matchId: widget.matchId,
                            jugadoresActuales: jugadoresActuales
                          ),
                        ));
                      },
                      icon: const Icon(Icons.star, color: Colors.black, size: 24),
                      label: const Text('EVALUAR JUGADORES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDFFF00), 
                        foregroundColor: Colors.black, 
                        padding: const EdgeInsets.symmetric(vertical: 20), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0
                      ),
                    ),
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET PARA LAS FILAS DE FILTROS ---
  Widget _buildFiltroRow(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icono, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // 👇 NUEVA FUNCIÓN: ANOTARSE AL PARTIDO CONTROLANDO CUPOS MIXTOS 👇
  Future<void> _anotarseAlPartido(String miGenero) async {
    setState(() => _estaProcesando = true);
    try {
      final String miUid = FirebaseAuth.instance.currentUser!.uid;

      final docPartido = await FirebaseFirestore.instance.collection('partidos').doc(widget.matchId).get();
      final datos = docPartido.data() as Map<String, dynamic>;
      final String generoReq = datos['generoReq'] ?? 'Mixto (Todos)';
      final String creadorId = datos['creadorId'] ?? '';

      final Map<String, dynamic> actualizaciones = {
        'jugadoresActuales': FieldValue.arrayUnion([miUid]),
        'lugaresDisponibles': FieldValue.increment(-1),
      };

      if (generoReq == 'Mixto (Todos)') {
        if (miGenero == 'masculino') {
          int actuales = datos['cuposMasculinos'] ?? 0;
          if (actuales <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya no quedan cupos para hombres en este partido mixto.'), backgroundColor: Colors.redAccent));
            setState(() => _estaProcesando = false);
            return;
          }
          actualizaciones['cuposMasculinos'] = FieldValue.increment(-1);
        } else if (miGenero == 'femenino') {
          int actuales = datos['cuposFemeninos'] ?? 0;
          if (actuales <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya no quedan cupos para mujeres en este partido mixto.'), backgroundColor: Colors.redAccent));
            setState(() => _estaProcesando = false);
            return;
          }
          actualizaciones['cuposFemeninos'] = FieldValue.increment(-1);
        }
      }

      await FirebaseFirestore.instance.collection('partidos').doc(widget.matchId).update(actualizaciones);

      // Gatillo: Avisarle al creador
      if (creadorId.isNotEmpty && creadorId != miUid) {
        await _enviarNotificacionCampanita(creadorId, '¡NUEVO JUGADOR! 🎾', 'Alguien se anotó a tu partido. ¡Revisá la lista!', 'partido');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Te anotaste al partido con éxito! 🎾'), backgroundColor: Color(0xFFDFFF00)));
      setState(() => _estaProcesando = false);
    } catch (e) {
      print("Error al anotarse: $e");
      setState(() => _estaProcesando = false);
    }
  }

  Future<void> _cancelarPartido() async {
    setState(() => _estaProcesando = true);
    try {
      await FirebaseFirestore.instance.collection('partidos').doc(widget.matchId).delete();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partido eliminado correctamente'), backgroundColor: Colors.redAccent));
      Navigator.pop(context);
    } catch (e) {
      print("Error al borrar: $e");
      setState(() => _estaProcesando = false);
    }
  }

  // 👇 ACTUALIZADA: REINTEGRA EL CUPO CUANDO ALGUIEN SE BAJA 👇
  Future<void> _salirDelPartido(List<dynamic> jugadores, String creadorId, String generoReq) async {
    setState(() => _estaProcesando = true);
    try {
      final String miUid = FirebaseAuth.instance.currentUser!.uid;
      final String miGenero = _misDatos?['genero']?.toString().toLowerCase() ?? 'masculino';

      final Map<String, dynamic> actualizaciones = {
        'jugadoresActuales': FieldValue.arrayRemove([miUid]),
        'lugaresDisponibles': FieldValue.increment(1),
      };

      if (generoReq == 'Mixto (Todos)') {
        if (miGenero == 'masculino') {
          actualizaciones['cuposMasculinos'] = FieldValue.increment(1);
        } else if (miGenero == 'femenino') {
          actualizaciones['cuposFemeninos'] = FieldValue.increment(1);
        }
      }

      await FirebaseFirestore.instance.collection('partidos').doc(widget.matchId).update(actualizaciones);

      if (creadorId.isNotEmpty && creadorId != miUid) {
        await _enviarNotificacionCampanita(creadorId, '¡BAJA EN TU PARTIDO! ⚠️', 'Un jugador se bajó de tu partido. Se liberó un cupo.', 'info');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Te bajaste del partido con éxito'), backgroundColor: Colors.orangeAccent));
      Navigator.pop(context);
    } catch (e) {
      print("Error al salir: $e");
      setState(() => _estaProcesando = false);
    }
  }

  Future<void> _confirmarResultadoYRepartirPuntos(Map<String, dynamic> datosPartido, String nombreClub) async {
    setState(() => _estaProcesando = true);
    try {
      final String resultado = datosPartido['resultadoPropuesto'];
      final List<dynamic> equipoA = datosPartido['equipoA'];
      final List<dynamic> equipoB = datosPartido['equipoB'];

      int ptsA = 0, ptsB = 0;
      int winA = 0, winB = 0;
      int lossA = 0, lossB = 0;

      if (resultado == '2-0') { ptsA = 3; winA = 1; ptsB = 0; lossB = 1; }
      else if (resultado == '2-1') { ptsA = 2; winA = 1; ptsB = 1; lossB = 1; }
      else if (resultado == '1-2') { ptsA = 1; lossA = 1; ptsB = 2; winB = 1; }
      else if (resultado == '0-2') { ptsA = 0; lossA = 1; ptsB = 3; winB = 1; }

      final batch = FirebaseFirestore.instance.batch();

      for (String uid in equipoA) {
        batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
          'puntosTotales': FieldValue.increment(ptsA),
          'partidosGanados': FieldValue.increment(winA),
          'partidosPerdidos': FieldValue.increment(lossA),
        });
        
        await _enviarNotificacionCampanita(uid, '¡PUNTOS REPARTIDOS! 🏆', 'El partido en $nombreClub finalizó. Sumaste +$ptsA pts. ¡Entrá a calificar a los jugadores!', 'partido');
      }

      for (String uid in equipoB) {
        batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
          'puntosTotales': FieldValue.increment(ptsB),
          'partidosGanados': FieldValue.increment(winB),
          'partidosPerdidos': FieldValue.increment(lossB),
        });
        
        await _enviarNotificacionCampanita(uid, '¡PUNTOS REPARTIDOS! 🏆', 'El partido en $nombreClub finalizó. Sumaste +$ptsB pts. ¡Entrá a calificar a los jugadores!', 'partido');
      }

      batch.update(FirebaseFirestore.instance.collection('partidos').doc(widget.matchId), {
        'estado': 'finalizado',
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Puntos repartidos con éxito!'), backgroundColor: Colors.green));
      Navigator.pop(context);

    } catch (e) {
      print("Error al repartir puntos: $e");
      setState(() => _estaProcesando = false);
    }
  }
}