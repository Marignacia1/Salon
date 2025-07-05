import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'contacto_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _channelId = 'citas_channel';
  static const String _channelName = 'Recordatorios de Citas';
  static const String _channelDescription = 'Notificaciones para recordatorios de citas';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // En desktop (Windows, macOS, Linux), las notificaciones funcionan diferente
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('🖥️ Ejecutándose en desktop - notificaciones limitadas');
      _initialized = true;
      return;
    }

    // Inicializar timezone
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
      print('🌍 Timezone configurado: America/Mexico_City');
    } catch (e) {
      print('⚠️ Error configurando timezone, usando local: $e');
      tz.initializeTimeZones();
    }

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Crear canal de notificación para Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    // Inicializar Firebase Messaging
    await _initializeFirebaseMessaging();

    _initialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Solicitar permisos
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    // Obtener token
    final token = await _messaging.getToken();
    print('FCM Token: $token');

    // Guardar token en Firestore
    if (_auth.currentUser != null && token != null) {
      await _saveTokenToFirestore(token);
    }

    // Escuchar cambios de token
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // Configurar handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Mensaje recibido en foreground: ${message.notification?.title}');
    
    // Mostrar notificación local cuando la app está en foreground
    if (message.notification != null) {
      showInstantNotification(
        title: message.notification!.title ?? 'Nueva notificación',
        body: message.notification!.body ?? '',
        payload: message.data['route'],
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Mensaje abierto desde notificación: ${message.data}');
    // Aquí puedes navegar a una pantalla específica
  }

  void _onNotificationTap(NotificationResponse response) {
    print('Notificación tocada: ${response.payload}');
    // Manejar navegación basada en el payload
  }

  Future<bool> requestPermissions() async {
    print('🔔 Solicitando permisos de notificación...');
    
    // En desktop, siempre "conceder" permisos
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('✅ Permisos de notificación "concedidos" en desktop');
      return true;
    }

    if (Platform.isAndroid) {
      print('📱 Plataforma Android detectada');
      
      final status = await Permission.notification.request();
      print('📝 Resultado solicitud permiso: $status');
      
      if (status.isGranted) {
        await _createNotificationChannel();
        print('✅ Canal de notificación creado');
      }
      
      return status.isGranted;
    } else if (Platform.isIOS) {
      print('🍎 Plataforma iOS detectada');
      final settings = await _messaging.requestPermission();
      print('📱 Configuración iOS: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }
    
    return false;
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // En desktop, mostrar en consola y como diálogo
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('🔔 NOTIFICACIÓN: $title - $body');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    print('📅 Programando notificación ID: $id');
    print('🗓️ Fecha programada: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}');
    print('⏰ Fecha actual: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    
    // En desktop, solo loggear la programación
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('📅 NOTIFICACIÓN PROGRAMADA (Desktop): $title para ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}');
      return;
    }

    // Verificar que la fecha sea en el futuro
    if (scheduledDate.isBefore(DateTime.now())) {
      print('❌ Error: La fecha programada es en el pasado');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      print('🌍 Fecha en zona horaria: $tzScheduledDate');
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
      print('✅ Notificación programada exitosamente con ID: $id');
    } catch (e) {
      print('❌ Error al programar notificación: $e');
    }
  }

  Future<void> scheduleAppointmentReminder(Cita cita) async {
    print('📝 Programando recordatorios para cita: ${cita.nombreContacto}');
    final appointmentTime = cita.fechaHora.toDate();
    print('📅 Cita programada para: ${DateFormat('dd/MM/yyyy HH:mm').format(appointmentTime)}');
    
    // Recordatorio 1 día antes
    final oneDayBefore = appointmentTime.subtract(const Duration(days: 1));
    print('🗓️ Recordatorio 1 día antes: ${DateFormat('dd/MM/yyyy HH:mm').format(oneDayBefore)}');
    
    if (oneDayBefore.isAfter(DateTime.now())) {
      print('✅ Programando recordatorio 1 día antes...');
      await scheduleNotification(
        id: (cita.hashCode.abs() % 100000) * 10 + 1,
        title: 'Recordatorio de Cita - Mañana',
        body: 'Tienes una cita mañana: ${cita.servicio.nombre} con ${cita.nombreContacto} a las ${cita.horaFormateada}',
        scheduledDate: oneDayBefore.copyWith(hour: 18, minute: 0), // 6:00 PM
        payload: 'cita_${cita.id}',
      );
    } else {
      print('⏰ Recordatorio 1 día antes ya pasó');
    }

    // Recordatorio 2 horas antes
    final twoHoursBefore = appointmentTime.subtract(const Duration(hours: 2));
    print('🗓️ Recordatorio 2 horas antes: ${DateFormat('dd/MM/yyyy HH:mm').format(twoHoursBefore)}');
    
    if (twoHoursBefore.isAfter(DateTime.now())) {
      print('✅ Programando recordatorio 2 horas antes...');
      await scheduleNotification(
        id: (cita.hashCode.abs() % 100000) * 10 + 2,
        title: 'Recordatorio de Cita - En 2 horas',
        body: 'Tu cita es en 2 horas: ${cita.servicio.nombre} con ${cita.nombreContacto}',
        scheduledDate: twoHoursBefore,
        payload: 'cita_${cita.id}',
      );
    } else {
      print('⏰ Recordatorio 2 horas antes ya pasó');
    }

    // Recordatorio 30 minutos antes
    final thirtyMinutesBefore = appointmentTime.subtract(const Duration(minutes: 30));
    print('🗓️ Recordatorio 30 min antes: ${DateFormat('dd/MM/yyyy HH:mm').format(thirtyMinutesBefore)}');
    
    if (thirtyMinutesBefore.isAfter(DateTime.now())) {
      print('✅ Programando recordatorio 30 minutos antes...');
      await scheduleNotification(
        id: (cita.hashCode.abs() % 100000) * 10 + 3,
        title: 'Recordatorio de Cita - En 30 minutos',
        body: 'Tu cita es en 30 minutos: ${cita.servicio.nombre} con ${cita.nombreContacto}',
        scheduledDate: thirtyMinutesBefore,
        payload: 'cita_${cita.id}',
      );
    } else {
      print('⏰ Recordatorio 30 minutos antes ya pasó');
    }
    
    print('✅ Recordatorios programados completamente');
  }

  Future<void> cancelAppointmentReminders(String citaId) async {
    final hash = citaId.hashCode.abs() % 100000;
    await _notifications.cancel(hash * 10 + 1);
    await _notifications.cancel(hash * 10 + 2);
    await _notifications.cancel(hash * 10 + 3);
    print('🗑️ Canceladas notificaciones para cita: $citaId (IDs: ${hash * 10 + 1}, ${hash * 10 + 2}, ${hash * 10 + 3})');
  }

  Future<void> sendPushNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Obtener token del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final token = userDoc.data()?['fcmToken'] as String?;

      if (token != null) {
        // Aquí normalmente usarías tu servidor backend para enviar la notificación
        // Por ahora, simularemos con una notificación local
        await showInstantNotification(
          title: title,
          body: body,
          payload: data?['route'],
        );
      }
    } catch (e) {
      print('Error enviando notificación push: $e');
    }
  }

  Future<void> notifySharedCalendarUsers({
    required String calendarId,
    required String title,
    required String body,
    String? route,
  }) async {
    try {
      // Obtener usuarios del calendario compartido
      final calendarDoc = await _firestore
          .collection('calendarios_compartidos')
          .doc(calendarId)
          .get();

      if (calendarDoc.exists) {
        final calendar = CalendarioCompartido.fromFirestore(calendarDoc);
        
        // Enviar notificación a todos los usuarios autorizados
        for (final userId in calendar.usuariosAutorizados) {
          await sendPushNotificationToUser(
            userId: userId,
            title: title,
            body: body,
            data: {'route': route, 'calendarId': calendarId},
          );
        }
      }
    } catch (e) {
      print('Error notificando usuarios del calendario: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    // En desktop, devolver lista vacía
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('📋 Notificaciones pendientes en desktop: 0 (limitación de plataforma)');
      return [];
    }
    
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}