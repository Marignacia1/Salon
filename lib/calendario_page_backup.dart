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

  Future<void> _agregarCita() async {
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
      
      if (contactos.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Primero debes registrar al menos un cliente'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final cita = await showDialog<Cita>(
        context: context,
        builder: (context) => AgregarCitaDialog(
          fecha: _selectedDay ?? DateTime.now(),
          contactos: contactos.docs.map((doc) => Contacto.fromFirestore(doc)).toList(),
          servicios: servicios.docs.map((doc) => Servicio.fromFirestore(doc)).toList(),
        ),
      );

      if (cita != null && mounted) {
        // Agregar información del usuario propietario
        final citaConPropietario = Cita(
          id: cita.id,
          contactoId: cita.contactoId,
          nombreContacto: cita.nombreContacto,
          fechaHora: cita.fechaHora,
          servicio: cita.servicio,
          costo: cita.costo,
          obs: cita.obs,
          productosUsados: cita.productosUsados,
          estilista: cita.estilista,
          estado: cita.estado,
          fechaCreacion: cita.fechaCreacion,
          atendidoPor: cita.atendidoPor,
          infoPersonalSesion: cita.infoPersonalSesion,
          detallesTecnicos: cita.detallesTecnicos,
          alergiasProdutosSesion: cita.alergiasProdutosSesion,
          userId: _authService.currentUser?.uid,
          propietarioEmail: _authService.currentUser?.email,
        );
        
        final docRef = await _firestore.collection('citas').add(citaConPropietario.toMap());
        final citaConId = Cita(
          id: docRef.id,
          contactoId: citaConPropietario.contactoId,
          nombreContacto: citaConPropietario.nombreContacto,
          fechaHora: citaConPropietario.fechaHora,
          servicio: citaConPropietario.servicio,
          costo: citaConPropietario.costo,
          obs: citaConPropietario.obs,
          productosUsados: citaConPropietario.productosUsados,
          estilista: citaConPropietario.estilista,
          estado: citaConPropietario.estado,
          fechaCreacion: citaConPropietario.fechaCreacion,
          atendidoPor: citaConPropietario.atendidoPor,
          infoPersonalSesion: citaConPropietario.infoPersonalSesion,
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
        // Actualizar la vista
        setState(() {});
      }
    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar cita: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarCita(String citaId) async {
    // Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cita'),
        content: const Text('¿Estás seguro de que deseas eliminar esta cita? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Cancelar notificaciones programadas
      await _notificationService.cancelAppointmentReminders(citaId);
      
      // Eliminar la cita
      await _firestore.collection('citas').doc(citaId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Actualizar la vista
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar cita: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

  void _showQuickAddContactDialog() {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    final alergiasCtrl = TextEditingController();
    DateTime? fechaNacimiento;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Registrar Cliente'),
            content: isLoading 
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Guardando cliente...'),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre*',
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: telefonoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: direccionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dirección',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => fechaNacimiento = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Nacimiento',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  fechaNacimiento != null
                                      ? '${fechaNacimiento!.day.toString().padLeft(2, '0')}/${fechaNacimiento!.month.toString().padLeft(2, '0')}/${fechaNacimiento!.year}'
                                      : 'Seleccionar fecha',
                                ),
                                const Icon(Icons.calendar_today),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: alergiasCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Alergias',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notasCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Notas',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            actions: isLoading ? [] : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (nombreCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('El nombre es obligatorio'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => isLoading = true);
                  
                  try {
                    print('🔥 Intentando guardar contacto: ${nombreCtrl.text.trim()}');
                    
                    final nuevoContacto = Contacto(
                      nombre: nombreCtrl.text.trim(),
                      telefono: telefonoCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      direccion: direccionCtrl.text.trim(),
                      fechaNacimiento: fechaNacimiento,
                      notas: notasCtrl.text.trim(),
                      alergias: alergiasCtrl.text.trim(),
                    );
                    
                    print('🔥 Datos del contacto: ${nuevoContacto.toMap()}');
                    
                    final docRef = await _firestore.collection('contactos').add(nuevoContacto.toMap());
                    
                    print('🔥 Contacto guardado con ID: ${docRef.id}');
                    
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente registrado exitosamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    print('🔥 ERROR al guardar contacto: $e');
                    setState(() => isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        backgroundColor: const Color(0xFF6B46C1), // Púrpura elegante
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: const Color(0xFF6B46C1).withOpacity(0.3),
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
                  const Color(0xFF6B46C1).withOpacity(0.1),
                  const Color(0xFF9333EA).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF6B46C1).withOpacity(0.2), width: 1),
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
                          color: const Color(0xFF6B46C1).withOpacity(0.3),
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
                        backgroundColor: const Color(0xFF6B46C1),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9333EA),
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
                  color: const Color(0xFF6B46C1).withOpacity(0.1),
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
                        const Color(0xFF9333EA),
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
                        const Color(0xFF6B46C1),
                        const Color(0xFF9333EA),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B46C1).withOpacity(0.4),
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
                        const Color(0xFF6B46C1),
                        const Color(0xFF9333EA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B46C1).withOpacity(0.3),
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
                    color: Color(0xFF6B46C1),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: const Color(0xFF6B46C1),
                    size: 28,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF6B46C1),
                    size: 28,
                  ),
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
                                const Color(0xFF6B46C1).withOpacity(0.1),
                                const Color(0xFF9333EA).withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_note,
                            size: 64,
                            color: const Color(0xFF6B46C1),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Selecciona un día para ver las citas',
                          style: TextStyle(
                            fontSize: 18,
                            color: const Color(0xFF6B46C1),
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
              color: const Color(0xFF6B46C1).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _agregarCita,
          backgroundColor: const Color(0xFF6B46C1),
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
    );
  }

  Future<void> _mostrarDialogoCompartir() async {
    await showDialog(
      context: context,
      builder: (context) => const CompartirCalendarioDialog(),
    );
  }

  Future<void> _mostrarDialogoUnirse() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => const UnirseCalendarioDialog(),
    );

    if (resultado == true && mounted) {
      setState(() {});
    }
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

  Widget _buildListaCitas() {
    return FutureBuilder<List<String>>(
      future: _calendarioService.obtenerPropietariosCalendarios(),
      builder: (context, propietariosSnapshot) {
        if (!propietariosSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final propietarios = propietariosSnapshot.data!;
        final todosLosPropietarios = [_authService.currentUser?.uid, ...propietarios]
            .where((id) => id != null)
            .cast<String>()
            .toList();

        return StreamBuilder<QuerySnapshot>(
          stream: todosLosPropietarios.isEmpty
              ? _firestore
                  .collection('citas')
                  .where('userId', isEqualTo: _authService.currentUser?.uid)
                  .snapshots()
              : _firestore
                  .collection('citas')
                  .where('userId', whereIn: todosLosPropietarios)
                  .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrar citas por la fecha seleccionada
        final startOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
        final endOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day + 1);
        
        final citas = snapshot.data!.docs
            .map((doc) => Cita.fromFirestore(doc))
            .where((cita) {
              final citaDate = cita.fechaHora.toDate();
              final isInSelectedDay = citaDate.isAfter(startOfDay) && citaDate.isBefore(endOfDay);
              // Mostrar solo citas que NO estén completadas
              final notCompleted = cita.estado != EstadoCita.completada;
              return isInSelectedDay && notCompleted;
            })
            .toList()
            ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora)); // Ordenar por hora ascendente

        if (citas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No hay citas para este día',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: citas.length,
          itemBuilder: (context, index) {
            final cita = citas[index];
            final esPropia = cita.userId == _authService.currentUser?.uid;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: esPropia 
                        ? const Color(0xFF6B46C1).withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: esPropia 
                      ? const Color(0xFF6B46C1).withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con servicio y estado
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: esPropia 
                                    ? const Color(0xFF6B46C1).withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                esPropia ? Icons.content_cut : Icons.share,
                                size: 20,
                                color: esPropia 
                                    ? const Color(0xFF6B46C1)
                                    : Colors.blue[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cita.servicio.nombre,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    cita.colorEstado.withOpacity(0.8),
                                    cita.colorEstado,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: cita.colorEstado.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                cita.estadoFormateado,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Información de la cita
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              Icons.access_time,
                              'Hora',
                              cita.horaFormateada,
                              esPropia,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _verDetalleCliente(cita.contactoId),
                              child: _buildInfoItem(
                                Icons.person,
                                'Cliente',
                                cita.nombreContacto,
                                esPropia,
                                isClickable: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (cita.atendidoPor != null && cita.atendidoPor!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          Icons.medical_services,
                          'Atendido por',
                          cita.atendidoPor!,
                          esPropia,
                        ),
                      ],
                      if (cita.obs.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          Icons.notes,
                          'Notas',
                          cita.obs,
                          esPropia,
                        ),
                      ],
                      if (!esPropia && cita.propietarioEmail != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 16, color: Colors.blue[600]),
                              const SizedBox(width: 8),
                              Text(
                                'Calendario de: ${cita.propietarioNombre}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Fecha de creación
                      Center(
                        child: Text(
                          'Creada: ${cita.fechaCreacionFormateada}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.grey[200],
                  ),
                  // Botones de acción
                  if (esPropia)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (cita.puedeEditarse)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: ElevatedButton.icon(
                                  onPressed: () => _editarCita(cita),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Editar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6B46C1),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: cita.puedeEditarse ? 4 : 0,
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _cambiarEstadoCita(cita),
                                icon: const Icon(Icons.update, size: 18),
                                label: const Text('Estado'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9333EA),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: ElevatedButton(
                              onPressed: () => _eliminarCita(cita.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400],
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Icon(Icons.delete, size: 18),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue[100]!,
                                  Colors.blue[50]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: Colors.blue[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Solo lectura',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
        },
      );
      },
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    bool esPropia, {
    bool isClickable = false,
  }) {
    final color = esPropia ? const Color(0xFF6B46C1) : Colors.blue[600]!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1F2937),
              decoration: isClickable ? TextDecoration.underline : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _verDetalleCliente(String contactoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialClientePage(
          contactoId: contactoId,
          onContactoDeleted: (deleted) {
            if (deleted) setState(() {});
          },
        ),
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
        
        final citaActualizada = Cita(
          id: cita.id,
          contactoId: citaEditada.contactoId,
          nombreContacto: citaEditada.nombreContacto,
          fechaHora: citaEditada.fechaHora,
          servicio: citaEditada.servicio,
          costo: citaEditada.costo,
          obs: citaEditada.obs,
          productosUsados: citaEditada.productosUsados,
          estilista: citaEditada.estilista,
          estado: citaEditada.estado,
          fechaCreacion: citaEditada.fechaCreacion,
          atendidoPor: citaEditada.atendidoPor,
          infoPersonalSesion: citaEditada.infoPersonalSesion,
          detallesTecnicos: citaEditada.detallesTecnicos,
          alergiasProdutosSesion: citaEditada.alergiasProdutosSesion,
          userId: cita.userId,
          propietarioEmail: cita.propietarioEmail,
        );
        
        // Solo programar recordatorios si la cita es en el futuro
        final ahora = DateTime.now();
        final fechaCita = citaActualizada.fechaHora.toDate();
        
        if (fechaCita.isAfter(ahora)) {
          final permisos = await _notificationService.requestPermissions();
          if (permisos) {
            await _notificationService.scheduleAppointmentReminder(citaActualizada);
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
      // Cerrar indicador de carga si está abierto
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
}