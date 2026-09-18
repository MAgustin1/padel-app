import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Función para manejar el botón de Google
  Future<void> _iniciarConGoogle() async {
    setState(() => _isLoading = true);

    final userCredential = await _authService.loginConGoogle();

    if (userCredential != null) {
      // 1. Agarramos el ID del usuario que acaba de entrar
      final String uid = userCredential.user!.uid;

      // 2. Hacemos una consulta rápida a Firestore para ver si ya tiene perfil creado
      final DocumentSnapshot docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      setState(() => _isLoading = false);
      if (!mounted) return;

      // 3. ¡LA DECISIÓN INTELIGENTE!
      if (docSnap.exists) {
        // Si el documento YA EXISTE en la base de datos, va directo al Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // Si el documento NO existe, es la primera vez y va a registrarse
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El inicio de sesión fue cancelado o falló.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Función para el botón de Apple (Visual por ahora)
  Future<void> _iniciarConApple() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login con Apple próximamente 🍏', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFFDFFF00),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // 👇 Fondo Grafito Elite
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              // --- LOGO CON EFECTO GLOW (Brillo Neón) ---
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDFFF00).withOpacity(0.05), // Fondo sutil flúor
                    border: Border.all(color: const Color(0xFFDFFF00).withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDFFF00).withOpacity(0.15), 
                        blurRadius: 40, 
                        spreadRadius: 10
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sports_tennis, size: 80, color: Color(0xFFDFFF00)),
                ),
              ),
              const SizedBox(height: 40),
              
              // --- TÍTULO DE LA APP ---
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2),
                  children: [
                    TextSpan(text: 'PADEL ', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'SOCIAL', style: TextStyle(color: Color(0xFFDFFF00))), // Resalte flúor
                  ]
                ),
              ),
              const SizedBox(height: 10),
              
              Text(
                'Tu carrera empieza acá',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[400], letterSpacing: 1),
              ),
              const SizedBox(height: 70),

              // --- BOTONES O INDICADOR DE CARGA ---
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFFDFFF00)))
              else ...[
                // Botón de Google (Dark Glassmorphism)
                ElevatedButton.icon(
                  onPressed: _iniciarConGoogle,
                  icon: Image.network(
                    'https://img.icons8.com/color/48/000000/google-logo.png',
                    height: 24,
                  ),
                  label: const Text(
                    'Continuar con Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B), // Gris azulado oscuro
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)), // Borde muy sutil
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botón de Apple (Negro Puro)
                ElevatedButton.icon(
                  onPressed: _iniciarConApple,
                  icon: const Icon(Icons.apple, color: Colors.white, size: 28),
                  label: const Text(
                    'Continuar con Apple',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0A0A), // Negro
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}