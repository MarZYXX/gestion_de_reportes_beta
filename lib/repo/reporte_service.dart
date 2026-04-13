import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/comentario_model.dart';
import '../model/report_model.dart';

class ReporteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> crearReporte(ReporteModel reporte) async {
    try {
      await _firestore.collection('reportes').add({
        'userId': reporte.userId,
        'titulo': reporte.titulo,
        'descripcion': reporte.descripcion,
        'severidad': reporte.severidad,
        'fechaIncidente': Timestamp.fromDate(reporte.fechaIncidente),
        'horaHora': reporte.horaIncidente.hour,
        'horaMinuto': reporte.horaIncidente.minute,
        'ubicacion': reporte.ubicacion,
        'urlsImagenes': reporte.urlsImagenes,
        'contadorCorroboraciones': 0,
        'corroboradoPor': [],
        'estaCompleto': false,
        'fechaCreacion': Timestamp.now(),
        'fechaCompletado': null,
        'severidadModificadaPorAdmin': false,
      });
    } catch (e) {
      throw Exception('Error al crear reporte: $e');
    }
  }

  Stream<List<ReporteModel>> obtenerReportesPorUsuario(String userId) {
    return _firestore
        .collection('reportes')
        .where('userId', isEqualTo: userId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReporteModel.fromFirestore(doc)) 
          .toList();
    });
  }

  Stream<List<ReporteModel>> obtenerTodosReportes() {
    return _firestore
        .collection('reportes')
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReporteModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<ReporteModel>> obtenerReportesPorSeveridad(String severidad) {
    return _firestore
        .collection('reportes')
        .where('severidad', isEqualTo: severidad)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReporteModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<ReporteModel>> obtenerReportesOrdenadosPorCorroboraciones() {
    return _firestore
        .collection('reportes')
        .orderBy('contadorCorroboraciones', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReporteModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> corroborarReporte(String reportId, String userId) async {
    final reportRef = _firestore.collection('reportes').doc(reportId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);
      if (!snapshot.exists) return;

      List<String> corroboradoPor = List<String>.from(snapshot.data()?['corroboradoPor'] ?? []);

      if (corroboradoPor.contains(userId)) {
        corroboradoPor.remove(userId);
        transaction.update(reportRef, {
          'contadorCorroboraciones': FieldValue.increment(-1),
          'corroboradoPor': corroboradoPor,
        });
      } else {
        corroboradoPor.add(userId);
        transaction.update(reportRef, {
          'contadorCorroboraciones': FieldValue.increment(1),
          'corroboradoPor': corroboradoPor,
        });
      }
    });
  }

  Future<void> actualizarSeveridad(String reportId, String nuevaSeveridad) async {
    try {
      await _firestore.collection('reportes').doc(reportId).update({
        'severidad': nuevaSeveridad,
        'severidadModificadaPorAdmin': true,
      });
    } catch (e) {
      throw Exception('Error al actualizar la severidad: $e');
    }
  }

  Future<void> eliminarReporte(String reportId) async {
    try {
      await _firestore.collection('reportes').doc(reportId).delete();
    } catch (e) {
      throw Exception('Error al eliminar reporte: $e');
    }
  }

  Future<void> actualizarReporte(String reportId, Map<String, dynamic> dataActualizada) async {
    try {
      await _firestore.collection('reportes').doc(reportId).update(dataActualizada);
    } catch (e) {
      throw Exception('Error al actualizar reporte: $e');
    }
  }

  Future<void> marcarComoCompletado(String reportId) async {
    await _firestore.collection('reportes').doc(reportId).update({
      'estaCompleto': true,
      'fechaCompletado': Timestamp.now(),
    });
  }

  Future<void> agregarComentario(String reportId, String userId, String texto) async {
    try {
      await _firestore
          .collection('reportes')
          .doc(reportId)
          .collection('comentarios')
          .add({
        'userId': userId,
        'texto': texto,
        'fecha': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al agregar comentario: $e');
    }
  }

  Stream<List<ComentarioModel>> obtenerComentarios(String reportId) {
    return _firestore
        .collection('reportes')
        .doc(reportId)
        .collection('comentarios')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ComentarioModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> actualizarComentario(String reportId, String comentarioId, String nuevoTexto) async {
    try {
      await _firestore
          .collection('reportes')
          .doc(reportId)
          .collection('comentarios')
          .doc(comentarioId)
          .update({
        'texto': nuevoTexto,
      });
    } catch (e) {
      throw Exception('Error al actualizar comentario: $e');
    }
  }

  Future<void> eliminarComentario(String reportId, String comentarioId) async {
    try {
      await _firestore
          .collection('reportes')
          .doc(reportId)
          .collection('comentarios')
          .doc(comentarioId)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar comentario: $e');
    }
  }

  Future<void> marcarComoFalso(String reportId) async {
    try {
      await _firestore.collection('reportes').doc(reportId).update({
        'esFalso': true,
        'estaCompleto': true,
      });
    } catch (e) {
      throw Exception('Error al marcar como falso: $e');
    }
  }
}