import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contacto_model.dart';
import 'detalle_contacto_page.dart';
import 'historial_cliente_page.dart';
import 'package:intl/intl.dart';
import 'servicios_page.dart';
import 'widgets/app_background.dart';


class ContactosHomePage extends StatefulWidget {
  const ContactosHomePage({super.key});

  @override
  State<ContactosHomePage> createState() => _ContactosHomePageState();
}

class _ContactosHomePageState extends State<ContactosHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filtroActivo = 'todos';
  
  // Cache para evitar reconstrucciones innecesarias
  List<Contacto> _contactosCache = [];
  Map<String, int> _citasPorContactoCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar contactos y citas en paralelo
      final futures = await Future.wait([
        _firestore.collection('contactos').get(),
        _firestore.collection('citas').get(),
      ]);
      
      final contactosSnapshot = futures[0];
      final citasSnapshot = futures[1];
      
      // Procesar contactos
      final contactos = <Contacto>[];
      for (var doc in contactosSnapshot.docs) {
        try {
          contactos.add(Contacto.fromFirestore(doc));
        } catch (e) {
          print('Error al parsear contacto ${doc.id}: $e');
        }
      }
      
      // Procesar citas
      final citasPorContacto = <String, int>{};
      for (var doc in citasSnapshot.docs) {
        try {
          final cita = Cita.fromFirestore(doc);
          citasPorContacto.update(
            cita.contactoId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        } catch (e) {
          print('Error al parsear cita ${doc.id}: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _contactosCache = contactos;
          _citasPorContactoCache = citasPorContacto;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar datos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: _filtroActivo == value,
        onSelected: (selected) {
          setState(() {
            _filtroActivo = selected ? value : 'todos';
          });
        },
        selectedColor: const Color(0xFF80CBC4).withOpacity(0.3),
        labelStyle: TextStyle(
          color: _filtroActivo == value 
              ? const Color(0xFF00695C)
              : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, int value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF00695C)),
            const SizedBox(height: 8),
            Text(value.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showAddContactoDialog() {
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
            title: const Text('Nuevo Cliente'),
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
                              initialDate: DateTime.now(),
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
                                      ? DateFormat('dd/MM/yyyy').format(fechaNacimiento!)
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
                  backgroundColor: const Color(0xFF00695C),
                ),
                onPressed: nombreCtrl.text.isEmpty ? null : () async {
                  setState(() => isLoading = true);
                  
                  try {
                    await _addContacto(
                      nombreCtrl.text,
                      telefonoCtrl.text,
                      emailCtrl.text,
                      direccionCtrl.text,
                      fechaNacimiento,
                      notasCtrl.text,
                      alergiasCtrl.text,
                    );
                    Navigator.pop(context);
                    // Recargar datos después de agregar contacto
                    _cargarDatos();
                  } catch (e) {
                    setState(() => isLoading = false);
                    // El error ya se muestra en _addContacto
                  }
                },
                child: const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ... (parte inicial del archivo se mantiene igual)

Future<void> _addContacto(
  String nombre,
  String telefono,
  String email,
  String direccion,
  DateTime? fechaNacimiento,
  String notas,
  String alergias,
) async {
  try {
    final nuevoContacto = Contacto(
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      email: email.trim(),
      direccion: direccion.trim(),
      fechaNacimiento: fechaNacimiento,
      notas: notas.trim(),
      alergias: alergias.trim(),
    );
    
    print('Intentando guardar contacto: ${nuevoContacto.nombre}');
    await _firestore.collection('contactos').add(nuevoContacto.toMap());
    print('Contacto guardado exitosamente');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente registrado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    print('Error detallado al guardar contacto: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar contacto: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    rethrow; // Re-lanzar el error para que el diálogo se mantenga abierto
  }
}

// ... (resto del archivo se mantiene igual)

  Widget _buildContactosList() {
    // Filtrar contactos por búsqueda
    var contactosFiltrados = _contactosCache
        .where((contacto) => contacto.nombre
            .toLowerCase()
            .contains(_searchController.text.toLowerCase()))
        .toList();

    // Aplicar filtros adicionales
    if (_filtroActivo == 'con-citas') {
      contactosFiltrados = contactosFiltrados
          .where((c) => c.id.isNotEmpty && _citasPorContactoCache.containsKey(c.id))
          .toList();
    } else if (_filtroActivo == 'sin-citas') {
      contactosFiltrados = contactosFiltrados
          .where((c) => c.id.isEmpty || !_citasPorContactoCache.containsKey(c.id))
          .toList();
    }

    contactosFiltrados.sort((a, b) => a.nombre.compareTo(b.nombre));
    final totalCitas = _citasPorContactoCache.values.fold(0, (sum, count) => sum + count);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(context, 'Clientes', contactosFiltrados.length, Icons.people),
              _buildStatCard(context, 'Citas', totalCitas, Icons.calendar_today),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _cargarDatos();
            },
            child: contactosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No se encontraron clientes'
                              : 'No hay clientes registrados',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        if (_searchController.text.isEmpty)
                          ElevatedButton(
                            onPressed: _showAddContactoDialog,
                            child: const Text('Agregar primer cliente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: contactosFiltrados.length,
                    itemBuilder: (context, index) {
                      final contacto = contactosFiltrados[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF80CBC4).withOpacity(0.3),
                            child: Text(
                              contacto.nombre.substring(0, 1),
                              style: const TextStyle(
                                color: Color(0xFF00695C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            contacto.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (contacto.telefono.isNotEmpty) Text(contacto.telefono),
                              if (contacto.id.isNotEmpty && _citasPorContactoCache.containsKey(contacto.id))
                                Text(
                                  '${_citasPorContactoCache[contacto.id]} ${_citasPorContactoCache[contacto.id] == 1 ? 'cita' : 'citas'}',
                                  style: const TextStyle(color: Color(0xFF00695C)),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HistorialClientePage(
                                  contactoId: contacto.id,
                                ),
                              ),
                            );
                            // Recargar datos si se eliminó el contacto
                            if (result == true && mounted) {
                              _cargarDatos();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.spa),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ServiciosPage()),
            ),
            tooltip: 'Servicios',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar clientes',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildFilterChip('Todos', 'todos'),
                  _buildFilterChip('Con citas', 'con-citas'),
                  _buildFilterChip('Sin citas', 'sin-citas'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildContactosList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactoDialog,
        child: const Icon(Icons.add),
      ),
    ),
    );
  }
}