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

// --- LÓGICA DE RECORDATORIOS (CUIDADO DE PLANTAS) ---

  Future<void> schedulePlantReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduleTime,
  }) async {

    // CORRECCIÓN: Convertimos la fecha a UTC para evitar errores de zona horaria.
    // Esto asegura que "dentro de 10 segundos" sea REALMENTE dentro de 10 segundos.
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      scheduleTime.toUtc(),
      tz.UTC,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'plant_care_channel_v99', // <--- ¡CAMBIA ESTO! Ponle v99 o lo que quieras
          'Recordatorios de Riego', // Nombre visible en ajustes
          channelDescription: 'Canal para recordatorios de cuidado de plantas',
          importance: Importance.max, // ¡IMPORTANTE!
          priority: Priority.high,    // ¡IMPORTANTE!
          playSound: true,            // Asegura que suene
        ),
      ),

      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    print("🌱 Recordatorio programado en UTC para: $scheduledDate");
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
  // --- FUNCIÓN DE PRUEBA INMEDIATA ---
  Future<void> showInstantNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'test_channel_id', // ID diferente para probar
      'Canal de Prueba',
      channelDescription: 'Este canal es para probar que las alertas funcionan',
      importance: Importance.max, // ¡IMPORTANCIA MÁXIMA!
      priority: Priority.high,    // ¡PRIORIDAD ALTA!
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      888, // ID fijo para pruebas
      '🔔 ¡Ding Dong!',
      '¡El sistema de notificaciones está funcionando!',
      notificationDetails,
    );
  }
}