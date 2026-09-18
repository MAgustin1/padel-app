import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // 1. Pedimos permiso al usuario (Salta el cartelito de "Desea recibir notificaciones")
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permiso concedido para notificaciones');
      
      // 2. Buscamos el Token único de este celular
      String? token = await _firebaseMessaging.getToken();
      print('📱 Token FCM: $token');
      
      // 3. Lo guardamos en el perfil del usuario en Firestore
      await _guardarToken(token);
      
      // 4. Por si el token cambia en el futuro, lo actualizamos automáticamente
      _firebaseMessaging.onTokenRefresh.listen(_guardarToken);
    } else {
      print('❌ Permiso denegado para notificaciones');
    }
  }

  static Future<void> _guardarToken(String? token) async {
    if (token == null) return;
    
    final User? usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(usuario.uid).set({
          'fcmToken': token, // Guardamos el token
        }, SetOptions(merge: true)); // Usamos merge para no borrar el resto de sus datos
        print('💾 Token guardado en Firebase con éxito');
      } catch (e) {
        print('Error guardando token: $e');
      }
    }
  }
}