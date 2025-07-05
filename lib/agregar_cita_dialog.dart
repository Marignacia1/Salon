import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contacto_model.dart';

class AgregarCitaDialog extends StatefulWidget {
  final DateTime fecha;
  final Cita? citaExistente;
  final List<Contacto> contactos;
  final List<Servicio> servicios;

  const AgregarCitaDialog({
    super.key,
    required this.fecha,
    this.citaExistente,
    required this.contactos,
    required this.servicios,
  });

  @override
  State<AgregarCitaDialog> createState() => _AgregarCitaDialogState();
}

class _AgregarCitaDialogState extends State<AgregarCitaDialog> {
  late Contacto? _contactoSeleccionado;
  late Servicio? _servicioSeleccionado;
  late TimeOfDay _horaSeleccionada;
  late DateTime _fechaSeleccionada;
  final _notasController = TextEditingController();
  final _productosController = TextEditingController();
  final _atendidoPorController = TextEditingController();
  final _infoPersonalController = TextEditingController();
  final _detallesTecnicosController = TextEditingController();
  final _alergiasProductosController = TextEditingController();
  EstadoCita? _estadoSeleccionado = EstadoCita.pendiente;

  @override
  void initState() {
    super.initState();
    _horaSeleccionada = TimeOfDay.now();
    _fechaSeleccionada = widget.fecha;
    
    if (widget.citaExistente != null) {
      _contactoSeleccionado = widget.contactos.firstWhere(
        (c) => c.id == widget.citaExistente!.contactoId,
      );
      _servicioSeleccionado = widget.servicios.firstWhere(
        (s) => s.nombre == widget.citaExistente!.servicio.nombre,
        orElse: () => widget.servicios.isNotEmpty ? widget.servicios.first : Servicio(id: '', nombre: '', precioBase: 0),
      );
      final citaDateTime = widget.citaExistente!.fechaHora.toDate();
      _horaSeleccionada = TimeOfDay.fromDateTime(citaDateTime);
      _fechaSeleccionada = DateTime(citaDateTime.year, citaDateTime.month, citaDateTime.day);
      _notasController.text = widget.citaExistente!.obs;
      _productosController.text = widget.citaExistente!.productosUsados.join(', ');
      _atendidoPorController.text = widget.citaExistente!.atendidoPor ?? '';
      _infoPersonalController.text = widget.citaExistente!.infoPersonalSesion ?? '';
      _estadoSeleccionado = widget.citaExistente!.estado;
    } else {
      _contactoSeleccionado = widget.contactos.isNotEmpty ? widget.contactos.first : null;
      _servicioSeleccionado = widget.servicios.isNotEmpty ? widget.servicios.first : null;
    }
  }

  void _guardarCita() {
    if (_contactoSeleccionado == null || _servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona cliente y servicio')));
      return;
    }

    final fechaHora = DateTime(
      _fechaSeleccionada.year,
      _fechaSeleccionada.month,
      _fechaSeleccionada.day,
      _horaSeleccionada.hour,
      _horaSeleccionada.minute,
    );

    // Solo validar fechas pasadas para citas nuevas, no para ediciones
    if (widget.citaExistente == null && fechaHora.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes agendar citas en el pasado')));
      return;
    }

    final productos = _productosController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final cita = Cita(
      id: widget.citaExistente?.id ?? '',
      contactoId: _contactoSeleccionado!.id,
      nombreContacto: _contactoSeleccionado!.nombre,
      fechaHora: Timestamp.fromDate(fechaHora),
      servicio: _servicioSeleccionado!,
      costo: _servicioSeleccionado!.precioBase,
      obs: _notasController.text,
      productosUsados: productos,
      estilista: '', // Campo legacy, se mantiene vacío
      estado: _estadoSeleccionado ?? EstadoCita.pendiente,
      fechaCreacion: widget.citaExistente?.fechaCreacion ?? Timestamp.now(),
      atendidoPor: _atendidoPorController.text.isEmpty ? null : _atendidoPorController.text,
      infoPersonalSesion: _infoPersonalController.text.isEmpty ? null : _infoPersonalController.text,
      // Preservar campos importantes de la cita original al editar
      userId: widget.citaExistente?.userId,
      propietarioEmail: widget.citaExistente?.propietarioEmail,
      detallesTecnicos: widget.citaExistente?.detallesTecnicos,
      alergiasProdutosSesion: widget.citaExistente?.alergiasProdutosSesion,
    );

    Navigator.pop(context, cita);
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

  String _getTextoForEstado(EstadoCita estado) {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.citaExistente == null ? 'Agregar Cita' : 'Editar Cita'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Contacto>(
              value: _contactoSeleccionado,
              decoration: const InputDecoration(labelText: 'Cliente*'),
              items: widget.contactos.map((contacto) {
                return DropdownMenuItem<Contacto>(
                  value: contacto,
                  child: Text(contacto.nombre),
                );
              }).toList(),
              onChanged: (contacto) => setState(() => _contactoSeleccionado = contacto),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Servicio>(
              value: _servicioSeleccionado,
              decoration: const InputDecoration(labelText: 'Servicio*'),
              items: widget.servicios.map((servicio) {
                return DropdownMenuItem<Servicio>(
                  value: servicio,
                  child: Text(servicio.nombre),
                );
              }).toList(),
              onChanged: (servicio) => setState(() => _servicioSeleccionado = servicio),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha de la cita*'),
              subtitle: Text('${_fechaSeleccionada.day.toString().padLeft(2, '0')}/${_fechaSeleccionada.month.toString().padLeft(2, '0')}/${_fechaSeleccionada.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaSeleccionada,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (fecha != null) setState(() => _fechaSeleccionada = fecha);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Hora*'),
              subtitle: Text(_horaSeleccionada.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final hora = await showTimePicker(
                  context: context,
                  initialTime: _horaSeleccionada,
                );
                if (hora != null) setState(() => _horaSeleccionada = hora);
              },
            ),
            TextField(
              controller: _notasController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 3,
            ),
            TextField(
              controller: _productosController,
              decoration: const InputDecoration(
                labelText: 'Productos (separados por coma)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EstadoCita>(
              value: _estadoSeleccionado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: EstadoCita.values.map((estado) {
                return DropdownMenuItem<EstadoCita>(
                  value: estado,
                  child: Row(
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
                      Text(_getTextoForEstado(estado)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (estado) => setState(() => _estadoSeleccionado = estado),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _atendidoPorController,
              decoration: const InputDecoration(
                labelText: 'Atendido por',
                hintText: 'Nombre del profesional que atiende',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _infoPersonalController,
              decoration: const InputDecoration(
                labelText: 'Info personal de la sesión',
                hintText: 'Notas específicas del cliente para esta sesión',
              ),
              maxLines: 2,
            ),
            if (widget.citaExistente != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información de la cita:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Fecha programada: ${widget.citaExistente!.fechaFormateada}'),
                    Text('Creada el: ${widget.citaExistente!.fechaCreacionFormateada}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            _guardarCita();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}