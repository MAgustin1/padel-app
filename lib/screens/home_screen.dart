import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'create_match_screen.dart';
import 'user_profile_tab_screen.dart';
import 'inbox_screen.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_details_screen.dart';
import 'ranking_screen.dart';
import '../widgets/player_card_widget.dart';
import '../services/push_notification_service.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceSeleccionado = 0;
  
  String _apodoUsuario = 'Jugador';
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    // Prendemos el motor de notificaciones
    PushNotificationService.init();
    _cargarDatosUsuario(); 
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final String uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        setState(() {
          _apodoUsuario = doc.data()?['apodo'] ?? doc.data()?['nombre'] ?? 'Jugador'; 
          _estaCargando = false;
        });
      }
    } catch (e) {
      print("Error al cargar usuario: $e");
      setState(() => _estaCargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito Premium
      
      // --- APP BAR (Cabecera) ---
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, 
        title: const Row(
          children: [
            Icon(Icons.sports_tennis, size: 28, color: Color(0xFFDFFF00)), // Icono Flúor
            SizedBox(width: 8),
            Text('Padel Ultimate Play', style: TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()), // 👈 Apunta a la nueva pantalla
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false, 
              );
            },
          ),
        ],
      ),

      // --- CUERPO PRINCIPAL ---
      body: IndexedStack(
        index: _indiceSeleccionado,
        children: [
          _construirPestanaInicio(),    
          const SearchScreen(),          
          const InboxScreen(),           
          const UserProfileTabScreen(),  
        ],
      ),

      // --- BARRA DE NAVEGACIÓN INFERIOR ---
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, 
          backgroundColor: const Color(0xFF0A0A0A), // Fondo oscuro para el menú
          currentIndex: _indiceSeleccionado,
          onTap: (index) {
            setState(() {
              _indiceSeleccionado = index; 
            });
          },
          selectedItemColor: const Color(0xFFDFFF00), // Item activo en flúor
          unselectedItemColor: Colors.grey[600],
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outlined), label: 'Mensajes'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mi Perfil'),
          ],
        ),
      ),
    );
  }

  // --- DISEÑO DE LA PESTAÑA INICIO (REDISEÑADO CON PROFUNDIDAD) ---
  Widget _construirPestanaInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Saludo al jugador 
          if (_estaCargando)
             const SizedBox(
               height: 35, 
               child: Align(
                 alignment: Alignment.centerLeft, 
                 child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDFFF00))
               )
             )
          else
             Text('$_apodoUsuario! 👋', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          
          const Text('¿Listo para ir a la cancha?', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 30),

          // --- CARTA CENTRAL GIGANTE CON GLOW NEÓN ---
          Center(
            child: StreamBuilder<DocumentSnapshot>(
              // 1. Buscamos pura y exclusivamente TU documento usando tu UID
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                // Mientras carga tus datos de Firebase, mostramos un cargando facha
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00))),
                  );
                }

                // Si por algún motivo no hay datos tuyos guardados todavía
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text(
                    'Creá tu perfil para ver tu carta.',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                // Mapeamos tus datos reales de la base de datos
                final misDatos = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 20), // Le da aire arriba y abajo
                  decoration: BoxDecoration(
                    boxShadow: [
                      // El halo de luz brillante neón sutil
                      BoxShadow(
                        color: const Color(0xFFDFFF00).withOpacity(0.15), 
                        blurRadius: 40, 
                        spreadRadius: 2
                      )
                    ]
                  ),
                  child: SizedBox(
                    width: 135,  
                    height: 190, 
                    child: FittedBox(
                      fit: BoxFit.contain, // Escala proporcionalmente sin deformar
                      child: SizedBox(
                        width: 300,  
                        height: 422, // Mantiene la relación de aspecto 0.71
                        child: PadelPlayerCardWidget(
                          // 👇 CLAVE: Ahora busca en todas las posibles llaves de tu Base de Datos
                          nombre: misDatos['apodo'] ?? misDatos['nombre'] ?? 'Jugador',
                          media: misDatos['media'] ?? 50,
                          categoriaLugar: misDatos['categoria'] ?? misDatos['categoriaLugar'] ?? 'Sin categoría',
                          vel: misDatos['vel'] ?? 50,
                          rem: misDatos['rem'] ?? 50,
                          vol: misDatos['vol'] ?? 50,
                          def: misDatos['def'] ?? 50,
                          con: misDatos['con'] ?? 50,
                          fis: misDatos['fis'] ?? 50,
                          avatarUrl: misDatos['fotoPerfil'] ?? misDatos['fotoUrl'] ?? misDatos['avatarUrl'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=me&backgroundColor=transparent',
                          isTinderView: false, // Falso porque es tu perfil propio
                          partidosGanados: misDatos['partidosGanados'] ?? 0,
                          partidosPerdidos: misDatos['partidosPerdidos'] ?? 0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 35),

          // 2. Tarjetas de Acción Principales (Efecto Cristal Profundo)
          Row(
            children: [
              Expanded(
                child: _construirTarjetaNeon(
                  titulo: 'Crear\nPartido',
                  icono: Icons.add_circle,
                  isNeon: true, // Se pinta de flúor
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMatchScreen()));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _construirTarjetaNeon(
                  titulo: 'Ranking\nGlobal',
                  icono: Icons.emoji_events, 
                  isNeon: false, // Se pinta de cristal oscuro
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RankingScreen()));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // 3. Sección de "Próximos Partidos" 
          const Text('TUS PRÓXIMOS PARTIDOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('partidos')
                .where('jugadoresActuales', arrayContains: FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text('Todavía no estás anotado en ningún partido.', style: TextStyle(color: Colors.grey[500])),
                  ),
                );
              }

              var partidos = snapshot.data!.docs.where((doc) {
                final datos = doc.data() as Map<String, dynamic>;
                final String miUid = FirebaseAuth.instance.currentUser!.uid;
                
                bool estaFinalizado = datos['estado'] == 'finalizado';
                List votaron = datos['votaron'] ?? [];
                bool yaVote = votaron.contains(miUid);

                // Si el partido terminó y yo YA VOTÉ, lo ocultamos.
                if (estaFinalizado && yaVote) {
                  return false;
                }
                
                // Si está abierto, esperando confirmación, o finalizado pero NO voté, lo mostramos.
                return true;
              }).toList();

              if (partidos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text('No hay partidos próximos a la vista.', style: TextStyle(color: Colors.grey[500])),
                  ),
                );
              }

              partidos.sort((a, b) => (a['fechaHora'] as Timestamp).compareTo(b['fechaHora'] as Timestamp));
              final String miUid = FirebaseAuth.instance.currentUser!.uid;

              return Column(
                children: partidos.map((doc) {
                  final datos = doc.data() as Map<String, dynamic>;
                  final bool soyCreador = datos['creadorId'] == miUid;
                  
                  final DateTime fecha = (datos['fechaHora'] as Timestamp).toDate();
                  final String horaStr = "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}hs";
                  final String diaStr = "${fecha.day}/${fecha.month}";

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchDetailsScreen(matchId: doc.id),
                          ),
                        );
                      },
                      child: Container(
                        // Efecto Neón para las tarjetas de partidos
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: soyCreador 
                              ? Border.all(color: const Color(0xFFDFFF00).withOpacity(0.8), width: 1.5)
                              : Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                          boxShadow: soyCreador ? [
                            BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.15), blurRadius: 20, spreadRadius: 2)
                          ] : [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: soyCreador ? const Color(0xFFDFFF00).withOpacity(0.2) : Colors.white.withOpacity(0.05), 
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Icon(
                              soyCreador ? Icons.star : Icons.calendar_month, 
                              color: soyCreador ? const Color(0xFFDFFF00) : Colors.white,
                              size: 26,
                            ),
                          ),
                          title: Text(
                            '${datos['club']} - $horaStr ($diaStr)', 
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('Faltan ${datos['lugaresDisponibles']} jugadores • ${datos['categoriaReq']}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                              if (soyCreador) 
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDFFF00).withOpacity(0.1), 
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.5))
                                  ),
                                  child: const Text('Sos el Organizador', style: TextStyle(color: Color(0xFFDFFF00), fontSize: 11, fontWeight: FontWeight.w900)),
                                )
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- MOTOR DE BOTONES NEÓN CON PROFUNDIDAD ---
  Widget _construirTarjetaNeon({
    required String titulo, 
    required IconData icono, 
    required bool isNeon, 
    required VoidCallback onTap
  }) {
    // Definimos los colores dependiendo de si es la tarjeta flúor o la oscura
    final colorArriba = isNeon ? const Color(0xFFE8FF33) : const Color(0xFF2B3A4F);
    final colorAbajo = isNeon ? const Color(0xFFB3CC00) : const Color(0xFF0F172A);
    final colorTexto = isNeon ? Colors.black : Colors.white;
    final colorBorde = isNeon ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.15);
    final colorSombra = isNeon ? const Color(0xFFDFFF00).withOpacity(0.4) : const Color(0xFFDFFF00).withOpacity(0.05);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // El degradado simula la luz pegando desde arriba a la izquierda
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorArriba, colorAbajo],
          ),
          borderRadius: BorderRadius.circular(20),
          // Borde semitransparente para dar el efecto de "vidrio/plástico premium"
          border: Border.all(color: colorBorde, width: 2),
          boxShadow: [
            // Sombra brillante centrada para crear el aura de neón
            BoxShadow(
              color: colorSombra, 
              blurRadius: 25, 
              spreadRadius: 2,
              offset: const Offset(0, 0) // Centrada
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 40, color: colorTexto),
            const SizedBox(height: 20),
            Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorTexto, height: 1.2)),
          ],
        ),
      ),
    );
  }
}