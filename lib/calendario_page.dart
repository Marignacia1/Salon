import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'contacto_model.dart';
import 'detalle_contacto_page.dart';
import 'historial_cliente_page.dart';
import 'agregar_cita_dialog.dart';
import 'contactos_home_page.dart';
import 'auth_service.dart';
import 'compartir_calendario_dialog.dart';
import 'unirse_calendario_dialog.dart';
import 'calendario_compartido_service.dart';
import 'notification_service_new.dart';
import 'test_notifications_page.dart';
import 'widgets/app_background.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  final _calendarioService = CalendarioCompartidoService();
  final _notificationService = NotificationServiceNew();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  Future<void> _agregarCita() async {
    // Primero obtenemos contactos y servicios
    final contactos = await _firestore.collection('contactos').get();
    final servicios = await _firestore.collection('servicios').get();
    
    final nuevaCita = await showDialog<Cita>(
      context: context,
      builder: (context) => AgregarCitaDialog(
        fecha: _selectedDay ?? DateTime.now(),
        contactos: contactos.docs.map((doc) => Contacto.fromFirestore(doc)).toList(),
        servicios: servicios.docs.map((doc) => Servicio.fromFirestore(doc)).toList(),
      ),
    );

    if (nuevaCita != null) {
      try {
        // Crear la cita con el propietario del calendario
        final usuario = _authService.currentUser;
        final citaConPropietario = Cita(
          id: '',
          fechaHora: nuevaCita.fechaHora,
          servicio: nuevaCita.servicio,
          contactoId: nuevaCita.contactoId,
          nombreContacto: nuevaCita.nombreContacto,
          costo: nuevaCita.costo,
          obs: nuevaCita.obs,
          estado: nuevaCita.estado,
          fechaCreacion: nuevaCita.fechaCreacion,
          userId: usuario?.uid ?? '',
          propietarioEmail: usuario?.email,
          atendidoPor: nuevaCita.atendidoPor,
          detallesTecnicos: nuevaCita.detallesTecnicos,
          alergiasProdutosSesion: nuevaCita.alergiasProdutosSesion,
        );

        // Guardar en Firestore
        final docRef = await _firestore.collection('citas').add(citaConPropietario.toMap());
        
        // Crear cita con ID para notificaciones
        final citaConId = Cita(
          id: docRef.id,
          fechaHora: citaConPropietario.fechaHora,
          servicio: citaConPropietario.servicio,
          contactoId: citaConPropietario.contactoId,
          nombreContacto: citaConPropietario.nombreContacto,
          costo: citaConPropietario.costo,
          obs: citaConPropietario.obs,
          estado: citaConPropietario.estado,
          fechaCreacion: citaConPropietario.fechaCreacion,
          atendidoPor: citaConPropietario.atendidoPor,
          detallesTecnicos: citaConPropietario.detallesTecnicos,
          alergiasProdutosSesion: citaConPropietario.alergiasProdutosSesion,
          userId: citaConPropietario.userId,
          propietarioEmail: citaConPropietario.propietarioEmail,
        );
        
        // Programar recordatorios de notificación solo si la cita es en el futuro
        final ahora = DateTime.now();
        final fechaCita = citaConId.fechaHora.toDate();
        
        if (fechaCita.isAfter(ahora)) {
          final permisos = await _notificationService.requestPermissions();
          if (permisos) {
            await _notificationService.scheduleAppointmentReminder(citaConId);
          }
        } else {
          print('⏰ Cita programada en el pasado, no se crean recordatorios');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita agendada correctamente con recordatorios'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Actualizar la UI
        setState(() {});
      } catch (e) {
        print('Error al agendar cita: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agendar cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarCita(String citaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Cancelar notificaciones antes de eliminar
        await _notificationService.cancelAppointmentReminders(citaId);
        
        await _firestore.collection('citas').doc(citaId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.content_cut,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Salón de Belleza',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: const Color(0xFF00695C).withOpacity(0.3),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              } else if (value == 'compartir') {
                _mostrarDialogoCompartir();
              } else if (value == 'unirse') {
                _mostrarDialogoUnirse();
              } else if (value == 'notificaciones') {
                _mostrarGestionNotificaciones();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'compartir',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Compartir Calendario'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unirse',
                child: Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 8),
                    Text('Unirse a Calendario'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'notificaciones',
                child: Row(
                  children: [
                    Icon(Icons.notifications),
                    SizedBox(width: 8),
                    Text('Gestionar Notificaciones'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Botones de navegación rápida
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00695C).withOpacity(0.1),
                  const Color(0xFF80CBC4).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF00695C).withOpacity(0.2), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00695C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showQuickAddContactDialog();
                      },
                      icon: const Icon(Icons.person_add_alt_1, size: 22),
                      label: const Text(
                        'Registrar Cliente',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9333EA).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
  onPressed: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactosHomePage(),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  },
  icon: const Icon(Icons.people_alt, size: 22),
  label: const Text(
    'Historial Clientes',
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  ),
  // Al eliminar la propiedad 'style', el botón usará el tema verde
),
                      
            ),
                ),
              ],
            ),
          ),
          // Calendario
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00695C).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF80CBC4),
                        const Color(0xFFB946C1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  selectedDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00695C),
                        const Color(0xFF80CBC4),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00695C).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  weekendTextStyle: TextStyle(
                    color: Colors.red[400],
                    fontWeight: FontWeight.w600,
                  ),
                  defaultTextStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  todayTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00695C),
                        const Color(0xFF80CBC4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00695C).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  formatButtonTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  titleTextStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: const Color(0xFF00695C),
                    size: 28,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF00695C),
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Lista de citas
          Expanded(
            child: _selectedDay == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00695C).withOpacity(0.1),
                                const Color(0xFF80CBC4).withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_note,
                            size: 64,
                            color: const Color(0xFF00695C),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Selecciona un día para ver las citas',
                          style: TextStyle(
                            fontSize: 18,
                            color: const Color(0xFF00695C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildListaCitas(),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00695C).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _agregarCita,
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.event_available, size: 24),
          label: const Text(
            'Nueva Cita',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    );
  }

 Widget _buildListaCitas() {
  return FutureBuilder<List<String>>(
    future: _calendarioService.obtenerPropietariosCalendarios(),
    builder: (context, propietariosSnapshot) {
      if (propietariosSnapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (propietariosSnapshot.hasError) {
        return Center(child: Text('Error cargando calendarios: ${propietariosSnapshot.error}'));
      }

      final propietarios = propietariosSnapshot.data ?? [];
      final todosLosPropietarios = [_authService.currentUser?.uid, ...propietarios]
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      return StreamBuilder<QuerySnapshot>(
        stream: todosLosPropietarios.isEmpty
            ? _firestore.collection('citas').where('userId', isEqualTo: 'invalid-user-id').snapshots()
            : _firestore.collection('citas').where('userId', whereIn: todosLosPropietarios).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final startOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          final endOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day + 1);

          final allDocs = snapshot.data!.docs;

          final citas = allDocs
              .map((doc) => Cita.fromFirestore(doc))
              .where((cita) {
                final citaDate = cita.fechaHora.toDate();
  final isInDay = citaDate.isAtSameMomentAs(startOfDay) ||
                 (citaDate.isAfter(startOfDay) && citaDate.isBefore(endOfDay));

  // --- NUEVA LÍNEA ---
  // Comprueba que el estado NO sea ni completada ni cancelada
  final esVisible = cita.estado != EstadoCita.completada && 
                    cita.estado != EstadoCita.cancelada;

  return isInDay && esVisible; // <-- Ahora comprueba fecha Y estado
              })
              .toList()
              ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

          if (citas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No hay citas para este día', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          // --- INICIO DEL NUEVO DISEÑO ---
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: citas.length,
            itemBuilder: (context, index) {
              final cita = citas[index];
              final esPropia = cita.userId == _authService.currentUser?.uid;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE0F2F1).withOpacity(0.7), // Verde menta muy claro
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              cita.servicio.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004D40), // Verde oscuro
                              ),
                            ),
                          ),
                          Text(
                            cita.horaFormateada,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00695C), // Verde medio
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildInfoItem(Icons.person_outline, cita.nombreContacto, onTap: () => _verDetalleCliente(cita.contactoId)),
                      if (cita.atendidoPor != null && cita.atendidoPor!.isNotEmpty)
                        _buildInfoItem(Icons.spa_outlined, 'Atendido por: ${cita.atendidoPor!}'),
                      
                      const SizedBox(height: 8),

                      // Estado y botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cita.colorEstado.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cita.estadoFormateado,
                              style: TextStyle(color: cita.colorEstado, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (esPropia)
                            Row(
                              children: [
                                if (cita.puedeEditarse)
                                  _buildActionButton(Icons.edit, () => _editarCita(cita)),
                                _buildActionButton(Icons.sync, () => _cambiarEstadoCita(cita)),
                                _buildActionButton(Icons.delete_outline, () => _eliminarCita(cita.id), color: Colors.red[700]),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          // --- FIN DEL NUEVO DISEÑO ---
        },
      );
    },
  );
}




 Widget _buildInfoItem(IconData icon, String text, {VoidCallback? onTap}) {
  final content = Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF00695C)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            decoration: onTap != null ? TextDecoration.underline : null,
          ),
        ),
      ),
    ],
  );

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: content,
    ),
  );
}
  void _verDetalleCliente(String contactoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialClientePage(
          contactoId: contactoId,
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoCompartir() async {
    await showDialog(
      context: context,
      builder: (context) => const CompartirCalendarioDialog(),
    );
  }

  Future<void> _mostrarDialogoUnirse() async {
    await showDialog(
      context: context,
      builder: (context) => const UnirseCalendarioDialog(),
    );
  }

  Future<void> _mostrarGestionNotificaciones() async {
    final permisos = await _notificationService.requestPermissions();
    
    if (!permisos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requieren permisos de notificación para usar esta función'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notificacionesPendientes = await _notificationService.getPendingNotifications();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gestión de Notificaciones'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notificaciones pendientes: ${notificacionesPendientes.length}'),
                const SizedBox(height: 16),
                if (notificacionesPendientes.isNotEmpty) ...[
                  const Text(
                    'Próximas notificaciones:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...notificacionesPendientes.take(5).map((notif) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${notif.title}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
                  if (notificacionesPendientes.length > 5)
                    Text('... y ${notificacionesPendientes.length - 5} más'),
                ] else ...[
                  const Text('No hay notificaciones pendientes'),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tipos de recordatorios:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('• 1 día antes (6:00 PM)'),
                      Text('• 2 horas antes'),
                      Text('• 30 minutos antes'),
                      Text('• 5 minutos antes'),
                      Text('• 1 minuto antes'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Probar notificación inmediata
                await _notificationService.showInstantNotification(
                  title: 'Prueba de Notificación',
                  body: 'Si ves esto, las notificaciones funcionan correctamente!',
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notificación de prueba enviada'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Probar Ahora'),
            ),
            TextButton(
              onPressed: () async {
                // Probar notificación programada para 10 segundos después
                final fechaPrueba = DateTime.now().add(const Duration(seconds: 10));
                await _notificationService.scheduleNotification(
                  id: 9999,
                  title: 'Prueba Programada',
                  body: 'Esta notificación fue programada hace 10 segundos',
                  scheduledDate: fechaPrueba,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notificación programada para 10 segundos'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Probar 10s'),
            ),
            if (notificacionesPendientes.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await _notificationService.cancelAllNotifications();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Todas las notificaciones han sido canceladas'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                child: const Text('Cancelar Todas'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TestNotificationsPage()),
                );
              },
              child: const Text('Pruebas Avanzadas'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.signOut();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickAddContactDialog() async {
    // Diálogo rápido para agregar contacto
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acceso Rápido'),
        content: const Text('¿Quieres ir a la página de registrar clientes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactosHomePage()),
              );
            },
            child: const Text('Ir'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarCita(Cita cita) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando...'),
                ],
              ),
            ),
          ),
        ),
      );

      final contactos = await _firestore.collection('contactos').get();
      final servicios = await _firestore.collection('servicios').get();
      
      // Cerrar indicador de carga
      if (mounted) Navigator.pop(context);
      
      final citaEditada = await showDialog<Cita>(
        context: context,
        builder: (context) => AgregarCitaDialog(
          fecha: cita.fechaHora.toDate(),
          contactos: contactos.docs.map((doc) => Contacto.fromFirestore(doc)).toList(),
          servicios: servicios.docs.map((doc) => Servicio.fromFirestore(doc)).toList(),
          citaExistente: cita,
        ),
      );

      if (citaEditada != null && mounted) {
        await _firestore.collection('citas').doc(cita.id).update(citaEditada.toMap());
        
        // Cancelar notificaciones anteriores y crear nuevas
        await _notificationService.cancelAppointmentReminders(cita.id);
        
        // Solo programar recordatorios si la cita es en el futuro
        final ahora = DateTime.now();
        final fechaCita = citaEditada.fechaHora.toDate();
        
        if (fechaCita.isAfter(ahora)) {
          final permisos = await _notificationService.requestPermissions();
          if (permisos) {
            await _notificationService.scheduleAppointmentReminder(citaEditada);
          }
        } else {
          print('⏰ Cita es en el pasado, no se programan recordatorios');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        setState(() {});
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al editar cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cambiarEstadoCita(Cita cita) async {
    final nuevoEstado = await showDialog<EstadoCita>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar estado de cita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EstadoCita.values.map((estado) {
            return ListTile(
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getColorForEstado(estado),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_getTextoEstado(estado)),
                ],
              ),
              selected: estado == cita.estado,
              onTap: () => Navigator.pop(context, estado),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (nuevoEstado != null && nuevoEstado != cita.estado) {
      try {
        await _firestore.collection('citas').doc(cita.id).update({
          'estado': nuevoEstado.name,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estado cambiado a: ${_getTextoEstado(nuevoEstado)}'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cambiar estado: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getColorForEstado(EstadoCita estado) {
    switch (estado) {
      case EstadoCita.pendiente:
        return Colors.orange;
      case EstadoCita.enProceso:
        return Colors.blue;
      case EstadoCita.completada:
        return Colors.green;
      case EstadoCita.cancelada:
        return Colors.red;
    }
  }

  String _getTextoEstado(EstadoCita estado) {
    switch (estado) {
      case EstadoCita.pendiente:
        return 'Pendiente';
      case EstadoCita.enProceso:
        return 'En proceso';
      case EstadoCita.completada:
        return 'Completada';
      case EstadoCita.cancelada:
        return 'Cancelada';
    }
  }

  // Nuevo widget auxiliar para los botones
  Widget _buildActionButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: color ?? const Color(0xFF00695C),
        splashRadius: 20,
      ),
    );
  }
}