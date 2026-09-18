import 'package:flutter/material.dart';

class PadelPlayerCardWidget extends StatelessWidget {
  final String nombre;
  final int media;
  final String categoriaLugar;
  final String? edadInfo;
  final int vel, rem, vol, def, con, fis;
  final String avatarUrl;
  final bool isTinderView;
  final int partidosGanados;
  final int partidosPerdidos;

  const PadelPlayerCardWidget({
    super.key,
    required this.nombre,
    required this.media,
    required this.categoriaLugar,
    this.edadInfo,
    required this.vel,
    required this.rem,
    required this.vol,
    required this.def,
    required this.con,
    required this.fis,
    required this.avatarUrl,
    this.isTinderView = false,
    this.partidosGanados = 0,
    this.partidosPerdidos = 0,
  });

  // --- SISTEMA DE COLORES POR CATEGORÍA ---
  Map<String, dynamic> _estiloPorCategoria(String categoria) {
    // Pasamos todo a mayúsculas para que sea fácil buscar las palabras
    final cat = categoria.toUpperCase();

    // 1. BLANCO PERLADO (1ra y 2da)
    if (cat.contains('1RA') || cat.contains('2DA') || cat.contains('PRIMERA') || cat.contains('SEGUNDA')) {
      return {
        'img': 'assets/images/carta_1ra.png', // Usá la imagen que quieras de fondo acá
        'b': const Color(0xFFF8F9FA)          // Blanco perlado / Platino
      };
    }
    
    // 2. DORADO (3ra y 4ta)
    if (cat.contains('3RA') || cat.contains('4TA') || cat.contains('TERCERA') || cat.contains('CUARTA')) {
      return {
        'img': 'assets/images/carta_oro.png', 
        'b': const Color(0xFFFFD700)          // Dorado brillante
      };
    }

    // 3. GRIS / PLATA (5ta y 6ta)
    if (cat.contains('5TA') || cat.contains('6TA') || cat.contains('QUINTA') || cat.contains('SEXTA')) {
      return {
        'img': 'assets/images/carta_plata.png', 
        'b': const Color(0xFFC0C0C0)          // Gris Plata
      };
    }

    // 4. BRONCE (7ma, 8va, Inicial o cualquier otra cosa no detectada)
    return {
      'img': 'assets/images/carta_bronce.png', 
      'b': const Color(0xFFCD7F32)            // Cobre / Bronce
    };
  }

  @override
  Widget build(BuildContext context) {
    final e        = _estiloPorCategoria(categoriaLugar);
    final Color cb = e['b'];

    final List<Shadow> sh = [
      Shadow(color: Colors.black.withOpacity(0.95), blurRadius: 8, offset: const Offset(1, 1)),
      Shadow(color: Colors.black.withOpacity(0.5),  blurRadius: 2, offset: const Offset(0, 0)),
    ];

    return AspectRatio(
      aspectRatio: 1024 / 1536, // Ratio exacto del PNG
      child: LayoutBuilder(
        builder: (context, box) {
          final double w = box.maxWidth;
          final double h = box.maxHeight;

          return Stack(
            children: [
              // 1. FONDO DE LA CARTA
              Positioned.fill(
                child: Image.asset(
                  e['img'],
                  fit: BoxFit.fill,
                ),
              ),

              // 2. NÚMERO DE MEDIA (Escudo superior izquierdo)
              Positioned(
                left:  w * 0.08,
                width: w * 0.30,
                top:   h * 0.135,
                child: Text(
                  '$media',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   h * 0.10,
                    fontWeight: FontWeight.w900,
                    color:      Colors.white,
                    height:     1.0,
                    shadows:    sh,
                  ),
                ),
              ),

              // 3. CATEGORÍA (Debajo del número)
              Positioned(
                left:  w * 0.065,
                width: w * 0.34,
                top:   h * 0.275,
                child: Text(
                  categoriaLugar.split('/').first.trim().toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   h * 0.035,
                    fontWeight: FontWeight.w900,
                    color:      cb,
                    letterSpacing: 0.5,
                    shadows:    sh,
                  ),
                ),
              ),

              // 4. W/L BADGE (Arriba derecha)
              Positioned(
                top:   h * 0.13,
                right: w * 0.13,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical:   h * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060E1E).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cb.withOpacity(0.5), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    'W:$partidosGanados  L:$partidosPerdidos',
                    style: TextStyle(
                      fontSize:   h * 0.022,
                      fontWeight: FontWeight.w900,
                      color:      Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

              // 5. FOTO DEL JUGADOR (Reducida y centrada)
              Positioned(
                left:   w * 0.28, // 👈 Aumentado para achicar el ancho
                right:  w * 0.28,
                top:    h * 0.25,
                height: w * 0.44, // 👈 Acompaña al ancho para mantener el círculo perfecto
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 15, spreadRadius: 2)
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      width: w * 0.44,
                      height: w * 0.44,
                      errorBuilder: (c, err, s) => Container(
                        color: Colors.black45,
                        child: Icon(Icons.person, size: w * 0.22, color: Colors.white30),
                      ),
                    ),
                  ),
                ),
              ),

              // 6. BLOQUE UNIFICADO: NOMBRE + LÍNEAS + STATS
              // Al estar todo junto, aseguramos la grilla "T" perfecta.
              Positioned(
                left:  w * 0.12,
                right: w * 0.12,
                top:   h * 0.57,  // 👈 1. SUBIR BLOQUE: Lo bajé de 0.58 a 0.55 para subirlo todo
                bottom: h * 0.15, // 👈 2. JUNTAR STATS: Lo subí de 0.11 a 0.15 para "aplastar" la caja y juntar las líneas
                child: Column(
                  children: [
                    // --- NOMBRE ---
                    Text(
                      nombre,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:   h * 0.040,
                        fontWeight: FontWeight.w900,
                        color:      Colors.white,
                        letterSpacing: 1.5,
                        shadows:    sh,
                      ),
                    ),
                    SizedBox(height: h * 0.008),
                    
                    // --- LÍNEA HORIZONTAL ---
                    Container(
                      height: 1.5,
                      width: double.infinity,
                      color: cb.withOpacity(0.6),
                    ),

                    // --- LÍNEA VERTICAL Y COLUMNAS DE STATS ---
                    Expanded(
                      child: Row(
                        children: [
                          // Mitad Izquierda 
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: h * 0.005),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _stat('VEL', '$vel', cb, sh, h),
                                  _stat('REM', '$rem', cb, sh, h),
                                  _stat('VOL', '$vol', cb, sh, h),
                                ],
                              ),
                            ),
                          ),
                          // --- LÍNEA VERTICAL ---
                          Container(
                            width: 1.5,
                            height: double.infinity,
                            margin: EdgeInsets.only(bottom: h * 0.01), // 👈 3. LÍNEA CORTA: Este margen la recorta desde abajo
                            color: cb.withOpacity(0.6),
                          ),
                          // Mitad Derecha
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: h * 0.005),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _stat('DEF', '$def', cb, sh, h),
                                  _stat('CON', '$con', cb, sh, h),
                                  _stat('FIS', '$fis', cb, sh, h),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Fila individual de stat (Sigla seguida de Número, perfectamente alineados)
  Widget _stat(String label, String num, Color accentColor, List<Shadow> sh, double cardH) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: cardH * 0.002), 
          child: Text(
            label,
            style: TextStyle(
              fontSize:   cardH * 0.025,
              fontWeight: FontWeight.w800,
              color:      accentColor,
              shadows:    sh,
            ),
          ),
        ),
        SizedBox(width: cardH * 0.008),
        Text(
          num,
          style: TextStyle(
            fontSize:   cardH * 0.035,
            fontWeight: FontWeight.w900,
            color:      Colors.white,
            shadows:    sh,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}