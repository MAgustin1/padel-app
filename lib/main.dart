import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_screen.dart';

// Importamos las pantallas
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PadelApp());
}

class PadelApp extends StatelessWidget {
  const PadelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Padel Ultimate Play',
      
      // --- TEMA GLOBAL ELITE ---
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Fondo global grafito
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDFFF00), // Flúor
          secondary: Color(0xFFDFFF00),
          surface: Color(0xFF1E293B), // Cristal oscuro
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFDFFF00), // Todos los loaders de la app nacen flúor
        ),
      ),
      
      // --- GUARDIA DE SEGURIDAD (STREAMBUILDER) ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          
          // 1. Pantalla de carga inicial (Estilo Elite)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFDFFF00)),
              ),
            );
          }
          
          // 2. Si detecta que YA estás logueado
          if (snapshot.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
              builder: (context, dbSnapshot) {
                
                // Mientras busca en la base de datos (Estilo Elite)
                if (dbSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0F172A),
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xFFDFFF00)),
                    ),
                  );
                }

                // Si el documento EXISTE
                if (dbSnapshot.hasData && dbSnapshot.data!.exists) {
                  return const HomeScreen();
                } 
                // Si el documento NO EXISTE (Usuario nuevo)
                else {
                  return const ProfileScreen(); 
                }
              },
            );
          }
          
          // 3. Si no hay nadie logueado
          return const LoginScreen();
        },
      ),
    );
  }
}