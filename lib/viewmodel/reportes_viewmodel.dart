import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repo/reporte_service.dart';
import '../model/report_model.dart';
import 'dart:async';

class ReportesViewModel extends ChangeNotifier {
  final ReporteService _reporteService = ReporteService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool cargando = false;
  String? error;
  List<ReporteModel> reportes = [];
  String filtroActual = 'todos';
  String ordenActual = 'fecha';
  String filtroPrioridadLocal = 'todas';
  bool mostrarSoloAtendidos = false;

  StreamSubscription? _reportesSubscription;

  Future<void> cargarReportes() async {
    try {
      cargando = true;
      error = null;
      notifyListeners();

      final userId = _auth.currentUser?.uid;

      Stream<List<ReporteModel>> stream;

      if (filtroActual == 'mis_reportes' && userId != null) {
        stream = _reporteService.obtenerReportesPorUsuario(userId);
      } else if (filtroActual == 'alta' || filtroActual == 'media' || filtroActual == 'baja') {
        stream = _reporteService.obtenerReportesPorSeveridad(filtroActual);
      } else if (ordenActual == 'corroboraciones') {
        stream = _reporteService.obtenerReportesOrdenadosPorCorroboraciones();
      } else {
        stream = _reporteService.obtenerTodosReportes();
      }

      await _reportesSubscription?.cancel();

      _reportesSubscription = stream.listen((reportesList) {
        reportes = reportesList;
        cargando = false;
        notifyListeners();
      }, onError: (e) {
        error = e.toString();
        cargando = false;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString();
      cargando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _reportesSubscription?.cancel();
    super.dispose();
  }

  void cambiarFiltro(String filtro) {
    filtroActual = filtro;
    cargarReportes();
  }

  void cambiarOrden(String orden) {
    ordenActual = orden;
    cargarReportes();
  }

  Future<void> corroborarReporte(String reportId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      await _reporteService.corroborarReporte(reportId, userId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  bool usuarioYaCorroboro(ReporteModel reporte) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    return reporte.corroboradoPor.contains(userId);
  }

  List<ReporteModel> get reportesFiltrados {
    return reportes.where((r) {
      final cumplePrioridad = filtroPrioridadLocal == 'todas' || r.severidad == filtroPrioridadLocal;
      final cumpleAtendido = mostrarSoloAtendidos ? r.estaCompleto : true;
      return cumplePrioridad && cumpleAtendido;
    }).toList();
  }

  void setFiltroPrioridadLocal(String prioridad) {
    filtroPrioridadLocal = prioridad;
    notifyListeners();
  }

  void toggleMostrarAtendidos(bool valor) {
    mostrarSoloAtendidos = valor;
    notifyListeners();
  }

  Future<void> eliminarReporteLocal(String reportId) async {
    try {
      await _reporteService.eliminarReporte(reportId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}