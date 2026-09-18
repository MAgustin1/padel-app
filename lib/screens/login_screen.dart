import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    UserCredential? userCredential;
    try {
      userCredential = await _authService.loginConGoogle();
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos iniciar sesión con Google: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (userCredential != null) {
      // 1. Agarramos el ID del usuario que acaba de entrar
      final String uid = userCredential.user!.uid;

      // 👇 Datos que Google nos da gratis: nombre y foto de perfil.
      // Los mandamos al ProfileScreen SOLO como sugerencia precargada;
      // el usuario puede cambiarlos en el paso siguiente.
      final String? nombreGoogle = userCredential.user!.displayName;
      final String? fotoGoogle = userCredential.user!.photoURL;

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
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              prefillNombre: nombreGoogle,
              prefillFotoUrl: fotoGoogle,
            ),
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicio de sesión cancelado.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 👇 Botón de Apple OCULTO a propósito: Apple exige Sign in with Apple
  // funcionando de verdad para poder mostrar login social en iOS (requisito
  // de revisión de la App Store). Lo reactivamos cuando auth_service.dart
  // tenga loginConApple() implementado con los certificados reales.
  // Future<void> _iniciarConApple() async { ... }

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
                  icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white, size: 20),
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
                // 👇 Botón de Apple oculto hasta que loginConApple() esté
                // implementado de verdad (ver auth_service.dart). Cuando esté
                // listo, el botón vuelve a este mismo lugar.
              ],
            ],
          ),
        ),
      ),
    );
  }
}