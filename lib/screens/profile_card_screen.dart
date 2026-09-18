import 'package:flutter/material.dart';
import 'home_screen.dart';

class ProfileCardScreen extends StatelessWidget {
  final String nombre;
  final int media;
  final int vel;
  final int rem;
  final int vol;
  final int def;
  final int con;
  final int fis;
  final String avatarUrl;

  const ProfileCardScreen({
    super.key,
    required this.nombre,
    required this.media,
    required this.vel,
    required this.rem,
    required this.vol,
    required this.def,
    required this.con,
    required this.fis,
    required this.avatarUrl,
  });

  // --- SISTEMA DE COLORES PREMIUM ---
  Map<String, Color> _obtenerColoresCategoria(int media) {
    if (media >= 90) {
      // Elite / Leyenda (Grafito oscuro y Verde Flúor)
      return {
        'fondo1': const Color(0xFF1E293B), 
        'fondo2': const Color(0xFF0A0A0A), 
        'borde': const Color(0xFFDFFF00), 
        'texto': Colors.white,
        'resalte': const Color(0xFFDFFF00)
      };
    } else if (media >= 80) {
      // Oro Premium
      return {
        'fondo1': const Color(0xFF3B300A), 
        'fondo2': const Color(0xFF0A0A0A), 
        'borde': const Color(0xFFFFD700), 
        'texto': Colors.white,
        'resalte': const Color(0xFFFFD700)
      };
    } else if (media >= 66) {
      // Plata Titanio
      return {
        'fondo1': const Color(0xFF2A2E35), 
        'fondo2': const Color(0xFF0A0A0A), 
        'borde': const Color(0xFFC0C0C0), 
        'texto': Colors.white,
        'resalte': const Color(0xFFC0C0C0)
      };
    } else {
      // Bronce Forjado
      return {
        'fondo1': const Color(0xFF3D2314), 
        'fondo2': const Color(0xFF0A0A0A), 
        'borde': const Color(0xFFCD7F32), 
        'texto': Colors.white,
        'resalte': const Color(0xFFCD7F32)
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = _obtenerColoresCategoria(media);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo Grafito
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TU CARTA ULTIMATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.5)), 
        backgroundColor: Colors.transparent, 
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Escondemos la flecha de volver para obligar a ir al Home
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              
              // --- AURA DE LUZ Y CARTA ---
              Container(
                width: 320, 
                height: 480,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colores['borde']!, width: 2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colores['fondo1']!, colores['fondo2']!],
                  ),
                  boxShadow: [
                    // Brillo holográfico de la carta
                    BoxShadow(color: colores['borde']!.withOpacity(0.3), blurRadius: 50, spreadRadius: 5),
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Stack(
                  children: [
                    // --- PATRÓN DE FONDO (Opcional, le da textura) ---
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: Icon(Icons.sports_tennis, size: 250, color: colores['borde']),
                      ),
                    ),

                    // --- MEDIA GIGANTE (Arriba Izquierda) ---
                    Positioned(
                      top: 20, left: 20,
                      child: Column(
                        children: [
                          Text('$media', style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: colores['resalte'], height: 1.0)),
                          Text('MEDIA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colores['texto'], letterSpacing: 2)),
                        ],
                      ),
                    ),

                    // --- INFO EXTRA (Arriba Derecha) ---
                    Positioned(
                      top: 30, right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colores['borde']!.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: colores['borde']!.withOpacity(0.5))
                            ),
                            child: Text('DRIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colores['resalte'])),
                          ),
                        ],
                      ),
                    ),

                    // --- FOTO DEL JUGADOR (Centro) ---
                    Positioned(
                      top: 100, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: colores['borde']!.withOpacity(0.15), blurRadius: 30, spreadRadius: 10)
                            ]
                          ),
                          child: Image.network(
                            avatarUrl,
                            width: 200,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person, size: 180, color: colores['texto']!.withOpacity(0.2));
                            },
                          ),
                        ),
                      ),
                    ),

                    // --- NOMBRE DEL JUGADOR ---
                    Positioned(
                      bottom: 110, left: 15, right: 15,
                      child: Column(
                        children: [
                          Text(
                            nombre,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colores['texto'], letterSpacing: 1.2),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
                            child: Divider(color: colores['borde']!.withOpacity(0.3), thickness: 2),
                          ),
                        ],
                      ),
                    ),

                    // --- LAS 6 ESTADÍSTICAS (Fila Inferior) ---
                    Positioned(
                      bottom: 25, left: 10, right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatHexagon(vel.toString(), 'VEL', colores),
                          _buildStatHexagon(rem.toString(), 'REM', colores),
                          _buildStatHexagon(vol.toString(), 'VOL', colores),
                          _buildStatHexagon(def.toString(), 'DEF', colores),
                          _buildStatHexagon(con.toString(), 'CON', colores),
                          _buildStatHexagon(fis.toString(), 'FIS', colores),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // --- BOTÓN DE ACCIÓN ---
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))
                  ]
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDFFF00), 
                    foregroundColor: Colors.black, 
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('¡A LA CANCHA!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      SizedBox(width: 8),
                      Icon(Icons.sports_tennis, size: 24)
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- ESCUDOS DE ESTADÍSTICAS (Estilo Cristal) ---
  Widget _buildStatHexagon(String valor, String etiqueta, Map<String, Color> colores) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.all(color: colores['borde']!.withOpacity(0.5), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colores['resalte'])),
          ),
        ),
        const SizedBox(height: 6),
        Text(etiqueta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colores['texto']!.withOpacity(0.8), letterSpacing: 0.5)),
      ],
    );
  }
}