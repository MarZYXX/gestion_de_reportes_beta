import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../model/report_model.dart';

class MapaViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool cargando = true;
  String? error;

  Position? posicionActual;
  List<ReporteModel> reportes = [];

  Function(ReporteModel)? onReportTapped;

  Future<void> inicializarMapa() async {
    try {
      cargando = true;
      notifyListeners();

      await _solicitarPermiso();
      posicionActual = await Geolocator.getCurrentPosition();

      cargando = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      cargando = false;
      notifyListeners();
    }
  }

  void cargarReportes() {
    _firestore
        .collection('reportes')
        .snapshots()
        .listen((snapshot) {

      final List<ReporteModel> nuevosReportes = [];

      for (var doc in snapshot.docs) {
        nuevosReportes.add(ReporteModel.fromFirestore(doc));
      }

      reportes = nuevosReportes;
      notifyListeners();
    });
  }

  Future<void> _solicitarPermiso() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Ubicación desactivada');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(size.width / 2, 0);    
    path.lineTo(0, size.height);  
    path.lineTo(size.width, size.height); 
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}