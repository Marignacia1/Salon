import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'contacto_model.dart';
import 'servicios_page.dart';
import 'calendario_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contactos_home_page.dart';
import 'auth_wrapper.dart';
import 'auth_service.dart';
import 'notification_service_new.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:local_notifier/local_notifier.dart';

// Handler para mensajes en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Mensaje recibido en background: ${message.messageId}');
  
  // Aquí puedes manejar la lógica de notificaciones en background
  if (message.notification != null) {
    await NotificationServiceNew().showInstantNotification(
      title: message.notification!.title ?? 'Nueva notificación',
      body: message.notification!.body ?? '',
      payload: message.data['route'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // Configuración de Firebase
  await _initializeFirebase();

  // Configurar handler para mensajes en background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const SalonBellezaApp());
  
// Inicializar notificaciones después del arranque
  _initializeNotifications();
}

void _initializeNotifications() async {
  try {
    await localNotifier.setup(
      appName: 'Salón de Belleza',
    );
  } catch (e) {
    print('Error inicializando notificaciones: $e');
  }
}
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Verificar conexión a Firebase
    await _testFirebaseConnection();
    
    // Inicializar servicio de notificaciones
    await NotificationServiceNew().initialize();
    
    // Cargar servicios iniciales si no existen
    await _cargarServiciosIniciales();
  } catch (e) {
    print('Error inicializando Firebase: $e');
    // Podrías mostrar un error al usuario o intentar una reconexión
  }
}

Future<void> _testFirebaseConnection() async {
  try {
    await FirebaseFirestore.instance
        .collection('connection_test')
        .doc('test')
        .set({
          'timestamp': DateTime.now(),
          'status': 'success'
        });
    print("✅ Firebase conectado correctamente");
  } catch (e) {
    print("❌ Error en Firebase: $e");
    throw Exception('No se pudo conectar a Firebase');
  }
}

Future<void> _cargarServiciosIniciales() async {
  try {
    final serviciosRef = FirebaseFirestore.instance.collection('servicios');
    final snapshot = await serviciosRef.limit(1).get();
    
    print("📋 Verificando servicios existentes: ${snapshot.size} encontrados");
    
    if (snapshot.size == 0) {
      print("🔄 Cargando servicios iniciales...");
      final batch = FirebaseFirestore.instance.batch();
      
      final serviciosIniciales = [
        Servicio(id: 'alisado', nombre: 'ALISADO ORGÁNICO', precioBase: 60000),
        Servicio(id: 'tonos', nombre: 'TONOS FANTASÍA', precioBase: 45000),
        Servicio(id: 'masaje_capilar', nombre: 'MASAJE CAPILAR', precioBase: 30000),
        Servicio(id: 'reconstruccion', nombre: 'MASAJE DE RECONSTRUCCIÓN', precioBase: 30000),
        Servicio(id: 'hidratacion', nombre: 'MASAJES DE HIDRATACIÓN', precioBase: 25000),
        Servicio(id: 'tinturas', nombre: 'TINTURAS', precioBase: 27000),
        Servicio(id: 'cortes', nombre: 'CORTES DE CABELLO', precioBase: 14000),
        Servicio(id: 'visado_platinado', nombre: 'VISADO PLATINADO', precioBase: 45000),
        Servicio(id: 'visado', nombre: 'VISADO', precioBase: 38000),
        Servicio(id: 'cejas', nombre: 'DISEÑOS DE CEJAS', precioBase: 9000),
        Servicio(id: 'mechas', nombre: 'MECHAS', precioBase: 58000),
        Servicio(id: 'ombre', nombre: 'DISEÑO OMBRÉ', precioBase: 58000),
        Servicio(id: 'mechas_uni', nombre: 'MECHAS UNIVERSALES', precioBase: 58000),
        Servicio(id: 'morena', nombre: 'MORENA ILUMINADA', precioBase: 58000),
        Servicio(id: 'depilacion_facial', nombre: 'DEPILACIÓN FACIAL', precioBase: 15000),
        Servicio(id: 'depilacion_corporal', nombre: 'DEPILACIÓN CORPORAL', precioBase: 30000),
        Servicio(id: 'balayage', nombre: 'BALAYAGE', precioBase: 58000),
        Servicio(id: 'esmaltado', nombre: 'ESMALTADO PERMANENTE', precioBase: 12000),
        Servicio(id: 'maquillaje', nombre: 'MAQUILLAJE DÍA Y NOCHE', precioBase: 15000),
      ];
      
      print("🎯 Creando ${serviciosIniciales.length} servicios...");
      
      for (var servicio in serviciosIniciales) {
        final docRef = serviciosRef.doc(servicio.id);
        batch.set(docRef, servicio.toMap());
      }
      
      await batch.commit();
      print("✅ ${serviciosIniciales.length} servicios iniciales cargados correctamente");
      
      // Verificar que se crearon correctamente
      final verifySnapshot = await serviciosRef.get();
      print("🔍 Verificación: ${verifySnapshot.size} servicios creados en Firestore");
    } else {
      print("✅ Servicios ya existentes, no es necesario cargar");
    }
  } catch (e) {
    print("❌ Error cargando servicios iniciales: $e");
    // Intentar cargar servicios uno por uno si el batch falla
    try {
      print("🔄 Intentando carga individual...");
      await _cargarServiciosIndividualmente();
    } catch (e2) {
      print("❌ Error en carga individual: $e2");
    }
  }
}

Future<void> _cargarServiciosIndividualmente() async {
  final serviciosRef = FirebaseFirestore.instance.collection('servicios');
  
  final serviciosIniciales = [
    Servicio(id: 'alisado', nombre: 'ALISADO ORGÁNICO', precioBase: 60000),
    Servicio(id: 'tonos', nombre: 'TONOS FANTASÍA', precioBase: 45000),
    Servicio(id: 'masaje_capilar', nombre: 'MASAJE CAPILAR', precioBase: 30000),
    Servicio(id: 'reconstruccion', nombre: 'MASAJE DE RECONSTRUCCIÓN', precioBase: 30000),
    Servicio(id: 'hidratacion', nombre: 'MASAJES DE HIDRATACIÓN', precioBase: 25000),
    Servicio(id: 'tinturas', nombre: 'TINTURAS', precioBase: 27000),
    Servicio(id: 'cortes', nombre: 'CORTES DE CABELLO', precioBase: 14000),
    Servicio(id: 'visado_platinado', nombre: 'VISADO PLATINADO', precioBase: 45000),
    Servicio(id: 'visado', nombre: 'VISADO', precioBase: 38000),
    Servicio(id: 'cejas', nombre: 'DISEÑOS DE CEJAS', precioBase: 9000),
    Servicio(id: 'mechas', nombre: 'MECHAS', precioBase: 58000),
    Servicio(id: 'ombre', nombre: 'DISEÑO OMBRÉ', precioBase: 58000),
    Servicio(id: 'mechas_uni', nombre: 'MECHAS UNIVERSALES', precioBase: 58000),
    Servicio(id: 'morena', nombre: 'MORENA ILUMINADA', precioBase: 58000),
    Servicio(id: 'depilacion_facial', nombre: 'DEPILACIÓN FACIAL', precioBase: 15000),
    Servicio(id: 'depilacion_corporal', nombre: 'DEPILACIÓN CORPORAL', precioBase: 30000),
    Servicio(id: 'balayage', nombre: 'BALAYAGE', precioBase: 58000),
    Servicio(id: 'esmaltado', nombre: 'ESMALTADO PERMANENTE', precioBase: 12000),
    Servicio(id: 'maquillaje', nombre: 'MAQUILLAJE DÍA Y NOCHE', precioBase: 15000),
  ];
  
  for (var servicio in serviciosIniciales) {
    try {
      await serviciosRef.doc(servicio.id).set(servicio.toMap());
      print("✅ Servicio creado: ${servicio.nombre}");
    } catch (e) {
      print("❌ Error creando ${servicio.nombre}: $e");
    }
  }
}

class SalonBellezaApp extends StatelessWidget {
  const SalonBellezaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos nuestra paleta de colores para reutilizarla
    const Color colorPrimario = Color(0xFF00695C); // Verde oscuro
    const Color colorAcento = Color(0xFF80CBC4); // Verde menta más vivo
    const Color colorFondo = Color(0xFFF5F5F5); // Un gris muy claro en lugar de blanco puro

    return MaterialApp(
      title: 'Salón de Belleza',
      theme: ThemeData(
        primaryColor: colorPrimario,
        scaffoldBackgroundColor: colorFondo,
        
        // Tema para la Barra de Navegación (AppBar)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Fondo transparente para que se vea el gradiente
          elevation: 0,
          foregroundColor: colorPrimario, // Color para el título y los íconos
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: colorPrimario,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Tema para las Tarjetas (Card)
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        // Tema para los Botones Elevados
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorPrimario,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),

        // Tema para el Botón Flotante de Acción (FAB)
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
        ),

        // Tema para los campos de texto
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: colorAcento, width: 2),
          ),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  final _authService = AuthService();

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await _authService.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const CalendarioPage();
  }
}