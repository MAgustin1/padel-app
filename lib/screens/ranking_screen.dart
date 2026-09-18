import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/player_card_widget.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

// 👇 Firestore no fuerza tipos: un campo numérico puede llegar como int o
// double según cómo se haya escrito. Normalizamos siempre a int acá en vez
// de castear directo, para que un solo documento con el tipo "raro" no
// tire abajo el ranking para todos los usuarios.
int _asInt(dynamic valor, [int porDefecto = 0]) {
  if (valor is num) return valor.toInt();
  return porDefecto;
}

class _RankingScreenState extends State<RankingScreen> {
  // Filtros
  String _filtroCategoria = 'Todas';
  String _filtroTiempo = 'Total'; // Lo dejamos en Total por ahora para que coincida con puntosTotales
  
  final List<String> _categorias = ['Todas', '1ra', '2da', '3ra', '4ta', '5ta', '6ta', '7ma', '8va'];
  // Desactivamos el filtro de tiempo complejo hasta que la base de datos soporte historial por fechas
  final List<String> _tiempos = ['Puntuación Global'];

  // 👇 Creado UNA sola vez: tocar un chip de categoría hace un setState del
  // widget, pero ya no recrea (ni resuscribe) el stream de Firestore.
  late final Stream<QuerySnapshot> _streamUsuarios = FirebaseFirestore.instance.collection('users').snapshots();

  // --- FUNCIÓN PARA MOSTRAR EL POP-UP DE LA CARTA (Lógica Intacta) ---
  void _mostrarCartaJugador(BuildContext context, Map<String, dynamic> jugador) {
    final String categoriaStr = jugador['categoria']?.toString() ?? jugador['categoriaLugar']?.toString() ?? '8va';
    
    // Obtenemos las stats base de la DB, o usamos 50 por defecto
    final int velDb = _asInt(jugador['vel'], 50);
    final int remDb = _asInt(jugador['rem'], 50);
    final int volDb = _asInt(jugador['vol'], 50);
    final int defDb = _asInt(jugador['def'], 50);
    final int conDb = _asInt(jugador['con'], 50);
    final int fisDb = _asInt(jugador['fis'], 50);

    int base = 50;
    String cat = categoriaStr.toLowerCase();
    if (cat.contains('1ra') || cat.contains('primera')) base = 92;
    else if (cat.contains('2da') || cat.contains('segunda')) base = 88;
    else if (cat.contains('3ra') || cat.contains('tercera')) base = 84;
    else if (cat.contains('4ta') || cat.contains('cuarta')) base = 78;
    else if (cat.contains('5ta') || cat.contains('quinta')) base = 73;
    else if (cat.contains('6ta') || cat.contains('sexta')) base = 67;
    else if (cat.contains('7ma') || cat.contains('septima')) base = 60;
    else base = 50;

    int sumarBonus(int stat) {
      int finalStat = base + (stat * 0.12).round();
      return finalStat > 99 ? 99 : finalStat;
    }

    final int velF = sumarBonus(velDb);
    final int remF = sumarBonus(remDb);
    final int volF = sumarBonus(volDb);
    final int defF = sumarBonus(defDb);
    final int conF = sumarBonus(conDb);
    final int fisF = sumarBonus(fisDb);

    final int mediaCalculada = ((velF + remF + volF + defF + conF + fisF) / 6).round();

    final String apodo = jugador['apodo']?.toString().toUpperCase() ?? jugador['nombre']?.toString().toUpperCase() ?? 'JUGADOR';
    final String avatar = jugador['avatarUrl'] ?? jugador['fotoPerfil'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=$apodo&backgroundColor=transparent';

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
                height: 400,
                width: 300,
                child: PadelPlayerCardWidget(
                  nombre: apodo,
                  media: mediaCalculada,
                  categoriaLugar: '$categoriaStr / DRIVE'.toUpperCase(),
                  vel: velF, rem: remF, vol: volF, def: defF, con: conF, fis: fisF,
                  avatarUrl: avatar,
                  isTinderView: false,
                  partidosGanados: jugador['partidosGanados'] ?? 0,
                  partidosPerdidos: jugador['partidosPerdidos'] ?? 0,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito Premium
      appBar: AppBar(
        title: const Text('LIGA COMPETITIVA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- 1. FILTROS DE TIEMPO (Simplificado a Global por ahora) ---
          Container(
            width: double.infinity,
            color: const Color(0xFF0A0A0A), 
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), 
            child: SegmentedButton<String>(
              showSelectedIcon: false, 
              segments: _tiempos.map((t) => ButtonSegment(
                value: t, 
                label: FittedBox( 
                  fit: BoxFit.scaleDown,
                  child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              )).toList(),
              selected: {_filtroTiempo},
              onSelectionChanged: (Set<String> newSelection) {},
              style: SegmentedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B), 
                foregroundColor: Colors.grey[400], 
                selectedBackgroundColor: const Color(0xFFDFFF00), 
                selectedForegroundColor: Colors.black, 
                side: const BorderSide(color: Colors.transparent),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), 
              ),
            ),
          ),

          // --- 2. FILTROS DE CATEGORÍA ---
          Container(
            height: 60,
            color: const Color(0xFF0A0A0A),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final isSelected = _filtroCategoria == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFDFFF00), 
                    backgroundColor: const Color(0xFF1E293B), 
                    showCheckmark: false, 
                    side: BorderSide(color: isSelected ? const Color(0xFFDFFF00) : Colors.transparent),
                    onSelected: (selected) {
                      if (selected) setState(() => _filtroCategoria = cat);
                    },
                  ),
                );
              },
            ),
          ),
          
          // Divisor sutil
          Container(height: 1, color: Colors.white.withOpacity(0.05)),

          // --- 3. LISTA DEL RANKING POR PUNTOS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _streamUsuarios,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Todavía no hay jugadores en la liga.', style: TextStyle(color: Colors.grey)));
                }

                // 1. Mapeamos y aseguramos que tengan puntosTotales
                List<Map<String, dynamic>> jugadores = snapshot.data!.docs.map((doc) {
                  final datos = doc.data() as Map<String, dynamic>;
                  datos['puntos_ranking'] = _asInt(datos['puntosTotales']);
                  return datos;
                }).toList();

                // 2. Filtramos por categoría (A prueba de balas)
                if (_filtroCategoria != 'Todas') {
                  jugadores = jugadores.where((j) {
                    final categoriaDb = (j['categoria'] ?? j['categoriaLugar'] ?? '').toString().toLowerCase();
                    return categoriaDb.contains(_filtroCategoria.toLowerCase());
                  }).toList();
                }

                // 3. Ordenamos del que tiene MÁS puntos al que tiene MENOS
                jugadores.sort((a, b) => (b['puntos_ranking'] as int).compareTo(a['puntos_ranking'] as int));

                if (jugadores.isEmpty) {
                  return const Center(child: Text('No hay jugadores en esta categoría.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: jugadores.length,
                  itemBuilder: (context, index) {
                    final jugador = jugadores[index];
                    final int posicion = index + 1;
                    
                    final String apodo = jugador['apodo']?.toString().toUpperCase() ?? jugador['nombre']?.toString().toUpperCase() ?? 'JUGADOR';
                    final String categoria = jugador['categoria']?.toString().toUpperCase() ?? jugador['categoriaLugar']?.toString().toUpperCase() ?? '8VA';
                    final int puntos = jugador['puntos_ranking'];
                    final String avatar = jugador['avatarUrl'] ?? jugador['fotoPerfil'] ?? 'https://api.dicebear.com/9.x/micah/png?seed=$apodo&backgroundColor=transparent';

                    // 👇 MAGIA DEL PODIO VIP 👇
                    Color colorBorde = Colors.white12;
                    Color colorPuntos = const Color(0xFFDFFF00);
                    Widget? medalla;

                    if (posicion == 1) { 
                      colorBorde = const Color(0xFFFFD700); // ORO
                      colorPuntos = const Color(0xFFFFD700);
                      medalla = const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 20);
                    } else if (posicion == 2) { 
                      colorBorde = const Color(0xFFC0C0C0); // PLATA
                      colorPuntos = const Color(0xFFC0C0C0);
                      medalla = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0), size: 20);
                    } else if (posicion == 3) { 
                      colorBorde = const Color(0xFFCD7F32); // BRONCE
                      colorPuntos = const Color(0xFFCD7F32);
                      medalla = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32), size: 20);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), // Fondo tarjeta oscuro
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorBorde, width: posicion <= 3 ? 1.5 : 1),
                        boxShadow: posicion == 1 ? [
                          BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.15), blurRadius: 20, spreadRadius: 2)
                        ] : [], // Brillo especial solo para el Rey del ranking
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 35,
                              child: Text(
                                '#$posicion', 
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w900, 
                                  color: posicion <= 3 ? colorBorde : Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _mostrarCartaJugador(context, jugador),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage: NetworkImage(avatar),
                                  ),
                                  if (medalla != null)
                                    Container(
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0F172A)),
                                      child: medalla,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        title: Text(apodo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        subtitle: Text(categoria, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min, 
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('PTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            Text(
                              '$puntos', 
                              style: TextStyle(
                                color: colorPuntos, 
                                fontWeight: FontWeight.w900, 
                                fontSize: 24, 
                                height: 1.0 
                              )
                            ),
                          ],
                        ),
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
  }
}