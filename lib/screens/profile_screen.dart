import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'questionnaire_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apodoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController(); // 👇 Faltaba este controlador

  String? _categoriaSeleccionada;
  DateTime? _fechaNacimiento;
  String? _posicionSeleccionada;
  String? _generoSeleccionado; // 👇 Nueva variable para el Género
  
  Uint8List? _imagenBytes; 
  final ImagePicker _picker = ImagePicker();

  final List<String> _categorias = ['1ra', '2da', '3ra', '4ta', '5ta', '6ta', '7ma', '8va', 'Inicial'];
  final List<String> _posiciones = ['Drive', 'Revés', 'Ambos'];
  final List<String> _generos = ['Masculino', 'Femenino']; // 👇 Nueva lista

  Future<void> _seleccionarFoto() async {
    final XFile? fotoElegida = await _picker.pickImage(source: ImageSource.gallery);

    if (fotoElegida != null) {
      final bytes = await fotoElegida.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
      });
    }
  }

  Future<void> _abrirCalendario() async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
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

    if (fechaElegida != null) {
      setState(() {
        _fechaNacimiento = fechaElegida;
      });
    }
  }

  // 👇 HELPER PARA DISEÑAR LOS INPUTS TODOS IGUALES Y PREMIUM 👇
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: const Color(0xFFDFFF00)),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFDFFF00), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        title: const Text('ARMÁ TU PERFIL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              // --- CÍRCULO DE FOTO CON GLOW NEÓN ---
              Center(
                child: GestureDetector(
                  onTap: _seleccionarFoto,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _imagenBytes != null ? const Color(0xFFDFFF00).withOpacity(0.3) : Colors.black26,
                          blurRadius: 30,
                          spreadRadius: 2,
                        )
                      ]
                    ),
                    child: CircleAvatar(
                      radius: 65,
                      backgroundColor: const Color(0xFF1E293B), 
                      backgroundImage: _imagenBytes != null ? MemoryImage(_imagenBytes!) : null,
                      child: _imagenBytes == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Color(0xFFDFFF00)),
                                SizedBox(height: 4),
                                Text('Tu Foto', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- CAMPOS DE FORMULARIO PREMIUM ---
              TextFormField(
                controller: _nombreController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _buildInputDecoration('Nombre y Apellido *', Icons.person),
                validator: (value) => value == null || value.isEmpty ? 'Por favor ingresa tu nombre' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _apodoController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _buildInputDecoration('Apodo (Opcional)', Icons.star_border),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _telefonoController, // 👇 Ahora sí guardamos el número
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: _buildInputDecoration('Teléfono (10 números) *', Icons.phone),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa tu teléfono';
                  if (value.length < 10) return 'Faltan números (deben ser 10)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Selector de Fecha
              InkWell(
                onTap: _abrirCalendario,
                borderRadius: BorderRadius.circular(15),
                child: InputDecorator(
                  decoration: _buildInputDecoration('Fecha de Nacimiento *', Icons.calendar_today),
                  child: Text(
                    _fechaNacimiento == null ? 'Toca para elegir fecha' : '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}',
                    style: TextStyle(color: _fechaNacimiento == null ? Colors.grey[500] : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 👇 NUEVO: Selector de Género
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: _buildInputDecoration('Género *', Icons.wc),
                value: _generoSeleccionado,
                items: _generos.map((gen) => DropdownMenuItem(value: gen, child: Text(gen))).toList(),
                onChanged: (val) => setState(() => _generoSeleccionado = val),
                validator: (value) => value == null ? 'Selecciona tu género' : null,
              ),
              const SizedBox(height: 16),

              // Selector de Categoría
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E293B), 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: _buildInputDecoration('Categoría *', Icons.emoji_events),
                value: _categoriaSeleccionada,
                items: _categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) => setState(() => _categoriaSeleccionada = val),
                validator: (value) => value == null ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 16),

              // Selector de Posición
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: _buildInputDecoration('Posición en cancha *', Icons.sports_tennis),
                value: _posicionSeleccionada,
                items: _posiciones.map((pos) => DropdownMenuItem(value: pos, child: Text(pos))).toList(),
                onChanged: (val) => setState(() => _posicionSeleccionada = val),
                validator: (value) => value == null ? 'Selecciona tu posición' : null,
              ),
              const SizedBox(height: 40),

              // --- BOTÓN FINAL ---
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_fechaNacimiento == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta la fecha de nacimiento'), backgroundColor: Colors.redAccent));
                      return;
                    }
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuestionnaireScreen(
                          nombre: _nombreController.text,
                          apodo: _apodoController.text,
                          telefono: _telefonoController.text, // Pasamos el teléfono
                          fechaNacimiento: _fechaNacimiento!, // Pasamos la fecha
                          genero: _generoSeleccionado!,       // Pasamos el género
                          posicion: _posicionSeleccionada!,   // Pasamos la posición
                          categoria: _categoriaSeleccionada!,
                          imagenBytes: _imagenBytes, 
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18), 
                  backgroundColor: const Color(0xFFDFFF00), 
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text('Comenzar Pruebas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}