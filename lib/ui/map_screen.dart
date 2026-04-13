import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/comentario_model.dart';
import '../repo/reporte_service.dart';
import '../viewmodel/mapa_viewmodel.dart';
import '../model/report_model.dart';
import '../auth/auth_ui/login_screen.dart';
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

  void _mostrarDetallesReporte(ReporteModel reporteInicial) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('reportes').doc(
              reporteInicial.id).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final reporte = ReporteModel.fromFirestore(snapshot.data!);
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
                            '${reporte.fechaIncidente.day}/${reporte
                                .fechaIncidente.month}/${reporte.fechaIncidente
                                .year}',
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
                                child: GestureDetector(
                                  onTap: () =>
                                      _verImagenPantallaCompleta(
                                          reporte.urlsImagenes[index]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _construirImagenSegura(
                                        reporte.urlsImagenes[index]),
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
                          GestureDetector(
                            onTap: () {
                              Provider
                                  .of<MapaViewModel>(context, listen: false)
                                  .corroborarReporte(reporte.id);
                            },
                            child: Column(
                              children: [
                                Icon(
                                  reporte.corroboradoPor.contains(
                                      FirebaseAuth.instance.currentUser?.uid)
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_alt_outlined,
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 4),
                                Text('${reporte.contadorCorroboraciones}'),
                                const Text('Apoyos'),
                              ],
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              // TODO: Abrir ventana de comentarios
                              _mostrarVentanaComentarios(context, reporte);
                            },
                            child: const Column(
                              children: [
                                Icon(Icons.comment_outlined,
                                    color: Colors.orange),
                                SizedBox(height: 4),
                                Text('Ver'),
                                Text('Comentar'),
                              ],
                            ),
                          ),

                          Column(
                            children: [
                              Icon(
                                reporte.estaCompleto ? Icons.verified : Icons
                                    .pending_actions,
                                color: reporte.estaCompleto
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(reporte.estaCompleto ? 'Sí' : 'No'),
                              const Text('Resuelto'),
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
      },
    );
  }

  void _mostrarVentanaComentarios(BuildContext context, ReporteModel reporte) {
    final TextEditingController comentarioController = TextEditingController();
    final ReporteService reporteService = ReporteService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                const Text('Comentarios de los Vecinos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),

                Expanded(
                  child: StreamBuilder<List<ComentarioModel>>(
                    stream: reporteService.obtenerComentarios(reporte.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('Aún no hay comentarios.\nSé el primero en aportar información.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        );
                      }

                      final comentarios = snapshot.data!;
                      return ListView.builder(
                        itemCount: comentarios.length,
                        itemBuilder: (context, index) {
                          final comentario = comentarios[index];
                          final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
                          final esMiComentario = currentUserUid == comentario.userId;

                          return Card(
                            elevation: 0,
                            color: Colors.grey.shade100,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.person, color: Colors.blue),
                              ),
                              title: Text(esMiComentario ? 'Tú (Anónimo)' : 'Vecino Anónimo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(comentario.texto),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${comentario.fecha.day}/${comentario.fecha.month}/${comentario.fecha.year}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              trailing: esMiComentario
                                  ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'editar') {
                                    _editarComentario(reporte.id, comentario, reporteService);
                                  } else if (value == 'eliminar') {
                                    _eliminarComentario(reporte.id, comentario.id, reporteService);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                                  const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
                                ],
                              )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: comentarioController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Añadir un comentario (Anónimo)...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: () async {
                          final texto = comentarioController.text.trim();
                          if (texto.isEmpty) return;

                          final userId = FirebaseAuth.instance.currentUser?.uid;
                          if (userId != null) {
                            comentarioController.clear();
                            await reporteService.agregarComentario(reporte.id, userId, texto);
                          }
                        },
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _editarComentario(String reportId, ComentarioModel comentario, ReporteService servicio) {
    final TextEditingController editController = TextEditingController(text: comentario.texto);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Comentario'),
        content: TextField(
          controller: editController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Modifica tu comentario...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoTexto = editController.text.trim();
              if (nuevoTexto.isNotEmpty && nuevoTexto != comentario.texto) {
                await servicio.actualizarComentario(reportId, comentario.id, nuevoTexto);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _eliminarComentario(String reportId, String comentarioId, ReporteService servicio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Comentario'),
        content: const Text('¿Estás seguro de que deseas borrar este comentario? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await servicio.eliminarComentario(reportId, comentarioId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
                bottom: 20,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
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

              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () async {
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

  void _mostrarVentanaFlotante(BuildContext context, List<ReporteModel> reportesOriginales) {
    final List<ReporteModel> reportesOrdenados = List.from(reportesOriginales);
    reportesOrdenados.sort((a, b) {
      int getValor(String severidad) {
        if (severidad == 'alta') return 1;
        if (severidad == 'media') return 2;
        return 3;
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
                              Navigator.pop(context);
                              _mostrarDetallesReporte(r);
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

  Widget _construirImagenSegura(String rutaOBase64) {
    try {
      if (rutaOBase64.startsWith('/data') || rutaOBase64.startsWith('file://')) {
        return Image.file(
          File(rutaOBase64),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }

      if (rutaOBase64.startsWith('http')) {
        return Image.network(
          rutaOBase64,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }

      String cleanBase64 = rutaOBase64;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

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
      return Container(
        width: 120,
        height: 120,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }

  void _verImagenPantallaCompleta(String rutaOBase64) {
    if (rutaOBase64.isEmpty) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (BuildContext context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: _construirImagenSegura(rutaOBase64),
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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