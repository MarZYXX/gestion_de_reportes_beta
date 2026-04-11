import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodel/mapa_viewmodel.dart';
import '../model/report_model.dart';
import 'crear_reporte_screen.dart';

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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(reporte.getTextoSeveridad()),
                        backgroundColor: reporte.getColorSeveridad().withOpacity(0.2),
                        labelStyle: TextStyle(color: reporte.getColorSeveridad()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reporte.descripcion,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${reporte.fechaIncidente.day}/${reporte.fechaIncidente.month}/${reporte.fechaIncidente.year}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        reporte.getHoraFormateada(),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (reporte.urlsImagenes.isNotEmpty) ...[
                    const Text(
                      'Imágenes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                              child: Image.network(
                                reporte.urlsImagenes[index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image),
                                  );
                                },
                              ),
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
                            const Icon(Icons.admin_panel_settings, color: Colors.orange),
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
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (viewModel.error != null) {
          return Center(
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
          );
        }

        final posicion = viewModel.posicionActual != null
            ? LatLng(
          viewModel.posicionActual!.latitude,
          viewModel.posicionActual!.longitude,
        )
            : _posicionDefault;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: posicion,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.gestion_de_reportes',
                ),
                MarkerLayer(
                  markers: viewModel.marcadores,
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                    ),
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
                      builder: (context) => const CrearReporteScreen(),
                    ),
                  );
                  if (result == true) {
                    viewModel.cargarReportes();
                  }
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}