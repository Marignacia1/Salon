import 'package:flutter/material.dart';
import 'notification_service_new.dart';
import 'package:intl/intl.dart';

class TestNotificationsPage extends StatefulWidget {
  const TestNotificationsPage({Key? key}) : super(key: key);

  @override
  State<TestNotificationsPage> createState() => _TestNotificationsPageState();
}

class _TestNotificationsPageState extends State<TestNotificationsPage> {
  final NotificationServiceNew _notificationService = NotificationServiceNew();
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateFormat('HH:mm:ss').format(DateTime.now())}: $message');
    });
  }

  Future<void> _initializeNotifications() async {
    _addLog('Inicializando servicio de notificaciones...');
    try {
      await _notificationService.initialize();
      _addLog('✅ Servicio inicializado correctamente');
    } catch (e) {
      _addLog('❌ Error al inicializar: $e');
    }
  }

  Future<void> _requestPermissions() async {
    _addLog('Solicitando permisos...');
    try {
      final bool granted = await _notificationService.requestPermissions();
      if (granted) {
        _addLog('✅ Permisos concedidos');
      } else {
        _addLog('❌ Permisos denegados');
      }
    } catch (e) {
      _addLog('❌ Error al solicitar permisos: $e');
    }
  }

  Future<void> _testInstantNotification() async {
    _addLog('Enviando notificación instantánea...');
    try {
      await _notificationService.showInstantNotification(
        title: '🧪 Prueba Instantánea',
        body: 'Esta es una notificación de prueba instantánea',
        payload: 'test_instant',
      );
      _addLog('✅ Notificación instantánea enviada');
    } catch (e) {
      _addLog('❌ Error al enviar notificación: $e');
    }
  }

  Future<void> _testScheduledNotification() async {
    _addLog('Programando notificación en 10 segundos...');
    try {
      final DateTime scheduledTime = DateTime.now().add(const Duration(seconds: 10));
      await _notificationService.scheduleNotification(
        id: 99999,
        title: '🧪 Prueba Programada',
        body: 'Esta notificación fue programada hace 10 segundos',
        scheduledDate: scheduledTime,
        payload: 'test_scheduled',
      );
      _addLog('✅ Notificación programada para: ${DateFormat('HH:mm:ss').format(scheduledTime)}');
    } catch (e) {
      _addLog('❌ Error al programar notificación: $e');
    }
  }

  Future<void> _testScheduledNotificationIn1Minute() async {
    _addLog('Programando notificación en 1 minuto...');
    try {
      final DateTime scheduledTime = DateTime.now().add(const Duration(minutes: 1));
      await _notificationService.scheduleNotification(
        id: 99998,
        title: '🧪 Prueba 1 Minuto',
        body: 'Esta notificación fue programada hace 1 minuto',
        scheduledDate: scheduledTime,
        payload: 'test_1min',
      );
      _addLog('✅ Notificación programada para: ${DateFormat('HH:mm:ss').format(scheduledTime)}');
    } catch (e) {
      _addLog('❌ Error al programar notificación: $e');
    }
  }

  Future<void> _getPendingNotifications() async {
    _addLog('Obteniendo notificaciones pendientes...');
    try {
      final pending = await _notificationService.getPendingNotifications();
      _addLog('📋 Notificaciones pendientes: ${pending.length}');
      for (var notification in pending) {
        _addLog('  • ${notification.title} (ID: ${notification.id})');
      }
    } catch (e) {
      _addLog('❌ Error al obtener notificaciones: $e');
    }
  }

  Future<void> _cancelAllNotifications() async {
    _addLog('Cancelando todas las notificaciones...');
    try {
      await _notificationService.cancelAllNotifications();
      _addLog('🗑️ Todas las notificaciones canceladas');
    } catch (e) {
      _addLog('❌ Error al cancelar notificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de Notificaciones'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pruebas de Notificaciones',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      child: const Text('1. Solicitar Permisos'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _testInstantNotification,
                      child: const Text('2. Notificación Instantánea'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _testScheduledNotification,
                      child: const Text('3. Notificación en 10 segundos'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _testScheduledNotificationIn1Minute,
                      child: const Text('4. Notificación en 1 minuto'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _getPendingNotifications,
                      child: const Text('5. Ver Notificaciones Pendientes'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _cancelAllNotifications,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('6. Cancelar Todas'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Log de Pruebas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _logs.clear();
                              });
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: log.contains('❌') 
                                      ? Colors.red 
                                      : log.contains('✅') 
                                          ? Colors.green 
                                          : Colors.black87,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}