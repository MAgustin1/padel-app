import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();

  // Variables para guardar la selección original
  String? _clubSeleccionado;
  String? _categoriaSeleccionada;
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  bool _esPublico = true;
  bool _estaGuardando = false;

  // NUEVAS Variables para Filtros Avanzados
  String? _generoSeleccionado = 'Mixto (Todos)';
  String? _rangoEdadSeleccionado = 'Cualquier edad';
  String? _tipoPartidoSeleccionado = 'Competitivo (Suma Puntos)';

  // Listas de opciones simuladas originales
  final List<String> _clubes = ['Padel Pro Arena', 'Central Club', 'Club El Palacio', 'La Jaula Padel'];
  final List<String> _categorias = ['Libre (Cualquiera)', '1ra a 3ra', '4ta a 5ta', '6ta a 7ma', '8va / Inicial'];

  // NUEVAS Listas de opciones
  final List<String> _generos = ['Mixto (Todos)', 'Masculino', 'Femenino'];
  final List<String> _rangosEdad = ['Cualquier edad', 'Menores de 30', '30 a 45 años', 'Mayores de 45'];
  final List<String> _tiposPartido = ['Competitivo (Suma Puntos)', 'Amistoso / Turno libre'];

  Future<void> _elegirFecha() async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFDFFF00),
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccionado != null) setState(() => _fechaSeleccionada = seleccionado);
  }

  Future<void> _elegirHora() async {
    final TimeOfDay? seleccionado = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFDFFF00),
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccionado != null) setState(() => _horaSeleccionada = seleccionado);
  }

  // --- FUNCIÓN MÁGICA DE FIREBASE (ACTUALIZADA) ---
  Future<void> _guardarPartidoEnFirebase() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaSeleccionada == null || _horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta elegir fecha y hora', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _estaGuardando = true);

    try {
      final DateTime fechaHoraPartido = DateTime(
        _fechaSeleccionada!.year,
        _fechaSeleccionada!.month,
        _fechaSeleccionada!.day,
        _horaSeleccionada!.hour,
        _horaSeleccionada!.minute,
      );

      final String uidCreador = FirebaseAuth.instance.currentUser!.uid;

      // 1. Buscamos el género del creador para descontar su cupo si el partido es Mixto
      final docCreador = await FirebaseFirestore.instance.collection('users').doc(uidCreador).get();
      final String miGenero = docCreador.data()?['genero']?.toString().toLowerCase() ?? 'masculino';

      // 2. Setear los cupos según el tipo de partido
      int cuposMasc = 0;
      int cuposFem = 0;

      if (_generoSeleccionado == 'Mixto (Todos)') {
        // En un partido mixto ideal hay 2 de cada uno. Restamos el cupo del creador.
        if (miGenero == 'masculino') {
          cuposMasc = 1; // 2 - 1
          cuposFem = 2;
        } else if (miGenero == 'femenino') {
          cuposMasc = 2;
          cuposFem = 1; // 2 - 1
        } else {
          // Si por algún motivo tiene otro género, dejamos 2 y 1 por defecto
          cuposMasc = 1;
          cuposFem = 2;
        }
      }

      await FirebaseFirestore.instance.collection('partidos').add({
        'creadorId': uidCreador,
        'club': _clubSeleccionado,
        'categoriaReq': _categoriaSeleccionada,
        'fechaHora': fechaHoraPartido,
        'esPublico': _esPublico,
        'generoReq': _generoSeleccionado,
        'rangoEdadReq': _rangoEdadSeleccionado,
        'tipoPartido': _tipoPartidoSeleccionado,
        // 👇 AGREGAMOS LOS CUPOS EXACTOS POR GÉNERO
        'cuposMasculinos': cuposMasc,
        'cuposFemeninos': cuposFem,
        // ----------------------------------------
        'estado': 'abierto',
        'jugadoresActuales': [uidCreador],
        'lugaresDisponibles': 3,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Partido publicado con éxito! 🎾', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFFDFFF00)),
      );
      Navigator.pop(context);

    } catch (e) {
      print("Error al guardar partido: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() => _estaGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ARMAR PARTIDO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 110, left: 24, right: 24, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- AVISO IMPORTANTE ---
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.05),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.orangeAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)
                  ]
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recordatorio Importante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orangeAccent, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text('Esta app NO gestiona la reserva física de la cancha. Asegurate de haber reservado tu turno en el club de forma privada.', style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Text('CONFIGURACIÓN DE CANCHA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              
              // --- TARJETA 1: Dónde y Cuándo ---
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      iconEnabledColor: const Color(0xFFDFFF00),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: '¿En qué Club?', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.location_on, color: Colors.grey), border: InputBorder.none),
                      value: _clubSeleccionado,
                      items: _clubes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _clubSeleccionado = val),
                      validator: (val) => val == null ? 'Falta elegir el club' : null,
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month, color: Colors.grey),
                      title: Text(
                        _fechaSeleccionada == null ? 'Día del partido' : '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}',
                        style: TextStyle(color: _fechaSeleccionada == null ? Colors.grey : Colors.white, fontWeight: _fechaSeleccionada == null ? FontWeight.normal : FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.edit, size: 18, color: Color(0xFFDFFF00)),
                      onTap: _elegirFecha,
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time, color: Colors.grey),
                      title: Text(
                        _horaSeleccionada == null ? 'Hora del turno' : _horaSeleccionada!.format(context),
                        style: TextStyle(color: _horaSeleccionada == null ? Colors.grey : Colors.white, fontWeight: _horaSeleccionada == null ? FontWeight.normal : FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.edit, size: 18, color: Color(0xFFDFFF00)),
                      onTap: _elegirHora,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              const Text('DETALLES DEL PARTIDO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
              const SizedBox(height: 12),

              // --- TARJETA 2: Nivel y Privacidad ---
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      iconEnabledColor: const Color(0xFFDFFF00),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: 'Categoría requerida', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.emoji_events, color: Colors.grey), border: InputBorder.none),
                      value: _categoriaSeleccionada,
                      items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _categoriaSeleccionada = val),
                      validator: (val) => val == null ? 'Falta elegir la categoría' : null,
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.black,
                      activeTrackColor: const Color(0xFFDFFF00),
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.black26,
                      title: const Text('Partido Público', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text(_esPublico ? 'Visible para todos los jugadores' : 'Solo con invitación secreta', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      secondary: Icon(_esPublico ? Icons.public : Icons.lock, color: _esPublico ? const Color(0xFFDFFF00) : Colors.grey),
                      value: _esPublico,
                      onChanged: (bool valor) => setState(() => _esPublico = valor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              // 👇 NUEVA SECCIÓN: FILTROS AVANZADOS
              const Text('FILTROS AVANZADOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDFFF00), letterSpacing: 1.2)),
              const SizedBox(height: 12),

              // --- TARJETA 3: Género, Edad y Tipo ---
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Género
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      iconEnabledColor: const Color(0xFFDFFF00),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: 'Género del Partido', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.wc, color: Colors.grey), border: InputBorder.none),
                      value: _generoSeleccionado,
                      items: _generos.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _generoSeleccionado = val),
                    ),
                    const Divider(color: Colors.white12, height: 10),
                    // Rango de Edad
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      iconEnabledColor: const Color(0xFFDFFF00),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: 'Rango de Edad', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.cake, color: Colors.grey), border: InputBorder.none),
                      value: _rangoEdadSeleccionado,
                      items: _rangosEdad.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _rangoEdadSeleccionado = val),
                    ),
                    const Divider(color: Colors.white12, height: 10),
                    // Tipo de Partido
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      iconEnabledColor: const Color(0xFFDFFF00),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: 'Tipo de Partido', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.local_fire_department, color: Colors.grey), border: InputBorder.none),
                      value: _tipoPartidoSeleccionado,
                      items: _tiposPartido.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _tipoPartidoSeleccionado = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),

              // --- BOTÓN FINAL CON FIREBASE ---
              _estaGuardando
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)))
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFDFFF00).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 5))
                        ]
                      ),
                      child: ElevatedButton(
                        onPressed: () => _guardarPartidoEnFirebase(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: const Color(0xFFDFFF00),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: const Text('Generar Partido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}