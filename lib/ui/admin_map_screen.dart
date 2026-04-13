import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geocoding/geocoding.dart';
import '../repo/reporte_service.dart';
import '../viewmodel/mapa_viewmodel.dart';
import '../model/report_model.dart';
import '../auth/auth_ui/login_screen.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final MapController _mapController = MapController();
  final ReporteService _reporteService = ReporteService();
  static const LatLng _posicionDefault = LatLng(20.6597, -103.3496);

  String filtroPrioridadLocal = 'todas';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<MapaViewModel>(context, listen: false);
      viewModel.inicializarMapa();
      viewModel.cargarReportes();
    });
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas salir del panel de administrador?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    }
  }

  Widget _construirImagenSegura(String rutaOBase64) {
    try {
      if (rutaOBase64.startsWith('/data') || rutaOBase64.startsWith('file://')) return Image.file(File(rutaOBase64), width: 120, height: 120, fit: BoxFit.cover);
      if (rutaOBase64.startsWith('http')) return Image.network(rutaOBase64, width: 120, height: 120, fit: BoxFit.cover);
      String cleanBase64 = rutaOBase64.contains(',') ? rutaOBase64.split(',').last : rutaOBase64;
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      while (cleanBase64.length % 4 != 0) cleanBase64 += '=';
      return Image.memory(base64Decode(cleanBase64), width: 120, height: 120, fit: BoxFit.cover);
    } catch (e) {
      return Container(width: 120, height: 120, color: Colors.grey[300], child: const Icon(Icons.broken_image, color: Colors.grey));
    }
  }

  void _mostrarDetallesAdmin(ReporteModel reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: Text(reporte.titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                      if (!reporte.estaCompleto && !reporte.esFalso)
                        PopupMenuButton<String>(
                          initialValue: reporte.severidad,
                          tooltip: 'Cambiar severidad',
                          onSelected: (nuevaSeveridad) {
                            if (nuevaSeveridad != reporte.severidad) {
                              _reporteService.actualizarSeveridad(reporte.id, nuevaSeveridad);
                              Navigator.pop(context);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'alta', child: Text('Cambiar a Alta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            const PopupMenuItem(value: 'media', child: Text('Cambiar a Media', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                            const PopupMenuItem(value: 'baja', child: Text('Cambiar a Baja', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          ],
                          child: Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [Text(reporte.getTextoSeveridad()), const SizedBox(width: 4), Icon(Icons.edit, size: 14, color: reporte.getColorSeveridad())],
                              ),
                              backgroundColor: reporte.getColorSeveridad().withOpacity(0.2),
                              labelStyle: TextStyle(color: reporte.getColorSeveridad())
                          ),
                        )
                      else
                        Chip(label: Text(reporte.getTextoSeveridad()), backgroundColor: reporte.getColorSeveridad().withOpacity(0.2), labelStyle: TextStyle(color: reporte.getColorSeveridad())),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Información del Ciudadano', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 8),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(reporte.userId).get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Text('Cargando datos...', style: TextStyle(fontSize: 12));
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              final nombreCompleto = '${data['nombre'] ?? ''} ${data['apellidoPaterno'] ?? ''} ${data['apellidoMaterno'] ?? ''} '.trim();
                              final correo = data['correo'] ?? 'Sin correo';
                              final celular = data['telefono'] ?? 'Sin número de celular';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nombre: $nombreCompleto', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Correo: $correo', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('Número de celular: $celular', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              );
                            }
                            return Text('ID Ciudadano: ${reporte.userId}');
                          },
                        ),
                        const Divider(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Expanded(
                              child: FutureBuilder<List<Placemark>>(
                                future: placemarkFromCoordinates(reporte.ubicacion.latitude, reporte.ubicacion.longitude),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                    final place = snapshot.data!.first;
                                    String direccion = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
                                    direccion = direccion.replaceAll(', ,', ',').replaceAll(RegExp(r'^, | ,$'), '');
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(direccion, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('Coords: ${reporte.ubicacion.latitude.toStringAsFixed(4)}, ${reporte.ubicacion.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    );
                                  }
                                  return Text('Coords: ${reporte.ubicacion.latitude}, ${reporte.ubicacion.longitude}');
                                },
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(reporte.descripcion, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),

                  if (reporte.urlsImagenes.isNotEmpty) ...[
                    const Text('Evidencia:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: reporte.urlsImagenes.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.black87,
                                    insetPadding: EdgeInsets.zero,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        InteractiveViewer(
                                          panEnabled: true,
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child: Center(
                                            child: _construirImagenSegura(reporte.urlsImagenes[index]),
                                          ),
                                        ),
                                        Positioned(
                                          top: 40,
                                          right: 20,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _construirImagenSegura(reporte.urlsImagenes[index])
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 32),

                  if (!reporte.estaCompleto && !reporte.esFalso)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.block, color: Colors.red),
                          label: const Text('Marcar Falso', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            _reporteService.marcarComoFalso(reporte.id);
                            Navigator.pop(context);
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text('Resolver', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () {
                            _reporteService.marcarComoCompletado(reporte.id);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    )
                  else
                    Center(
                      child: Text(
                        reporte.esFalso ? 'REPORTE FALSO / INVÁLIDO' : 'ATENDIDO Y RESUELTO',
                        style: TextStyle(color: reporte.esFalso ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Marker> _crearListaDeMarcadores(List<ReporteModel> reportes) {
    return reportes.map((reporte) {
      return Marker(
        point: LatLng(reporte.ubicacion.latitude, reporte.ubicacion.longitude),
        width: 40.0,
        height: 40.0,
        child: GestureDetector(
          onTap: () => _mostrarDetallesAdmin(reporte),
          child: Container(
            decoration: BoxDecoration(color: reporte.getColorSeveridad(), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.warning, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();
  }

  void _mostrarVentanaFlotante(BuildContext context, List<ReporteModel> reportesOriginales) {
    final List<ReporteModel> reportesOrdenados = List.from(reportesOriginales);
    reportesOrdenados.sort((a, b) {
      int getValor(String severidad) => severidad == 'alta' ? 1 : (severidad == 'media' ? 2 : 3);
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
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text('${reportesOrdenados.length} Incidentes en esta zona', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: reportesOrdenados.length,
                      itemBuilder: (context, index) {
                        final r = reportesOrdenados[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(side: BorderSide(color: r.getColorSeveridad().withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(r.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(r.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Icon(Icons.chevron_right, color: r.getColorSeveridad()),
                            onTap: () {
                              Navigator.pop(context);
                              _mostrarDetallesAdmin(r);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<MapaViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final reportesParaMapa = viewModel.reportes.where((r) {
          if (filtroPrioridadLocal != 'todas' && r.severidad != filtroPrioridadLocal) return false;
          return true;
        }).toList();

        final posicion = viewModel.posicionActual != null ? LatLng(viewModel.posicionActual!.latitude, viewModel.posicionActual!.longitude) : _posicionDefault;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mapa Operativo'),
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: _cerrarSesion)],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.grey.shade50,
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.grey, size: 20),
                      const SizedBox(width: 16),
                      FilterChip(label: const Text('Alta'), selected: filtroPrioridadLocal == 'alta', selectedColor: Colors.red.shade100, onSelected: (val) => setState(() => filtroPrioridadLocal = val ? 'alta' : 'todas')),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Media'), selected: filtroPrioridadLocal == 'media', selectedColor: Colors.orange.shade100, onSelected: (val) => setState(() => filtroPrioridadLocal = val ? 'media' : 'todas')),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Baja'), selected: filtroPrioridadLocal == 'baja', selectedColor: Colors.green.shade100, onSelected: (val) => setState(() => filtroPrioridadLocal = val ? 'baja' : 'todas')),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: posicion, initialZoom: 14),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.gestion_de_reportes'),
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            maxClusterRadius: 45,
                            size: const Size(40, 40),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(50),
                            maxZoom: 15,
                            markers: _crearListaDeMarcadores(reportesParaMapa),
                            builder: (context, markers) {
                              final listaReportes = markers.map((m) {
                                return reportesParaMapa.firstWhere((r) => r.ubicacion.latitude == m.point.latitude && r.ubicacion.longitude == m.point.longitude);
                              }).toList();

                              bool tieneAlta = listaReportes.any((r) => r.severidad == 'alta');
                              bool tieneMedia = listaReportes.any((r) => r.severidad == 'media');

                              Color colorRecuadro = tieneAlta ? Colors.red : (tieneMedia ? Colors.orange : Colors.green);

                              return GestureDetector(
                                onTap: () => _mostrarVentanaFlotante(context, listaReportes),
                                child: Container(
                                  decoration: BoxDecoration(color: colorRecuadro, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                                  child: const Center(child: Icon(Icons.add, color: Colors.white, size: 24)),
                                ),
                              );
                            },
                          ),
                        ),
                        RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
                      ],
                    ),

                    Positioned(
                      bottom: 20,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            _buildLegendItem(Colors.red, 'Alta'),
                            _buildLegendItem(Colors.orange, 'Media'),
                            _buildLegendItem(Colors.green, 'Baja'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}