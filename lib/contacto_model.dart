import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class Servicio {
  final String id;
  final String nombre;
  final String descripcion;
  final double precioBase;

  Servicio({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.precioBase,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precioBase': precioBase,
    };
  }

  factory Servicio.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Servicio(
      id: doc.id,
      nombre: data['nombre'],
      descripcion: data['descripcion'] ?? '',
      precioBase: data['precioBase']?.toDouble() ?? 0.0,
    );
  }

  factory Servicio.fromMap(Map<String, dynamic> map) {
    return Servicio(
      id: map['id'] ?? '',
      nombre: map['nombre'],
      descripcion: map['descripcion'] ?? '',
      precioBase: (map['precioBase'] as num).toDouble(),
    );
  }

  @override
  String toString() => nombre;
}

enum EstadoCita { pendiente, enProceso, completada, cancelada }

class Cita {
  final String id;
  final String contactoId;
  final String nombreContacto;
  final Timestamp fechaHora;
  final Servicio servicio;
  final double costo;
  final String obs;
  final List<String> productosUsados;
  final String estilista;
  final EstadoCita estado;
  final Timestamp? fechaCreacion;
  final String? atendidoPor;
  final String? infoPersonalSesion; // Info específica de esta sesión
  final String? detallesTecnicos; // Detalles técnicos del servicio (ej: corte en capas)
  final String? alergiasProdutosSesion; // Alergias específicas para esta sesión
  final String? userId; // ID del usuario propietario de la cita
  final String? propietarioEmail; // Email del propietario para identificación

  Cita({
    required this.id,
    required this.contactoId,
    required this.nombreContacto,
    required this.fechaHora,
    required this.servicio,
    required this.costo,
    this.obs = '',
    this.productosUsados = const [],
    this.estilista = '',
    this.estado = EstadoCita.pendiente,
    this.fechaCreacion,
    this.atendidoPor,
    this.infoPersonalSesion,
    this.detallesTecnicos,
    this.alergiasProdutosSesion,
    this.userId,
    this.propietarioEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'contactoId': contactoId,
      'nombreContacto': nombreContacto,
      'fechaHora': fechaHora,
      'servicio': servicio.toMap(),
      'costo': costo,
      'obs': obs,
      'productosUsados': productosUsados,
      'estilista': estilista,
      'estado': estado.name,
      'fechaCreacion': fechaCreacion ?? Timestamp.now(),
      'atendidoPor': atendidoPor,
      'infoPersonalSesion': infoPersonalSesion,
      'detallesTecnicos': detallesTecnicos,
      'alergiasProdutosSesion': alergiasProdutosSesion,
      'userId': userId,
      'propietarioEmail': propietarioEmail,
    };
  }

  factory Cita.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Manejar estado con compatibilidad hacia atrás
    EstadoCita estado = EstadoCita.pendiente;
    if (data['estado'] != null) {
      try {
        estado = EstadoCita.values.firstWhere(
          (e) => e.name == data['estado'],
          orElse: () => EstadoCita.pendiente,
        );
      } catch (e) {
        estado = EstadoCita.pendiente;
      }
    }
    
    return Cita(
      id: doc.id,
      contactoId: data['contactoId'],
      nombreContacto: data['nombreContacto'],
      fechaHora: data['fechaHora'] as Timestamp,
      servicio: Servicio.fromMap(data['servicio']),
      costo: data['costo']?.toDouble() ?? 0.0,
      obs: data['obs'] ?? '',
      productosUsados: List<String>.from(data['productosUsados'] ?? []),
      estilista: data['estilista'] ?? '',
      estado: estado,
      fechaCreacion: data['fechaCreacion'] as Timestamp?,
      atendidoPor: data['atendidoPor'],
      infoPersonalSesion: data['infoPersonalSesion'],
      detallesTecnicos: data['detallesTecnicos'],
      alergiasProdutosSesion: data['alergiasProdutosSesion'],
      userId: data['userId'],
      propietarioEmail: data['propietarioEmail'],
    );
  }

  String get productosFormateados => productosUsados.join(', ');
  String get horaFormateada => DateFormat('HH:mm').format(fechaHora.toDate());
  String get fechaFormateada => DateFormat('dd/MM/yyyy').format(fechaHora.toDate());
  String get fechaCreacionFormateada => fechaCreacion != null 
      ? DateFormat('dd/MM/yyyy HH:mm').format(fechaCreacion!.toDate())
      : 'No disponible';
  
  String get estadoFormateado {
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
  
  Color get colorEstado {
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
  
  bool get puedeEditarse => estado != EstadoCita.completada && estado != EstadoCita.cancelada;

  bool get esCompartida => userId != null && propietarioEmail != null;
  String get propietarioNombre => propietarioEmail?.split('@').first ?? 'Desconocido';
}

class Contacto {
  final String id;
  final String nombre;
  final String telefono;
  final String email;
  final DateTime? fechaNacimiento;
  final String direccion;
  final String notas;
  final String alergias;

  Contacto({
    this.id = '',
    required this.nombre,
    this.telefono = '',
    this.email = '',
    this.fechaNacimiento,
    this.direccion = '',
    this.notas = '',
    this.alergias = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'fechaNacimiento': fechaNacimiento?.toIso8601String(),
      'direccion': direccion,
      'notas': notas,
      'alergias': alergias,
    };
  }

  factory Contacto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contacto(
      id: doc.id,
      nombre: data['nombre'],
      telefono: data['telefono'] ?? '',
      email: data['email'] ?? '',
      fechaNacimiento: data['fechaNacimiento'] != null 
          ? DateTime.parse(data['fechaNacimiento']) 
          : null,
      direccion: data['direccion'] ?? '',
      notas: data['notas'] ?? '',
      alergias: data['alergias'] ?? '',
    );
  }

  String get fechaNacimientoFormateada {
    return fechaNacimiento != null 
        ? DateFormat('dd/MM/yyyy').format(fechaNacimiento!)
        : 'No especificada';
  }

  static Future<void> deleteContacto(String id) async {
    try {
      // Verificar todas las citas del cliente (sin limit)
      final citasSnapshot = await FirebaseFirestore.instance
          .collection('citas')
          .where('contactoId', isEqualTo: id)
          .get();
      
      if (citasSnapshot.docs.isNotEmpty) {
        throw Exception('No se puede eliminar, el cliente tiene ${citasSnapshot.docs.length} cita(s) asociada(s)');
      }
      
      await FirebaseFirestore.instance.collection('contactos').doc(id).delete();
    } catch (e) {
      throw Exception('Error al eliminar contacto: $e');
    }
  }
}

class CalendarioCompartido {
  final String id;
  final String codigoAcceso;
  final String propietarioId;
  final String propietarioEmail;
  final String nombre;
  final List<String> usuariosAutorizados;
  final Map<String, String> usuariosAutorizadosInfo;
  final DateTime fechaCreacion;
  final DateTime fechaExpiracion;
  final bool activo;

  CalendarioCompartido({
    this.id = '',
    required this.codigoAcceso,
    required this.propietarioId,
    required this.propietarioEmail,
    required this.nombre,
    this.usuariosAutorizados = const [],
    this.usuariosAutorizadosInfo = const {},
    required this.fechaCreacion,
    required this.fechaExpiracion,
    this.activo = true,
  });

  static String generarCodigoAcceso() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Map<String, dynamic> toMap() {
    return {
      'codigoAcceso': codigoAcceso,
      'propietarioId': propietarioId,
      'propietarioEmail': propietarioEmail,
      'nombre': nombre,
      'usuariosAutorizados': usuariosAutorizados,
      'usuariosAutorizadosInfo': usuariosAutorizadosInfo,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaExpiracion': Timestamp.fromDate(fechaExpiracion),
      'activo': activo,
    };
  }

  factory CalendarioCompartido.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarioCompartido(
      id: doc.id,
      codigoAcceso: data['codigoAcceso'],
      propietarioId: data['propietarioId'],
      propietarioEmail: data['propietarioEmail'],
      nombre: data['nombre'],
      usuariosAutorizados: List<String>.from(data['usuariosAutorizados'] ?? []),
      usuariosAutorizadosInfo: Map<String, String>.from(data['usuariosAutorizadosInfo'] ?? {}),
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
      fechaExpiracion: (data['fechaExpiracion'] as Timestamp).toDate(),
      activo: data['activo'] ?? true,
    );
  }

  bool get estaVencido => DateTime.now().isAfter(fechaExpiracion);
  bool get estaActivo => activo && !estaVencido;

  String get fechaCreacionFormateada => DateFormat('dd/MM/yyyy').format(fechaCreacion);
  String get fechaExpiracionFormateada => DateFormat('dd/MM/yyyy').format(fechaExpiracion);
}

// Modelo para gestionar cupos por hora
class CupoHorario {
  final String id;
  final String propietarioId;
  final DateTime fecha;
  final int hora; // 0-23
  final int cuposDisponibles;
  final int cuposOcupados;
  final bool activo;

  CupoHorario({
    this.id = '',
    required this.propietarioId,
    required this.fecha,
    required this.hora,
    required this.cuposDisponibles,
    this.cuposOcupados = 0,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'propietarioId': propietarioId,
      'fecha': Timestamp.fromDate(fecha),
      'hora': hora,
      'cuposDisponibles': cuposDisponibles,
      'cuposOcupados': cuposOcupados,
      'activo': activo,
    };
  }

  factory CupoHorario.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CupoHorario(
      id: doc.id,
      propietarioId: data['propietarioId'],
      fecha: (data['fecha'] as Timestamp).toDate(),
      hora: data['hora'],
      cuposDisponibles: data['cuposDisponibles'],
      cuposOcupados: data['cuposOcupados'] ?? 0,
      activo: data['activo'] ?? true,
    );
  }

  bool get tieneCuposLibres => cuposOcupados < cuposDisponibles;
  int get cuposLibres => cuposDisponibles - cuposOcupados;
  String get horaFormateada => '${hora.toString().padLeft(2, '0')}:00';
  
  CupoHorario copyWith({
    String? id,
    String? propietarioId,
    DateTime? fecha,
    int? hora,
    int? cuposDisponibles,
    int? cuposOcupados,
    bool? activo,
  }) {
    return CupoHorario(
      id: id ?? this.id,
      propietarioId: propietarioId ?? this.propietarioId,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      cuposDisponibles: cuposDisponibles ?? this.cuposDisponibles,
      cuposOcupados: cuposOcupados ?? this.cuposOcupados,
      activo: activo ?? this.activo,
    );
  }
}