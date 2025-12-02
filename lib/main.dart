import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// 1. IMPORTANTE: Paquete para inicializar la base de datos de zonas horarias
//    Esto es necesario para que 'zonedSchedule' funcione en el servicio de notificaciones.
import 'package:timezone/data/latest.dart' as tz;

// Importaciones de tus archivos
import 'auth_guardian.dart';
import 'firebase_options.dart';
// 2. Importa tu servicio de notificaciones (Ruta relativa)
import 'services/notification_service.dart';

void main() async {
  // Asegura que los bindings del sistema estén listos antes de ejecutar código nativo
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inicializar Timezones
  //    (CRÍTICO: Si falta esto, la app fallará al intentar programar recordatorios)
  tz.initializeTimeZones();

  // 4. Inicializar Firebase con las opciones de tu plataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 5. Inicializar el Servicio de Notificaciones
  //    - Pide permisos al usuario
  //    - Configura los canales de Android
  //    - Guarda el Token FCM en Firestore
  await NotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenLife',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,

      // Tu AuthGuardian decide si mostrar Login o Home
      home: const AuthGuardian(),
    );
  }
}