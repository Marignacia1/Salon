import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contacto_model.dart';
import 'agregar_cita_dialog.dart';

class DetalleContactoPage extends StatefulWidget {
  final String contactoId;
  final Function(bool)? onContactoDeleted;

  const DetalleContactoPage({
    Key? key,
    required this.contactoId,
    this.onContactoDeleted,
  }) : super(key: key);

  @override
  _DetalleContactoPageState createState() => _DetalleContactoPageState();
}

class _DetalleContactoPageState extends State<DetalleContactoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Contacto contacto;
  late TextEditingController notasController;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarContacto();
  }

  Future<void> _cargarContacto() async {
    try {
      final doc = await _firestore.collection('contactos').doc(widget.contactoId).get();
      if (!doc.exists) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        contacto = Contacto.fromFirestore(doc);
        notasController = TextEditingController(text: contacto.notas);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar contacto: $e')));
      Navigator.pop(context);
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return; // Evitar múltiples saves simultáneos
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      await _firestore.collection('contactos').doc(widget.contactoId).update({
        'notas': notasController.text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: const Text('¿Estás seguro de eliminar este cliente permanentemente?'),
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

    if (confirm == true) {
      try {
        await Contacto.deleteContacto(widget.contactoId);
        if (mounted) {
          Navigator.pop(context, true);
          widget.onContactoDeleted?.call(true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(contacto.nombre),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Información', icon: Icon(Icons.info)),
              Tab(text: 'Citas', icon: Icon(Icons.calendar_today)),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildInfoTab(),
                _buildCitasTab(),
              ],
            ),
            if (_isSaving)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                  ),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Procesando...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditCitaDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Nombre', contacto.nombre),
          _buildInfoRow('Teléfono', contacto.telefono),
          _buildInfoRow('Email', contacto.email),
          _buildInfoRow('Dirección', contacto.direccion),
          _buildInfoRow('Fecha Nacimiento', contacto.fechaNacimientoFormateada),
          _buildInfoRow('Alergias', contacto.alergias),
          const SizedBox(height: 16),
          const Text('Notas:', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: notasController,
            decoration: const InputDecoration(
              hintText: 'Agregar notas sobre el cliente...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) => _saveChanges(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value.isEmpty ? 'No especificado' : value)),
        ],
      ),
    );
  }

  Widget _buildCitasTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('citas')
          .where('contactoId', isEqualTo: widget.contactoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error al cargar citas: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final citas = snapshot.data!.docs
            .map((doc) => Cita.fromFirestore(doc))
            .toList()
            ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora)); // Ordenar por fecha descendente

        return Column(
          children: [
            if (citas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Historial de Citas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            Expanded(
              child: citas.isEmpty
                  ? _buildEmptyCitas()
                  : RefreshIndicator(
                      onRefresh: () async {
                        // Forzar actualización del stream
                        setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: citas.length,
                        itemBuilder: (context, index) {
                          return _buildCitaCard(citas[index]);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyCitas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No hay citas registradas'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showAddEditCitaDialog(),
            child: const Text('Agregar primera cita'),
          ),
        ],
      ),
    );
  }

  Widget _buildCitaCard(Cita cita) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cita.servicio.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cita.colorEstado.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cita.colorEstado),
                  ),
                  child: Text(
                    cita.estadoFormateado,
                    style: TextStyle(
                      color: cita.colorEstado,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Fecha: ${cita.fechaFormateada} - ${cita.horaFormateada}'),
            if (cita.atendidoPor != null && cita.atendidoPor!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Atendido por: ${cita.atendidoPor}'),
              ),
            if (cita.productosUsados.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Productos: ${cita.productosFormateados}'),
              ),
            if (cita.obs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Observaciones: ${cita.obs}'),
              ),
            if (cita.infoPersonalSesion != null && cita.infoPersonalSesion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Info personal: ${cita.infoPersonalSesion}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Creada: ${cita.fechaCreacionFormateada}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cita.puedeEditarse)
                  TextButton.icon(
                    onPressed: () => _showAddEditCitaDialog(citaExistente: cita),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteCita(cita.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCita(String citaId) async {
    if (_isSaving) return; // Evitar operaciones múltiples
    
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cita'),
        content: const Text('¿Está seguro que desea eliminar esta cita?'),
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

    if (confirm == true) {
      setState(() {
        _isSaving = true;
      });
      
      try {
        await _firestore.collection('citas').doc(citaId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita eliminada correctamente')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar cita: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  Future<void> _showAddEditCitaDialog({Cita? citaExistente}) async {
    if (_isSaving) return; // Evitar múltiples diálogos
    
    try {
      setState(() {
        _isSaving = true;
      });
      
      final servicios = await _firestore.collection('servicios').get();
      
      setState(() {
        _isSaving = false;
      });
      
      final result = await showDialog<Cita>(
        context: context,
        builder: (context) => AgregarCitaDialog(
          fecha: DateTime.now(),
          contactos: [contacto],
          servicios: servicios.docs.map((doc) => Servicio.fromFirestore(doc)).toList(),
          citaExistente: citaExistente,
        ),
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita agendada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarContacto();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar servicios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}