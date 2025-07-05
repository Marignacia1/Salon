import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contacto_model.dart';

class CalendarioCompartidoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<CalendarioCompartido> crearCalendarioCompartido({
    required String nombre,
    int diasValidez = 30,
  }) async {
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    final calendario = CalendarioCompartido(
      codigoAcceso: CalendarioCompartido.generarCodigoAcceso(),
      propietarioId: currentUser!.uid,
      propietarioEmail: currentUser!.email ?? '',
      nombre: nombre,
      fechaCreacion: DateTime.now(),
      fechaExpiracion: DateTime.now().add(Duration(days: diasValidez)),
    );

    final docRef = await _firestore
        .collection('calendarios_compartidos')
        .add(calendario.toMap());

    return calendario.copyWith(id: docRef.id);
  }

  Future<CalendarioCompartido?> buscarPorCodigo(String codigo) async {
    try {
      final query = await _firestore
          .collection('calendarios_compartidos')
          .where('codigoAcceso', isEqualTo: codigo.toUpperCase())
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final calendario = CalendarioCompartido.fromFirestore(query.docs.first);
      return calendario.estaActivo ? calendario : null;
    } catch (e) {
      throw Exception('Error al buscar calendario: $e');
    }
  }

  Future<bool> unirseACalendario(String codigo) async {
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    final calendario = await buscarPorCodigo(codigo);
    if (calendario == null) {
      throw Exception('Código inválido o calendario no encontrado');
    }

    if (calendario.propietarioId == currentUser!.uid) {
      throw Exception('No puedes unirte a tu propio calendario');
    }

    if (calendario.usuariosAutorizados.contains(currentUser!.uid)) {
      throw Exception('Ya tienes acceso a este calendario');
    }

    final usuariosActualizados = List<String>.from(calendario.usuariosAutorizados)
      ..add(currentUser!.uid);

    final usuariosInfoActualizada = Map<String, String>.from(calendario.usuariosAutorizadosInfo);
    usuariosInfoActualizada[currentUser!.uid] = currentUser!.email ?? 'Usuario';

    await _firestore
        .collection('calendarios_compartidos')
        .doc(calendario.id)
        .update({
      'usuariosAutorizados': usuariosActualizados,
      'usuariosAutorizadosInfo': usuariosInfoActualizada,
    });

    return true;
  }

  Stream<List<CalendarioCompartido>> obtenerCalendariosCompartidos() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('calendarios_compartidos')
        .where('usuariosAutorizados', arrayContains: currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarioCompartido.fromFirestore(doc))
            .where((cal) => cal.estaActivo)
            .toList());
  }

  Stream<List<CalendarioCompartido>> obtenerCalendariosCreados() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('calendarios_compartidos')
        .where('propietarioId', isEqualTo: currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarioCompartido.fromFirestore(doc))
            .toList());
  }

  Future<void> desactivarCalendario(String calendarioId) async {
    await _firestore
        .collection('calendarios_compartidos')
        .doc(calendarioId)
        .update({'activo': false});
  }

  Future<void> eliminarUsuario(String calendarioId, String usuarioId) async {
    final doc = await _firestore
        .collection('calendarios_compartidos')
        .doc(calendarioId)
        .get();

    if (!doc.exists) return;

    final calendario = CalendarioCompartido.fromFirestore(doc);
    if (calendario.propietarioId != currentUser?.uid) {
      throw Exception('Solo el propietario puede eliminar usuarios');
    }

    final usuariosActualizados = List<String>.from(calendario.usuariosAutorizados)
      ..remove(usuarioId);

    final usuariosInfoActualizada = Map<String, String>.from(calendario.usuariosAutorizadosInfo);
    usuariosInfoActualizada.remove(usuarioId);

    await _firestore
        .collection('calendarios_compartidos')
        .doc(calendarioId)
        .update({
      'usuariosAutorizados': usuariosActualizados,
      'usuariosAutorizadosInfo': usuariosInfoActualizada,
    });
  }

  Future<List<String>> obtenerPropietariosCalendarios() async {
    if (currentUser == null) return [];

    final calendariosCompartidos = await _firestore
        .collection('calendarios_compartidos')
        .where('usuariosAutorizados', arrayContains: currentUser!.uid)
        .where('activo', isEqualTo: true)
        .get();

    return calendariosCompartidos.docs
        .map((doc) => CalendarioCompartido.fromFirestore(doc))
        .where((cal) => cal.estaActivo)
        .map((cal) => cal.propietarioId)
        .toList();
  }

  Future<Query<Map<String, dynamic>>> obtenerConsultaCitasCompartidas() async {
    final propietarios = await obtenerPropietariosCalendarios();
    
    if (propietarios.isEmpty) {
      return _firestore
          .collection('citas')
          .where('userId', isEqualTo: currentUser?.uid);
    }

    final todosLosPropietarios = [currentUser?.uid, ...propietarios]
        .where((id) => id != null)
        .cast<String>()
        .toList();

    return _firestore
        .collection('citas')
        .where('userId', whereIn: todosLosPropietarios);
  }

  /// Verifica si el usuario actual tiene permisos para crear/editar citas
  Future<bool> tienePermisosCompletos() async {
    if (currentUser == null) return false;
    
    // Si es propietario de algún calendario, tiene permisos completos
    final calendariosCreados = await _firestore
        .collection('calendarios_compartidos')
        .where('propietarioId', isEqualTo: currentUser!.uid)
        .where('activo', isEqualTo: true)
        .get();

    if (calendariosCreados.docs.isNotEmpty) return true;

    // Si está invitado a algún calendario, también tiene permisos completos
    final calendariosCompartidos = await _firestore
        .collection('calendarios_compartidos')
        .where('usuariosAutorizados', arrayContains: currentUser!.uid)
        .where('activo', isEqualTo: true)
        .get();

    return calendariosCompartidos.docs.isNotEmpty;
  }

  /// Obtiene todos los contactos accesibles (propios y de calendarios compartidos)
  Future<List<String>> obtenerUsuariosAccesibles() async {
    if (currentUser == null) return [];

    final propietarios = await obtenerPropietariosCalendarios();
    return [currentUser!.uid, ...propietarios];
  }

  /// Verifica si puede editar una cita específica
  Future<bool> puedeEditarCita(String citaUserId) async {
    if (currentUser == null) return false;
    
    // Puede editar si es el propietario de la cita
    if (citaUserId == currentUser!.uid) return true;
    
    // Puede editar si está en un calendario compartido con el propietario
    final propietarios = await obtenerPropietariosCalendarios();
    return propietarios.contains(citaUserId);
  }
}

extension CalendarioCompartidoCopyWith on CalendarioCompartido {
  CalendarioCompartido copyWith({
    String? id,
    String? codigoAcceso,
    String? propietarioId,
    String? propietarioEmail,
    String? nombre,
    List<String>? usuariosAutorizados,
    Map<String, String>? usuariosAutorizadosInfo,
    DateTime? fechaCreacion,
    DateTime? fechaExpiracion,
    bool? activo,
  }) {
    return CalendarioCompartido(
      id: id ?? this.id,
      codigoAcceso: codigoAcceso ?? this.codigoAcceso,
      propietarioId: propietarioId ?? this.propietarioId,
      propietarioEmail: propietarioEmail ?? this.propietarioEmail,
      nombre: nombre ?? this.nombre,
      usuariosAutorizados: usuariosAutorizados ?? this.usuariosAutorizados,
      usuariosAutorizadosInfo: usuariosAutorizadosInfo ?? this.usuariosAutorizadosInfo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      activo: activo ?? this.activo,
    );
  }
}