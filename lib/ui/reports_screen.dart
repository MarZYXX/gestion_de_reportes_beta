import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../auth/auth_ui/login_screen.dart';
import '../model/comentario_model.dart';
import '../repo/reporte_service.dart';
import '../viewmodel/mapa_viewmodel.dart';
import '../viewmodel/reportes_viewmodel.dart';
import '../model/report_model.dart';
import 'crear_reporte_screen.dart';

enum OpcionesMenu { editar, eliminar }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportesViewModel>(context, listen: false)
          .cambiarFiltro('todos');
    });
  }

  Future<void> _cerrarSesion(BuildContext context) async {
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
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _confirmarEliminacion(String reportId, ReportesViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: const Text('¿Estás seguro de que deseas eliminar este reporte? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.eliminarReporteLocal(reportId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte eliminado'), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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


  void _abrirDetalleEdicion(BuildContext context, ReporteModel reporte) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearReporteScreen(reporteOriginal: reporte),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: Consumer<ReportesViewModel>(
        builder: (context, vm, child) {
          if (vm.cargando) return const Center(child: CircularProgressIndicator());
          if (vm.error != null) return Center(child: Text('Error: ${vm.error}', style: const TextStyle(color: Colors.red)));

          final reportesMostrar = vm.reportesFiltrados.where((reporte) {
            if (reporte.esFalso) {
              return vm.filtroActual == 'mis_reportes';
            }
            return true;
          }).toList();

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
                      const Icon(Icons.filter_list, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Atendidos'),
                        selected: vm.mostrarSoloAtendidos,
                        selectedColor: Colors.green.shade100,
                        onSelected: (val) => vm.toggleMostrarAtendidos(val),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Mis reportes'),
                        selected: vm.filtroActual == 'mis_reportes',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) => vm.cambiarFiltro(val ? 'mis_reportes' : 'todos'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Alta'),
                        selected: vm.filtroPrioridadLocal == 'alta',
                        selectedColor: Colors.red.shade100,
                        onSelected: (val) => vm.setFiltroPrioridadLocal(val ? 'alta' : 'todas'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Media'),
                        selected: vm.filtroPrioridadLocal == 'media',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (val) => vm.setFiltroPrioridadLocal(val ? 'media' : 'todas'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Baja'),
                        selected: vm.filtroPrioridadLocal == 'baja',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) => vm.setFiltroPrioridadLocal(val ? 'baja' : 'todas'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: reportesMostrar.isEmpty
                    ? const Center(
                  child: Text('No hay reportes que coincidan con los filtros.',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                )
                    : RefreshIndicator(
                  onRefresh: () async => await vm.cargarReportes(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: reportesMostrar.length,
                    itemBuilder: (context, index) {
                      final ReporteModel reporte = reportesMostrar[index];
                      final bool esPropio = reporte.userId == currentUserId;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: reporte.esFalso ? Colors.red : reporte.getColorSeveridad().withOpacity(0.5),
                              width: 1
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _mostrarDetallesReporte(reporte),
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            reporte.titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: reporte.esFalso ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          trailing: esPropio ? PopupMenuButton<OpcionesMenu>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (opcion) {
                              if (opcion == OpcionesMenu.eliminar) {
                                _confirmarEliminacion(reporte.id, vm);
                              } else if (opcion == OpcionesMenu.editar) {
                                _abrirDetalleEdicion(context, reporte);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: OpcionesMenu.editar,
                                child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')]),
                              ),
                              const PopupMenuItem(
                                value: OpcionesMenu.eliminar,
                                child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar')]),
                              ),
                            ],
                          ) : null,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(reporte.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(reporte.fechaIncidente),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  const Spacer(),

                                  if (reporte.esFalso)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Rechazado (Falso)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    )
                                  else if (reporte.estaCompleto)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Atendido', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: reporte.getColorSeveridad().withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      reporte.getTextoSeveridad(),
                                      style: TextStyle(color: reporte.getColorSeveridad(), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
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
              ),
            ],
          );
        },
      ),
    );
  }
}