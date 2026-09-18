import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Lo dejamos listo para el futuro

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- INICIO DE SESIÓN CON GOOGLE ---
  Future<UserCredential?> loginConGoogle() async {
    try {
      if (kIsWeb) {
        // Lógica exclusiva para cuando probamos en Google Chrome
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      } else {
        // --- CÓDIGO ACTUALIZADO PARA GOOGLE SIGN IN V7+ ---
        // 1. Usamos la instancia global (Singleton) y la inicializamos
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize(); 

        // 2. signIn() cambió su nombre a authenticate()
        final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

        if (googleUser != null) {
          // 3. Ya no requiere 'await'
          final GoogleSignInAuthentication googleAuth = googleUser.authentication;
          
          // 4. Firebase Auth ahora solo necesita el idToken
          final AuthCredential credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );
          return await _auth.signInWithCredential(credential);
        }
      }
    } catch (e) {
      print("Error en Google Login: $e");
      return null;
    }
    return null;
  }

  // --- CERRAR SESIÓN ---
  Future<void> cerrarSesion() async {
    await _auth.signOut();
    if (!kIsWeb) {
      // También arreglamos el constructor acá
      await GoogleSignIn.instance.signOut();
    }
  }

  // --- INICIO DE SESIÓN CON APPLE (Estructura lista para producción) ---
  Future<UserCredential?> loginConApple() async {
    try {
      print("Login con Apple en construcción (Requiere cuenta Apple Developer)");
      // Aquí irá el código final de Apple cuando tengamos los certificados
      return null; 
    } catch (e) {
      print("Error en Apple Login: $e");
      return null;
    }
  }
}