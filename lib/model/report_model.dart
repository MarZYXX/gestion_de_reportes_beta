import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReporteModel {
  final String id;
  final String userId;
  final String titulo;
  final String descripcion;
  final String severidad;
  final DateTime fechaIncidente;
  final TimeOfDay horaIncidente;
  final GeoPoint ubicacion;
  final List<String> urlsImagenes;
  final int contadorCorroboraciones;
  final List<String> corroboradoPor;
  final bool estaCompleto;
  final DateTime fechaCreacion;
  final DateTime? fechaCompletado;
  final bool severidadModificadaPorAdmin;
  final bool esFalso;

  ReporteModel({
    required this.id,
    required this.userId,
    required this.titulo,
    required this.descripcion,
    required this.severidad,
    required this.fechaIncidente,
    required this.horaIncidente,
    required this.ubicacion,
    required this.urlsImagenes,
    required this.contadorCorroboraciones,
    required this.corroboradoPor,
    required this.estaCompleto,
    required this.fechaCreacion,
    this.fechaCompletado,
    required this.severidadModificadaPorAdmin,
    this.esFalso = false,
  });

  factory ReporteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReporteModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      severidad: data['severidad'] ?? 'baja',
      fechaIncidente: (data['fechaIncidente'] as Timestamp).toDate(),
      horaIncidente: TimeOfDay(
        hour: data['horaHora'] ?? 0,
        minute: data['horaMinuto'] ?? 0,
      ),
      ubicacion: data['ubicacion'] ?? GeoPoint(0, 0),
      urlsImagenes: List<String>.from(data['urlsImagenes'] ?? []),
      contadorCorroboraciones: data['contadorCorroboraciones'] ?? 0,
      corroboradoPor: List<String>.from(data['corroboradoPor'] ?? []),
      estaCompleto: data['estaCompleto'] ?? false,
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
      fechaCompletado: data['fechaCompletado'] != null
          ? (data['fechaCompletado'] as Timestamp).toDate()
          : null,
      severidadModificadaPorAdmin: data['severidadModificadaPorAdmin'] ?? false,
      esFalso: data['esFalso'] ?? false,
    );
  }

  Color getColorSeveridad() {
    switch (severidad) {
      case 'alta':
        return Colors.red;
      case 'media':
        return Colors.orange;
      case 'baja':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String getTextoSeveridad() {
    switch (severidad) {
      case 'alta':
        return 'Alta';
      case 'media':
        return 'Media';
      case 'baja':
        return 'Baja';
      default:
        return severidad;
    }
  }

  String getHoraFormateada() {
    return '${horaIncidente.hour.toString().padLeft(2, '0')}:${horaIncidente.minute.toString().padLeft(2, '0')}';
  }
}