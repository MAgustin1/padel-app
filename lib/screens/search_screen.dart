import 'package:flutter/material.dart';
import '../widgets/player_card_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_details_screen.dart'; 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int _viewIndex = 0;

  // 👇 Variables para guardar tus datos personales en silencio
  Map<String, dynamic>? _misDatos;
  bool _cargandoMisDatos = true;
  final String miUid = FirebaseAuth.instance.currentUser!.uid;

  // 👇 NUEVO: Filtros para el Tinder de Padel
  String _tinderFiltroPosicion = 'Todas';
  String _tinderFiltroNivel = 'Todos';

  // 👇 Evita doble tap mientras se procesa un rechazo/paletazo
  bool _procesandoInteraccion = false;

  // 👇 Streams creados UNA sola vez (no en cada build()): tocar un filtro o
  // cambiar de pestaña solo dispara un setState del widget, no una
  // resuscripción + relectura completa de Firestore.
  late final Stream<QuerySnapshot> _streamPartidosAbiertos = FirebaseFirestore.instance
      .collection('partidos')
      .where('estado', isEqualTo: 'abierto')
      .where('esPublico', isEqualTo: true)
      .snapshots();

  // 👇 Cap duro de candidatos por costo: sin esto, el Tinder trae y sincroniza
  // en vivo TODA la colección de usuarios en cada apertura de la pantalla.
  late final Stream<QuerySnapshot> _streamUsuariosTinder =
      FirebaseFirestore.instance.collection('users').limit(200).snapshots();

  @override
  void initState() {
    super.initState();
    _cargarMisDatosSilencioso();
  }

  // Buscamos tus datos para saber tu edad, género y nivel
  Future<void> _cargarMisDatosSilencioso() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(miUid).get();
      if (doc.exists) {
        setState(() {
          _misDatos = doc.data();
          _cargandoMisDatos = false;
        });
      } else {
        setState(() => _cargandoMisDatos = false);
      }
    } catch (e) {
      print("Error cargando mis datos para filtros: $e");
      setState(() => _cargandoMisDatos = false);
    }
  }

  // --- LÓGICA SILENCIOSA ANTI-FRUSTRACIÓN PARA PARTIDOS ---
  bool _puedoJugarEstePartido(Map<String, dynamic> partido) {
    // 1. Si ya estoy anotado en el partido, no lo muestro acá (ya lo veo en el Home)
    List jugadores = partido['jugadoresActuales'] ?? [];
    if (jugadores.contains(miUid)) return false;

    // 2. Si no hay lugares en general, no lo muestro
    int lugares = partido['lugaresDisponibles'] ?? 0;
    if (lugares <= 0) return false;

    // Si por algún motivo no tengo mis datos cargados (error de internet), muestro todo por las dudas
    if (_misDatos == null) return true;

    // Mis datos reales (si no cargaste la edad, asumimos 25 para no dejarte afuera de todo)
    final String miGenero = _misDatos!['genero']?.toString() ?? 'Masculino';
    final int miEdad = _misDatos!['edad'] ?? 25; 
    
    // Reglas establecidas por el creador del partido
    final String generoReq = partido['generoReq'] ?? 'Mixto (Todos)';
    final String edadReq = partido['rangoEdadReq'] ?? 'Cualquier edad';

    // 3. 👇 FILTRO ESTRICTO DE GÉNERO PARA MIXTOS Y EXCLUSIVOS 👇
    if (generoReq == 'Mixto (Todos)') {
      // Si es Mixto, controlamos que queden cupos específicos para MI género
      if (miGenero.toLowerCase() == 'masculino') {
        int cuposMasc = partido['cuposMasculinos'] ?? 0;
        if (cuposMasc <= 0) return false; // Ya se llenó de hombres, te lo escondo.
      } else if (miGenero.toLowerCase() == 'femenino') {
        int cuposFem = partido['cuposFemeninos'] ?? 0;
        if (cuposFem <= 0) return false; // Ya se llenó de mujeres, te lo escondo.
      }
    } else {
      // Si el partido es Exclusivo (ej: solo Masculino o solo Femenino)
      if (generoReq.toLowerCase() != miGenero.toLowerCase()) {
        return false; // Es para otro género, lo escondemos.
      }
    }

    // 4. Filtro de Edad
    if (edadReq == 'Menores de 30' && miEdad >= 30) return false;
    if (edadReq == '30 a 45 años' && (miEdad < 30 || miEdad > 45)) return false;
    if (edadReq == 'Mayores de 45' && miEdad <= 45) return false;

    // ¡Pasaste todos los filtros! El partido es apto y tiene cupo real para vos.
    return true; 
  }

  // --- LÓGICA DE RECHAZO (TINDER) ---
  Future<void> _rechazarJugador(String idOtroJugador) async {
    if (_procesandoInteraccion) return;
    setState(() => _procesandoInteraccion = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(miUid).set({
        'interactuados': FieldValue.arrayUnion([idOtroJugador])
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error al rechazar: $e");
    } finally {
      if (mounted) setState(() => _procesandoInteraccion = false);
    }
  }

  // --- LÓGICA DE MATCH (TINDER DE PADEL) ---
  // 👇 Guardado con _procesandoInteraccion: si el usuario toca "paletazo" dos
  // veces seguidas antes de que el stream refleje el 'interactuados' recién
  // escrito, evitamos disparar la escritura (y el .add() no-idempotente de
  // 'paletazos') dos veces sobre la misma carta.
  Future<void> _darPaletazo(String idOtroJugador) async {
    if (_procesandoInteraccion) return;
    setState(() => _procesandoInteraccion = true);
    try {
      // 1. Lo anotamos como interactuado para que desaparezca del mazo
      await FirebaseFirestore.instance.collection('users').doc(miUid).set({
        'interactuados': FieldValue.arrayUnion([idOtroJugador])
      }, SetOptions(merge: true));

      // 2. Chequeamos si el otro ya nos había dado like
      final chequeoMatch = await FirebaseFirestore.instance
          .collection('paletazos')
          .where('de', isEqualTo: idOtroJugador)
          .where('para', isEqualTo: miUid)
          .get();

      if (chequeoMatch.docs.isNotEmpty) {
        // ¡MATCH MUTUO!
        await FirebaseFirestore.instance.collection('users').doc(miUid).update({
          'amigos': FieldValue.arrayUnion([idOtroJugador])
        });
        
        await FirebaseFirestore.instance.collection('users').doc(idOtroJugador).update({
          'amigos': FieldValue.arrayUnion([miUid])
        });

        // 👇 GATILLO: NOTIFICACIÓN DE NUEVO MATCH AL OTRO JUGADOR 👇
        final miApodo = _misDatos?['apodo']?.toString().toUpperCase() ?? 'UN JUGADOR';
        await _enviarNotificacionCampanita(
          idOtroJugador, 
          '¡HAY CONEXIÓN! ⚡', 
          '¡Hiciste match con $miApodo! Ya podés invitarlo a tus partidos.', 
          'match'
        );

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¡HAY CONEXIÓN! ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Image.asset('assets/images/icono_paleta.png', width: 24, height: 24, color: const Color(0xFFDFFF00)),
              ],
            ),
            content: const Text('¡Ya son amigos! Ahora podés invitarlo a tus partidos.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDFFF00), foregroundColor: Colors.black),
                child: const Text('¡Genial!'),
              )
            ],
          )
        );

      } else {
        // NO HAY MATCH TODAVÍA, DEJAMOS EL PALETAZO ASENTADO
        await FirebaseFirestore.instance.collection('paletazos').add({
          'de': miUid,
          'para': idOtroJugador,
          'fecha': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Paletazo enviado! Veremos si hay suerte.'),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 1),
          )
        );
      }
    } catch (e) {
      print("Error al dar paletazo: $e");
    } finally {
      if (mounted) setState(() => _procesandoInteraccion = false);
    }
  }

  Future<void> _notificarAlOrganizador(String idCreador, String nombreClub, String tipoAviso) async {
    try {
      // 1. Buscamos el apodo del usuario actual para saber quién se postula
      final miDoc = await FirebaseFirestore.instance.collection('users').doc(miUid).get();
      final miApodo = miDoc.data()?['apodo'] ?? 'Un jugador';

      String titulo = "";
      String mensaje = "";

      if (tipoAviso == 'solicitud') {
        titulo = "¡SOLICITUD DE UNIÓN! 🎾";
        mensaje = "$miApodo quiere sumarse a tu partido en $nombreClub. ¡Entrá a revisar su carta!";
      }

      // 2. Le creamos el documento en su campanita al organizador
      await FirebaseFirestore.instance
          .collection('users')
          .doc(idCreador) // ID del dueño del partido
          .collection('notificaciones')
          .add({
            'titulo': titulo,
            'mensaje': mensaje,
            'tipo': 'partido', // Icono de paleta
            'fecha': FieldValue.serverTimestamp(),
          });
          
      print("💾 Notificación enviada al creador del partido con éxito");
    } catch (e) {
      print("Error notificando al organizador: $e");
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
            'tipo': tipo, // 'match', 'partido', etc.
            'fecha': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error enviando notificación genérica: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A), 
      child: Column(
        children: [
          // --- 1. SELECTOR DE VISTA ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16), 
            color: Colors.transparent, // 👇 ACÁ ESTÁ LA MAGIA, CHAU PARCHE NEGRO 👇
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(value: 0, icon: Icon(Icons.sports_tennis), label: Text('Partidos Open', style: TextStyle(fontWeight: FontWeight.bold))),
                ButtonSegment<int>(value: 1, icon: Icon(Icons.people_alt), label: Text('Encontrar Pareja', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              selected: {_viewIndex},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() => _viewIndex = newSelection.first);
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.grey[400],
                selectedBackgroundColor: const Color(0xFFDFFF00),
                selectedForegroundColor: Colors.black,
                side: const BorderSide(color: Colors.transparent),
              ),
            ),
          ),

          // --- 2. CONTENIDO ---
          Expanded(
            child: _cargandoMisDatos
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)))
                : IndexedStack(
                    index: _viewIndex,
                    children: [
                      _buildMatchesListView(), 
                      _buildPeopleTinderView(), 
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // VISTA 0: LISTA DE PARTIDOS
  // =========================================
  Widget _buildMatchesListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _streamPartidosAbiertos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay partidos disponibles ahora.', style: TextStyle(color: Colors.grey)));
        }

        final partidosDisponibles = snapshot.data!.docs.where((doc) {
          final datos = doc.data() as Map<String, dynamic>;
          return _puedoJugarEstePartido(datos);
        }).toList();

        if (partidosDisponibles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text(
                'No encontramos partidos acordes a tu Edad y Género por ahora.\n¡Animate a crear el tuyo!', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.grey[500], fontSize: 16, height: 1.5)
              ),
            ),
          );
        }

        partidosDisponibles.sort((a, b) => (a['fechaHora'] as Timestamp).compareTo(b['fechaHora'] as Timestamp));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: partidosDisponibles.length,
          itemBuilder: (context, index) {
            final doc = partidosDisponibles[index];
            final datos = doc.data() as Map<String, dynamic>;
            
            final DateTime fecha = (datos['fechaHora'] as Timestamp).toDate();
            final String horaStr = "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}hs";
            final String diaStr = "${fecha.day}/${fecha.month}";
            
            final int ocupados = (datos['jugadoresActuales'] as List?)?.length ?? 0;
            final int lugaresDisponibles = (datos['lugaresDisponibles'] as num?)?.toInt() ?? 0;
            final List<bool> estadoJugadores = List.generate(4, (i) => i < ocupados);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              datos['club'].toString().toUpperCase(), 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            const SizedBox(height: 4),
                            Text("$diaStr - $horaStr", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.3))
                        ),
                        child: Text(
                          datos['categoriaReq'] ?? 'Sin categoría', 
                          style: const TextStyle(color: Color(0xFFDFFF00), fontSize: 14, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JUGADORES ($ocupados/4)', style: TextStyle(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(4, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  estadoJugadores[i] ? Icons.person : Icons.person_add_alt_1,
                                  size: 18,
                                  color: estadoJugadores[i] ? const Color(0xFFDFFF00) : Colors.grey[600],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      if (lugaresDisponibles > 0)
                        ElevatedButton(
                          onPressed: () async {
                            // 👇 GATILLO: Avisamos al creador que alguien está chusmeando o interesado en su partido 👇
                            final String idCreador = datos['creadorId'] ?? datos['organizadorId'] ?? '';
                            final String nombreClub = datos['club']?.toString().toUpperCase() ?? 'el club';
                            
                            if (idCreador.isNotEmpty && idCreador != miUid) {
                              // Ejecuta la notificación silenciosa en segundo plano
                              await _notificarAlOrganizador(idCreador, nombreClub, 'solicitud');
                            }

                            if (!context.mounted) return;
                            // Sigue su camino normal a la pantalla de detalles
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => MatchDetailsScreen(matchId: doc.id),
                            ));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDFFF00), 
                            foregroundColor: Colors.black, 
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0
                          ),
                          child: const Text('Ver Detalles', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================
  // VISTA 1: TINDER DE PERSONAS (CON FILTROS)
  // =========================================
  Widget _buildPeopleTinderView() {
    return Column(
      children: [
        // 👇 NUEVA BARRA DE FILTROS PARA EL TINDER 👇
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      value: _tinderFiltroPosicion,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFDFFF00), size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      // 👇 ACÁ ESTÁN TUS OPCIONES LIMPIAS 👇
                      items: ['Todas', 'Ambos', 'Revés', 'Drive'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          // Si es "Todas", muestra "Posición". Si no, muestra la opción elegida.
                          child: Text(value == 'Todas' ? 'Posición' : value), 
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() => _tinderFiltroPosicion = newValue!);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      value: _tinderFiltroNivel,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFDFFF00), size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      // 👇 OPCIONES DEL NIVEL 👇
                      items: ['Todos', 'Mi Nivel'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value == 'Todos' ? 'Nivel' : value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() => _tinderFiltroNivel = newValue!);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 👇 LAS CARTAS 👇
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _streamUsuariosTinder,
            builder: (context, snapshot) {
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('La cancha está vacía por ahora.', style: TextStyle(color: Colors.grey)));
              }

              final interactuados = _misDatos?['interactuados'] as List<dynamic>? ?? [];
              final miCategoria = _misDatos?['categoria']?.toString().toLowerCase() ?? '';

              // Filtramos la lista maestra con los nuevos filtros
              final jugadores = snapshot.data!.docs.where((doc) {
                if (doc.id == miUid) return false;
                if (interactuados.contains(doc.id)) return false;

                final data = doc.data() as Map<String, dynamic>? ?? {};
                final pos = data['posicion']?.toString().toLowerCase() ?? '';
                final cat = data['categoria']?.toString().toLowerCase() ?? '';

                // Filtro Posición (Actualizado para coincidir con las nuevas palabras)
                if (_tinderFiltroPosicion != 'Todas') {
                  if (pos != _tinderFiltroPosicion.toLowerCase() && pos != 'ambos') {
                    return false;
                  }
                }

                // Filtro Nivel
                if (_tinderFiltroNivel == 'Mi Nivel' && miCategoria.isNotEmpty) {
                  if (cat != miCategoria) {
                    return false;
                  }
                }

                return true;
              }).toList();

              if (jugadores.isEmpty) {
                return const Center(
                  child: Text('No hay jugadores que coincidan con tu búsqueda.\n¡Cambiá los filtros e intentá de nuevo!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                );
              }

              final jugadorActual = jugadores[0];
              final idActual = jugadorActual.id;

              return Column(
                children: [
                  const SizedBox(height: 10), 
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0), 
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Carta de fondo
                          if (jugadores.length > 1)
                            Transform.translate(
                              offset: const Offset(0, -20), 
                              child: Transform.scale(
                                scale: 0.95, 
                                child: Opacity(
                                  opacity: 0.4, 
                                  child: IgnorePointer( 
                                    child: AspectRatio(
                                      aspectRatio: 0.71, 
                                      child: _construirCarta(jugadores[1]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          
                          // Carta principal
                          AspectRatio(
                            aspectRatio: 0.71, 
                            child: _construirCarta(jugadorActual),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0, top: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        _buildTinderButton(
                          icon: Icons.close,
                          color: Colors.redAccent,
                          size: 65,
                          iconSize: 35,
                          onTap: _procesandoInteraccion ? null : () => _rechazarJugador(idActual),
                        ),
                        const SizedBox(width: 40),
                        _buildTinderButton(
                          imagePath: 'assets/images/icono_paleta.png',
                          color: const Color(0xFFDFFF00),
                          size: 65,
                          iconSize: 32,
                          onTap: _procesandoInteraccion ? null : () => _darPaletazo(idActual),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPER ---
  Widget _construirCarta(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return PadelPlayerCardWidget(
      nombre: data['apodo'] ?? data['nombre'] ?? 'Jugador',
      media: data['media'] ?? 50,
      categoriaLugar: "${data['categoria'] ?? 'Sin categoría'} / ${data['posicion'] ?? 'Drive'}",
      vel: data['vel'] ?? 50,
      rem: data['rem'] ?? 50,
      vol: data['vol'] ?? 50,
      def: data['def'] ?? 50,
      con: data['con'] ?? 50,
      fis: data['fis'] ?? 50,
      avatarUrl: data['avatarUrl'] ?? data['fotoPerfil'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=${doc.id}&backgroundColor=transparent',
      isTinderView: true,
      partidosGanados: data['partidosGanados'] ?? 0,
      partidosPerdidos: data['partidosPerdidos'] ?? 0,
    );
  }

  // --- BOTÓN ESTILO TINDER ---
  Widget _buildTinderButton({
    IconData? icon,
    String? imagePath,
    required Color color,
    required double size,
    required double iconSize,
    VoidCallback? onTap
  }) {
    final bool deshabilitado = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: deshabilitado ? 0.4 : 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 5))
            ],
          ),
          child: imagePath != null
              ? Center(
                  child: Image.asset(
                    imagePath,
                    width: iconSize,
                    height: iconSize,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}