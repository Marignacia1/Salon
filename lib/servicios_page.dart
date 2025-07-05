import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contacto_model.dart';

class ServiciosPage extends StatefulWidget {
  const ServiciosPage({super.key});

  @override
  State<ServiciosPage> createState() => _ServiciosPageState();
}

class _ServiciosPageState extends State<ServiciosPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  int _limite = 20;
  bool _cargandoMas = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == 
        _scrollController.position.maxScrollExtent) {
      _cargarMasServicios();
    }
  }

  Future<void> _cargarMasServicios() async {
    if (_cargandoMas) return;
    setState(() => _cargandoMas = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _limite += 10;
      _cargandoMas = false;
    });
  }

  Future<void> _showAddServicioDialog() async {
    final nombreCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nuevo Servicio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) const LinearProgressIndicator(),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio Base*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre es requerido')));
                    return;
                  }

                  final precio = double.tryParse(precioCtrl.text);
                  if (precio == null || precio <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese un precio válido mayor a 0')));
                    return;
                  }

                  setState(() => isLoading = true);
                  try {
                    final existente = await _firestore.collection('servicios')
                        .where('nombre', isEqualTo: nombreCtrl.text)
                        .get();

                    if (existente.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ya existe un servicio con este nombre')));
                      return;
                    }

                    final nuevoServicio = Servicio(
                      id: '', // Se asignará al crear
                      nombre: nombreCtrl.text,
                      descripcion: descripcionCtrl.text,
                      precioBase: precio,
                    );
                    
                    await _firestore.collection('servicios').add(nuevoServicio.toMap());
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar: ${e.toString()}')));
                  } finally {
                    setState(() => isLoading = false);
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

  Future<void> _confirmDeleteServicio(String servicioId, String servicioNombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: const Text('¿Está seguro? Esta acción no se puede deshacer.'),
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
        await _firestore.collection('servicios').doc(servicioId).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('servicios')
            .limit(_limite)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final servicios = snapshot.data!.docs
              .map((doc) => Servicio.fromFirestore(doc))
              .toList()
              ..sort((a, b) => a.nombre.compareTo(b.nombre)); // Ordenar en el cliente
          
          return Column(
            children: [
              Expanded(
                child: servicios.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: servicios.length + (_cargandoMas ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= servicios.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final servicio = servicios[index];
                          return _buildServicioItem(servicio);
                        },
                      ),
              ),
              if (_cargandoMas) const LinearProgressIndicator(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddServicioDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No hay servicios registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _showAddServicioDialog,
            child: const Text("Agregar servicio"),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _cargarServiciosIniciales,
            child: const Text("Cargar servicios predeterminados"),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarServiciosIniciales() async {
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
                  Text('Cargando servicios...'),
                ],
              ),
            ),
          ),
        ),
      );

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

      final batch = _firestore.batch();
      
      for (var servicio in serviciosIniciales) {
        final docRef = _firestore.collection('servicios').doc(servicio.id);
        batch.set(docRef, servicio.toMap());
      }
      
      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context); // Cerrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${serviciosIniciales.length} servicios cargados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar servicios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildServicioItem(Servicio servicio) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(servicio.nombre),
        subtitle: Text(
          servicio.descripcion.isNotEmpty 
              ? servicio.descripcion 
              : 'Sin descripción',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${servicio.precioBase.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteServicio(servicio.id, servicio.nombre),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}