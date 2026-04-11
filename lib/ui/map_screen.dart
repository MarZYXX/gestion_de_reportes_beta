import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodel/mapa_viewmodel.dart';
import '../model/report_model.dart';
import '../auth/auth_ui/login_screen.dart';
import 'crear_reporte_screen.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  static const LatLng _posicionDefault = LatLng(20.6597, -103.3496);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<MapaViewModel>(context, listen: false);
      viewModel.inicializarMapa();
      viewModel.cargarReportes();
      viewModel.onReportTapped = (reporte) {
        _mostrarDetallesReporte(reporte);
      };
    });
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _mostrarDetallesReporte(ReporteModel reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reporte.titulo,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(reporte.getTextoSeveridad()),
                        backgroundColor:
                        reporte.getColorSeveridad().withOpacity(0.2),
                        labelStyle:
                        TextStyle(color: reporte.getColorSeveridad()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(reporte.descripcion,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${reporte.fechaIncidente.day}/${reporte.fechaIncidente.month}/${reporte.fechaIncidente.year}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(reporte.getHoraFormateada(),
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (reporte.urlsImagenes.isNotEmpty) ...[
                    const Text('Imágenes:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: reporte.urlsImagenes.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _construirImagenSegura(reporte.urlsImagenes[index]),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.thumb_up, color: Colors.blue),
                          const SizedBox(height: 4),
                          Text('${reporte.contadorCorroboraciones}'),
                          const Text('Corroboraciones'),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.verified, color: Colors.green),
                          const SizedBox(height: 4),
                          Text(reporte.estaCompleto ? 'Sí' : 'No'),
                          const Text('Completado'),
                        ],
                      ),
                      if (reporte.severidadModificadaPorAdmin)
                        Column(
                          children: [
                            const Icon(Icons.admin_panel_settings,
                                color: Colors.orange),
                            const SizedBox(height: 4),
                            const Text('Modificado'),
                            const Text('por admin'),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapaViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.cargando) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (viewModel.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(viewModel.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.inicializarMapa();
                      viewModel.cargarReportes();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final posicion = viewModel.posicionActual != null
            ? LatLng(
          viewModel.posicionActual!.latitude,
          viewModel.posicionActual!.longitude,
        )
            : _posicionDefault;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mapa de Reportes'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar sesión',
                onPressed: _cerrarSesion,
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: posicion,
                  initialZoom: 14,
                ),
                children: [

                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.gestion_de_reportes',
                  ),

                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45,
                      size: const Size(40, 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(50),
                      maxZoom: 15,
                      markers: _crearListaDeMarcadores(viewModel.reportes),
                      builder: (context, markers) {
                        final reportMarkers = markers.whereType<ReporteMarker>().toList();

                        bool tieneAlta = false;
                        bool tieneMedia = false;

                        for (var marker in reportMarkers) {
                          if (marker.reporte.severidad == 'alta') tieneAlta = true;
                          if (marker.reporte.severidad == 'media') tieneMedia = true;
                        }

                        Color colorRecuadro = Colors.green;
                        if (tieneAlta) {
                          colorRecuadro = Colors.red;
                        } else if (tieneMedia) {
                          colorRecuadro = Colors.orange;
                        }

                        return GestureDetector(
                          onTap: () {
                            final listaReportes = reportMarkers.map((m) => m.reporte).toList();
                            _mostrarVentanaFlotante(context, listaReportes);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorRecuadro,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Center(
                              child: Icon(Icons.add, color: Colors.white, size: 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CrearReporteScreen()),
                    );
                    if (result == true) {
                      viewModel.cargarReportes();
                    }
                  },
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _crearListaDeMarcadores(List<ReporteModel> reportes) {
    return reportes.map((reporte) {
      return ReporteMarker(
        reporte: reporte,
        point: LatLng(reporte.ubicacion.latitude, reporte.ubicacion.longitude),
        child: GestureDetector(
          onTap: () => _mostrarDetallesReporte(reporte),
          child: Container(
            decoration: BoxDecoration(
              color: reporte.getColorSeveridad(),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.warning, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();
  }

  // --- LA VENTANA FLOTANTE (BOTTOM SHEET DE LISTA) ---
  void _mostrarVentanaFlotante(BuildContext context, List<ReporteModel> reportesOriginales) {
    // 1. ORDENAR LOS REPORTES POR SEVERIDAD (Alta > Media > Baja)
    final List<ReporteModel> reportesOrdenados = List.from(reportesOriginales);
    reportesOrdenados.sort((a, b) {
      int getValor(String severidad) {
        if (severidad == 'alta') return 1;
        if (severidad == 'media') return 2;
        return 3; // baja
      }
      return getValor(a.severidad).compareTo(getValor(b.severidad));
    });

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),

                Text(
                  '${reportesOrdenados.length} Incidentes en esta zona',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Flexible(
                  child: ListView.builder(
                      shrinkWrap: true,
                      // Usamos la lista ordenada
                      itemCount: reportesOrdenados.length,
                      itemBuilder: (context, index) {
                        final r = reportesOrdenados[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              side: BorderSide(color: r.getColorSeveridad().withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(12)
                          ),
                          child: ListTile(
                            title: Text(r.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(r.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Icon(Icons.chevron_right, color: r.getColorSeveridad()),
                            onTap: () {
                              // 2. CERRAR LA LISTA Y ABRIR LOS DETALLES DEL REPORTE
                              Navigator.pop(context); // Cierra la ventanita de la lista
                              _mostrarDetallesReporte(r); // Abre tu vista original de detalles
                            },
                          ),
                        );
                      }
                  ),
                ),
              ],
            ),
          );
        }
    );
  }

  // --- CONSTRUCTOR ROBUSTO DE IMÁGENES ---
  Widget _construirImagenSegura(String rutaOBase64) {
    try {
      // 1. Si es una ruta de archivo local (Tus reportes antiguos)
      if (rutaOBase64.startsWith('/data') || rutaOBase64.startsWith('file://')) {
        return Image.file(
          File(rutaOBase64),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }

      // 2. Si es una URL de red (por si acaso)
      if (rutaOBase64.startsWith('http')) {
        return Image.network(
          rutaOBase64,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }

      // 3. Es un Base64: Limpiamos la cadena por si trae prefijos
      String cleanBase64 = rutaOBase64;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      // Aseguramos el padding para evitar el error de "Invalid length"
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }

      return Image.memory(
        base64Decode(cleanBase64),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } catch (e) {
      // Si todo falla, mostramos un recuadro gris con ícono de error
      // en lugar de que la pantalla roja bloquee la app
      return Container(
        width: 120,
        height: 120,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }
}

class ReporteMarker extends Marker {
  final ReporteModel reporte;

  ReporteMarker({
    required this.reporte,
    required super.point,
    required super.child,
    super.width = 40.0,
    super.height = 40.0,
  });
}