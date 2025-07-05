import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'contacto_model.dart';
import 'package:local_notifier/local_notifier.dart';

class NotificationServiceNew {
  static final NotificationServiceNew _instance = NotificationServiceNew._internal();
  factory NotificationServiceNew() => _instance;
  NotificationServiceNew._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Inicializar timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);
    
    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // Configuración para iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print('Notificación tocada: ${details.payload}');
      },
    );
    
    // Crear canal de notificación para Android
    await _createNotificationChannel();
    
    _isInitialized = true;
    print('✅ NotificationService inicializado correctamente');
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'appointment_channel',
      'Recordatorios de Citas',
      description: 'Notificaciones para recordatorios de citas del salón de belleza',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.scheduleExactAlarm.isDenied) {
       await Permission.scheduleExactAlarm.request();
      }
      return true;
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    
    return false;
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      LocalNotification notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.onShow = () => print('Notificación de escritorio mostrada: $title');
      notification.onClose = (reason) => print('Notificación de escritorio cerrada: $reason');
      notification.onClick = () => print('Notificación de escritorio clickeada');
      await notification.show();
      print('✅ Notificación de escritorio mostrada: $title');

    } else {
      if (!_isInitialized) {
        print('❌ NotificationService no inicializado para móvil');
        return;
      }

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'appointment_channel',
        'Recordatorios de Citas',
        channelDescription: 'Notificaciones para recordatorios de citas',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ Notificación de móvil mostrada: $title');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) {
      print('❌ La fecha programada es en el pasado: $scheduledDate');
      return;
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final delay = scheduledDate.difference(DateTime.now());
      Future.delayed(delay, () {
        showInstantNotification(title: title, body: body, payload: payload);
      });
      print('✅ Notificación de escritorio programada para: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}');
    } else {
      if (!_isInitialized) {
        print('❌ NotificationService no inicializado para móvil');
        return;
      }

      const NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_channel',
          'Recordatorios de Citas',
          channelDescription: 'Notificaciones para recordatorios de citas del salón de belleza',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      print('✅ Notificación de móvil programada - ID: $id, Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}');
    }
  }

  Future<void> scheduleAppointmentReminder(Cita cita) async {
    print('📅 Programando recordatorios para: ${cita.nombreContacto}');
    
    final DateTime appointmentTime = cita.fechaHora.toDate();
    final DateTime now = DateTime.now();
    
    print('⏰ Cita: ${DateFormat('dd/MM/yyyy HH:mm').format(appointmentTime)}');
    print('⏰ Ahora: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}');
    
    final int baseId = cita.hashCode.abs() % 100000;
    
    final DateTime oneDayBefore = DateTime(
      appointmentTime.year,
      appointmentTime.month,
      appointmentTime.day - 1,
      18, // 6:00 PM
      0,
    );
    
    if (oneDayBefore.isAfter(now)) {
      await scheduleNotification(
        id: baseId + 1,
        title: '🌟 Recordatorio de Cita - Mañana',
        body: 'Tienes una cita mañana: ${cita.servicio.nombre} con ${cita.nombreContacto} a las ${cita.horaFormateada}',
        scheduledDate: oneDayBefore,
        payload: 'appointment_${cita.id}',
      );
    }
    
    final DateTime twoHoursBefore = appointmentTime.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(now)) {
      await scheduleNotification(
        id: baseId + 2,
        title: '⏰ Recordatorio de Cita - En 2 horas',
        body: 'Tu cita es en 2 horas: ${cita.servicio.nombre} con ${cita.nombreContacto}',
        scheduledDate: twoHoursBefore,
        payload: 'appointment_${cita.id}',
      );
    }
    
    final DateTime thirtyMinutesBefore = appointmentTime.subtract(const Duration(minutes: 30));
    if (thirtyMinutesBefore.isAfter(now)) {
      await scheduleNotification(
        id: baseId + 3,
        title: '🔔 Recordatorio de Cita - ¡En 30 minutos!',
        body: 'Tu cita es en 30 minutos: ${cita.servicio.nombre} con ${cita.nombreContacto}',
        scheduledDate: thirtyMinutesBefore,
        payload: 'appointment_${cita.id}',
      );
    }
    
    final DateTime fiveMinutesBefore = appointmentTime.subtract(const Duration(minutes: 5));
    if (fiveMinutesBefore.isAfter(now)) {
      await scheduleNotification(
        id: baseId + 4,
        title: '🚨 Recordatorio de Cita - ¡En 5 minutos!',
        body: 'Tu cita es en 5 minutos: ${cita.servicio.nombre} con ${cita.nombreContacto}',
        scheduledDate: fiveMinutesBefore,
        payload: 'appointment_${cita.id}',
      );
    }
    
    final DateTime oneMinuteBefore = appointmentTime.subtract(const Duration(minutes: 1));
    if (oneMinuteBefore.isAfter(now)) {
      await scheduleNotification(
        id: baseId + 5,
        title: '⚡ Recordatorio de Cita - ¡AHORA!',
        body: 'Tu cita es en 1 minuto: ${cita.servicio.nombre} con ${cita.nombreContacto}',
        scheduledDate: oneMinuteBefore,
        payload: 'appointment_${cita.id}',
      );
    }
    
    print('✅ Recordatorios programados para ${cita.nombreContacto}');
  }

  Future<void> cancelAppointmentReminders(String citaId) async {
    final int baseId = citaId.hashCode.abs() % 100000;
    
    await _flutterLocalNotificationsPlugin.cancel(baseId + 1);
    await _flutterLocalNotificationsPlugin.cancel(baseId + 2);
    await _flutterLocalNotificationsPlugin.cancel(baseId + 3);
    await _flutterLocalNotificationsPlugin.cancel(baseId + 4);
    await _flutterLocalNotificationsPlugin.cancel(baseId + 5);
    
    print('🗑️ Recordatorios cancelados para cita: $citaId');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('🗑️ Todas las notificaciones canceladas');
  }

  Future<void> testNotification() async {
    await showInstantNotification(
      title: '🧪 Prueba de Notificación',
      body: 'Esta es una prueba para verificar que las notificaciones funcionan correctamente',
      payload: 'test',
    );
  }

  Future<void> testScheduledNotification() async {
    final DateTime testDate = DateTime.now().add(const Duration(seconds: 10));
    await scheduleNotification(
      id: 99999,
      title: '🧪 Prueba de Notificación Programada',
      body: 'Esta notificación fue programada hace 10 segundos',
      scheduledDate: testDate,
      payload: 'test_scheduled',
    );
    print('🧪 Notificación de prueba programada para: ${DateFormat('HH:mm:ss').format(testDate)}');
  }
}