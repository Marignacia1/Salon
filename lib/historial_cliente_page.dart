import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'contacto_model.dart';
import 'agregar_cita_dialog.dart';
import 'widgets/app_background.dart';

class HistorialClientePage extends StatefulWidget {
  final String contactoId;
  final Function(bool)? onContactoDeleted;

  const HistorialClientePage({
    Key? key,
    required this.contactoId,
    this.onContactoDeleted,
  }) : super(key: key);

  @override
  State<HistorialClientePage> createState() => _HistorialClientePageState();
}

class _HistorialClientePageState extends State<HistorialClientePage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  
  Contacto? _contacto;
  bool _isLoading = true;
  bool _isEditingInfo = false;
  
  // Controladores para editar información del cliente
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _notasController = TextEditingController();
  final _alergiasController = TextEditingController();
  DateTime? _fechaNacimiento;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarContacto();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _notasController.dispose();
    _alergiasController.dispose();
    super.dispose();
  }

  Future<void> _cargarContacto() async {
    try {
      final doc = await _firestore.collection('contactos').doc(widget.contactoId).get();
      if (!doc.exists) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _contacto = Contacto.fromFirestore(doc);
        _inicializarControladores();
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar contacto: $e')));
      Navigator.pop(context);
    }
  }

  void _inicializarControladores() {
    if (_contacto != null) {
      _nombreController.text = _contacto!.nombre;
      _telefonoController.text = _contacto!.telefono;
      _emailController.text = _contacto!.email;
      _direccionController.text = _contacto!.direccion;
      _notasController.text = _contacto!.notas;
      _alergiasController.text = _contacto!.alergias;
      _fechaNacimiento = _contacto!.fechaNacimiento;
    }
  }

  Future<void> _guardarInformacionCliente() async {
    if (_contacto == null) return;

    try {
      final contactoActualizado = Contacto(
        id: _contacto!.id,
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim(),
        direccion: _direccionController.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        notas: _notasController.text.trim(),
        alergias: _alergiasController.text.trim(),
      );

      await _firestore
          .collection('contactos')
          .doc(widget.contactoId)
          .update(contactoActualizado.toMap());

      setState(() {
        _contacto = contactoActualizado;
        _isEditingInfo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Información actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarCita(String citaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cita'),
        content: const Text('¿Estás seguro de que deseas eliminar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _firestore.collection('citas').doc(citaId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _editarCita(Cita cita) async {
    try {
      // Cargar datos necesarios
      final contactos = await _firestore.collection('contactos').get();
      final servicios = await _firestore.collection('servicios').get();

      final citaEditada = await showDialog<Cita>(
        context: context,
        builder: (context) => AgregarCitaDialog(
          fecha: cita.fechaHora.toDate(),
          contactos: contactos.docs.map((doc) => Contacto.fromFirestore(doc)).toList(),
          servicios: servicios.docs.map((doc) => Servicio.fromFirestore(doc)).toList(),
          citaExistente: cita,
        ),
      );

      if (citaEditada != null) {
        await _firestore.collection('citas').doc(cita.id).update(citaEditada.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al editar cita: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _mostrarDialogoEliminarCliente() async {
    // Mostrar confirmación directamente
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente a ${_contacto?.nombre}?\n\nEsta acción no se puede deshacer.\n\nNota: Si el cliente tiene citas asociadas, no se podrá eliminar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await Contacto.deleteContacto(widget.contactoId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          // Regresar a la página anterior con indicador de que se eliminó
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_contacto == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No se pudo cargar la información del cliente')),
      );
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_contacto!.nombre),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Información'),
            Tab(icon: Icon(Icons.history), text: 'Historial de Citas'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: Icon(_isEditingInfo ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditingInfo) {
                  _guardarInformacionCliente();
                } else {
                  setState(() => _isEditingInfo = true);
                }
              },
            ),
          if (_tabController.index == 0)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'eliminar') {
                  _mostrarDialogoEliminarCliente();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar Cliente', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInformacionTab(),
          _buildHistorialTab(),
        ],
      ),
    ),
    );
  }

  Widget _buildInformacionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF00695C)),
                      const SizedBox(width: 8),
                      const Text(
                        'Información Personal',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (!_isEditingInfo)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => setState(() => _isEditingInfo = true),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCampoInfo('Nombre', _nombreController, Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildCampoInfo('Teléfono', _telefonoController, Icons.phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildCampoInfo('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildCampoInfo('Dirección', _direccionController, Icons.location_on),
                  const SizedBox(height: 12),
                  _buildFechaNacimiento(),
                  const SizedBox(height: 12),
                  _buildCampoInfo('Alergias', _alergiasController, Icons.warning, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildCampoInfo('Notas', _notasController, Icons.note, maxLines: 3),
                  if (_isEditingInfo) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _inicializarControladores();
                              setState(() => _isEditingInfo = false);
                            },
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _guardarInformacionCliente,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoInfo(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: _isEditingInfo
              ? TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.text.isEmpty ? 'No especificado' : controller.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: controller.text.isEmpty ? Colors.grey[400] : Colors.black87,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFechaNacimiento() {
    return Row(
      children: [
        Icon(Icons.cake, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: _isEditingInfo
              ? InkWell(
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaNacimiento ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setState(() => _fechaNacimiento = fecha);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Nacimiento',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fechaNacimiento != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                              : 'Seleccionar fecha',
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha de Nacimiento',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contacto!.fechaNacimientoFormateada,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHistorialTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('citas')
          .where('contactoId', isEqualTo: widget.contactoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final citas = snapshot.data!.docs
            .map((doc) => Cita.fromFirestore(doc))
            .toList()
            ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora)); // Ordenar en el cliente

        if (citas.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No hay citas registradas',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: citas.length,
          itemBuilder: (context, index) {
            final cita = citas[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: cita.colorEstado,
                  child: Icon(
                    _getIconForEstado(cita.estado),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  cita.servicio.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${cita.fechaFormateada} - ${cita.horaFormateada}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetalleCita('Estado', cita.estadoFormateado, cita.colorEstado),
                        _buildDetalleCita('Costo', '\$${cita.costo.toStringAsFixed(0)}', Colors.green),
                        if (cita.atendidoPor != null && cita.atendidoPor!.isNotEmpty)
                          _buildDetalleCita('Atendido por', cita.atendidoPor!, Colors.blue),
                        if (cita.productosUsados.isNotEmpty)
                          _buildDetalleCita('Productos', cita.productosFormateados, Colors.purple),
                        if (cita.obs.isNotEmpty)
                          _buildDetalleCita('Notas', cita.obs, Colors.orange),
                        if (cita.infoPersonalSesion != null && cita.infoPersonalSesion!.isNotEmpty)
                          _buildDetalleCita('Info de la sesión', cita.infoPersonalSesion!, Colors.teal),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _editarCita(cita),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Editar'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _eliminarCita(cita.id),
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
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
  }

  Widget _buildDetalleCita(String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  valor,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForEstado(EstadoCita estado) {
    switch (estado) {
      case EstadoCita.pendiente:
        return Icons.schedule;
      case EstadoCita.enProceso:
        return Icons.play_arrow;
      case EstadoCita.completada:
        return Icons.check;
      case EstadoCita.cancelada:
        return Icons.close;
    }
  }
}