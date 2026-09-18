class PlayerModel {
  final String uid;
  final String nombre;
  final String apodo;
  final String categoria;
  final String posicion;
  final int media;
  final String avatarUrl;
  final Map<String, int> stats;

  PlayerModel({
    required this.uid,
    required this.nombre,
    required this.apodo,
    required this.categoria,
    required this.posicion,
    required this.media,
    required this.avatarUrl,
    required this.stats,
  });

  // Esto convierte el objeto a un formato que Firebase entiende (JSON)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'apodo': apodo,
      'categoria': categoria,
      'posicion': posicion,
      'media': media,
      'avatarUrl': avatarUrl,
      'stats': stats,
    };
  }
}