import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/timezone.dart' as tz;

// --- MANEJADOR DE SEGUNDO PLANO ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Manejo de mensaje FCM en segundo plano: ${message.messageId}");
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- INICIALIZACIÓN ---
  Future<void> initialize() async {
    // 1. Configuración Android
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("Notificación local tocada: ${response.payload}");
      },
    );

    // 2. Permisos FCM
    await _fcm.requestPermission();

    // 3. ¡CORRECCIÓN IMPORTANTE!
    // Escuchamos los cambios de sesión.
    // Si el usuario inicia sesión (user != null), guardamos el token inmediatamente.
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _saveDeviceToken();
      }
    });

    // También intentamos guardar si ya había una sesión activa al abrir la app
    if (_auth.currentUser != null) {
      await _saveDeviceToken();
    }

    _setupFCMListeners();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // --- GUARDAR TOKEN EN FIRESTORE ---

  Future<void> _saveDeviceToken() async {
    try {
      String? token = await _fcm.getToken();
      final userId = _auth.currentUser?.uid;

      if (userId != null && token != null) {
        // Usamos el nombre exacto que tienes en tu BD: 'tokenNotificacion'
        await _db.collection('users').doc(userId).update({
          'tokenNotificacion': token,
        }); // Usamos update para no borrar otros campos por accidente

        print('✅ Token guardado en campo tokenNotificacion para: $userId');
      }
    } catch (e) {
      print("Error guardando token: $e");
    }
  }

  // --- RESTO DE LÓGICA (Igual que antes) ---

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notificación FCM recibida en primer plano');
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App abierta desde notificación FCM');
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'greenlife_channel',
          'Notificaciones Generales',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  Future<void> schedulePlantReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduleTime,
  }) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      scheduleTime,
      tz.local,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'plant_care_channel',
          'Recordatorios de Riego',
          channelDescription: 'Canal para recordatorios de cuidado de plantas',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
    print("🌱 Recordatorio programado para: $scheduledDate");
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}