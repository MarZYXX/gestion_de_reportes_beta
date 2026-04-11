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
  List<Marker> marcadores = [];

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
      final List<Marker> nuevosMarcadores = [];

      for (var doc in snapshot.docs) {
        final reporte = ReporteModel.fromFirestore(doc);

        final marker = Marker(
          width: 120,
          height: 70,
          point: LatLng(
            reporte.ubicacion.latitude,
            reporte.ubicacion.longitude,
          ),
          child: GestureDetector(
            onTap: () {
              if (onReportTapped != null) {
                onReportTapped!(reporte);
              }
            },
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 120,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: reporte.getColorSeveridad(),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.report_problem,
                    color: reporte.getColorSeveridad(),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      reporte.titulo.length > 15
                          ? '${reporte.titulo.substring(0, 12)}...'
                          : reporte.titulo,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (reporte.contadorCorroboraciones > 0) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.thumb_up,
                      size: 10,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${reporte.contadorCorroboraciones}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        nuevosMarcadores.add(marker);
      }

      marcadores = nuevosMarcadores;
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
