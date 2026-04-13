import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:io';
import '../model/comentario_model.dart';
import '../viewmodel/reportes_viewmodel.dart';
import '../model/report_model.dart';
import '../repo/reporte_service.dart';
import '../auth/auth_ui/login_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReporteService _reporteService = ReporteService();
  String filtroPrioridadLocal = 'todas';
  String filtroEstadoLocal = 'pendientes';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportesViewModel>(context, listen: false).cambiarFiltro('todos');
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

  List<ReporteModel> _filtrarYOrdenar(List<ReporteModel> reportes) {
    var filtrados = reportes.where((r) {
      final cumplePrioridad = filtroPrioridadLocal == 'todas' || r.severidad == filtroPrioridadLocal;

      bool cumpleEstado = false;
      if (filtroEstadoLocal == 'pendientes') {
        cumpleEstado = !r.estaCompleto && !r.esFalso;
      } else if (filtroEstadoLocal == 'resueltos') {
        cumpleEstado = r.estaCompleto && !r.esFalso;
      } else if (filtroEstadoLocal == 'falsos') {
        cumpleEstado = r.esFalso;
      }

      return cumplePrioridad && cumpleEstado;
    }).toList();

    filtrados.sort((a, b) {
      int getSev(String s) => s == 'alta' ? 1 : (s == 'media' ? 2 : 3);
      int sevCompare = getSev(a.severidad).compareTo(getSev(b.severidad));
      if (sevCompare != 0) return sevCompare;
      return b.contadorCorroboraciones.compareTo(a.contadorCorroboraciones);
    });

    return filtrados;
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

                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]), const SizedBox(width: 4),
                      Text(DateFormat('dd/MM/yyyy').format(reporte.fechaIncidente), style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]), const SizedBox(width: 4),
                      Text(reporte.getHoraFormateada(), style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
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
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _construirImagenSegura(reporte.urlsImagenes[index])),
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 16),

                  const Text('Comentarios de los vecinos:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: StreamBuilder<List<ComentarioModel>>(
                      stream: _reporteService.obtenerComentarios(reporte.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Sin comentarios aún.', style: TextStyle(color: Colors.grey)));
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final com = snapshot.data![index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.comment, size: 16, color: Colors.grey),
                              title: Text(com.texto, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${com.fecha.day}/${com.fecha.month}/${com.fecha.year}', style: const TextStyle(fontSize: 10)),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Moderación'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: _cerrarSesion),
        ],
      ),
      body: Consumer<ReportesViewModel>(
        builder: (context, vm, child) {
          if (vm.cargando) return const Center(child: CircularProgressIndicator());

          final reportesMostrar = _filtrarYOrdenar(vm.reportes);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.grey.shade50,
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.grey, size: 20), const SizedBox(width: 8),

                      FilterChip(
                        label: const Text('Pendientes'),
                        selected: filtroEstadoLocal == 'pendientes',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (_) => setState(() => filtroEstadoLocal = 'pendientes'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Resueltos'),
                        selected: filtroEstadoLocal == 'resueltos',
                        selectedColor: Colors.green.shade100,
                        onSelected: (_) => setState(() => filtroEstadoLocal = 'resueltos'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Falsos'),
                        selected: filtroEstadoLocal == 'falsos',
                        selectedColor: Colors.red.shade100,
                        onSelected: (_) => setState(() => filtroEstadoLocal = 'falsos'),
                      ),

                      Container(height: 24, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),

                      FilterChip(label: const Text('Alta'), selected: filtroPrioridadLocal == 'alta', selectedColor: Colors.red.shade100, onSelected: (val) => setState(() => filtroPrioridadLocal = val ? 'alta' : 'todas')),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Media'), selected: filtroPrioridadLocal == 'media', selectedColor: Colors.orange.shade100, onSelected: (val) => setState(() => filtroPrioridadLocal = val ? 'media' : 'todas')),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Baja'), selected: filtroPrioridadLocal == 'baja', selectedColor: Colors.blue.shade100, onSelected: (val) => setState(() => filtroPrioridadLocal = val ? 'baja' : 'todas')),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: reportesMostrar.isEmpty
                    ? const Center(child: Text('No hay reportes con estos filtros.'))
                    : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: reportesMostrar.length,
                  itemBuilder: (context, index) {
                    final reporte = reportesMostrar[index];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          side: BorderSide(color: reporte.getColorSeveridad().withOpacity(0.5), width: 1),
                          borderRadius: BorderRadius.circular(12)
                      ),
                      child: ListTile(
                        onTap: () => _mostrarDetallesAdmin(reporte),
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                            reporte.titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: reporte.esFalso ? TextDecoration.lineThrough : null, // Tachamos el título si es falso
                            )
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(reporte.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.thumb_up, size: 14, color: Colors.blue.shade300), const SizedBox(width: 4),
                                Text('${reporte.contadorCorroboraciones} Apoyos', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: reporte.getColorSeveridad().withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(reporte.getTextoSeveridad(), style: TextStyle(color: reporte.getColorSeveridad(), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}